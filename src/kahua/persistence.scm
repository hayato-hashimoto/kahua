;; Persistent metaclass
;;
;;  Copyright (c) 2003-2004 Scheme Arts, L.L.C., All rights reserved.
;;  Copyright (c) 2003-2004 Time Intermedia Corporation, All rights reserved.
;;  See COPYING for terms and conditions of using this software
;;
;; $Id: persistence.scm,v 1.10 2004/02/27 13:27:29 shiro Exp $

(define-module kahua.persistence
  (use srfi-1)
  (use srfi-2)
  (use srfi-13)
  (use file.util)
  (use util.list)
  (use gauche.sequence)
  (use gauche.parameter)
  (use gauche.version)
  (use gauche.fcntl)
  (use gauche.logger)
  (export <kahua-persistent-meta> <kahua-persistent-base>
          <kahua-persistent-metainfo>
          key-of find-kahua-class find-kahua-instance
          touch-kahua-instance!
          kahua-serializable-object?
          <kahua-db> current-db with-db kahua-db-sync
          id->kahua-instance class&key->kahua-instance
          <kahua-collection> make-kahua-collection
          )
  )
(select-module kahua.persistence)

;;=========================================================
;; Persistent metaclass
;;

;; <kahua-persistent-meta>
;;
;;  - Processes :persistent allocation option.
;;  - Keeps generation of persistent class.
;;  - Keeps mapping from class name to the in-memory class.

(define-class <kahua-persistent-meta> (<class>)
  (;; In-memory catalog of persistent classes.
   ;; maps class name to class object.
   (class-alist :allocation :class :init-value '())

   ;; A signature given in the class definition in the source file
   ;; to be used to determine class' generation.
   (source-id   :init-keyword :source-id :init-value "")
   
   ;; The following metainformation is set up when a first instance of
   ;; the class is realized (either read from DB or newly created)
   ;; See the "Persistent metainformation" section below for the details.
   (metainfo      :init-value #f)  ;; <kahua-persistent-metainfo> instance
   (generation    :init-value 0)   ;; generation of in-memory class
   (persistent-generation :init-value #f) ;; generation in persistent db
   ))

(define-method make ((class <kahua-persistent-meta>) . initargs)
  ;; When the first instance of a persistent class is realized (created
  ;; in memory), the in-memory definition and in-db definition is compared.
  (ensure-metainfo class)
  (next-method))

(define-method initialize ((class <kahua-persistent-meta>) initargs)
  (next-method)
  (set! (ref class 'class-alist)
        (assq-set! (ref class 'class-alist) (class-name class) class)))

;; Support of persistent slot
(define-method compute-get-n-set ((class <kahua-persistent-meta>) slot)
  (let ((alloc (slot-definition-allocation slot)))
    (case alloc
      ((:persistent)
       (let* ((slot-num (slot-ref class 'num-instance-slots))
              (acc (make <slot-accessor>
                     :class class :name (slot-definition-name slot)
                     :slot-number slot-num :initializable #t)))
         (inc! (slot-ref class 'num-instance-slots))
         (list (make-kahua-getter acc)
               (make-kahua-setter acc)
               (make-kahua-boundp acc)
               #t)))
      (else (next-method)))))

(define (make-kahua-getter acc)
  (lambda (o)
    (let1 val (slot-ref-using-accessor o acc)
      (if (is-a? val <kahua-wrapper>)
        (let1 real (peel-wrapper val)
          (slot-set-using-accessor! o acc real)
          real)
        val))))

(define (make-kahua-setter acc)
  (lambda (o v)
    (let1 db (current-db)
      (unless db (error "database not active"))
      (unless (memq o (ref db 'modified-instances))
        (push! (ref db 'modified-instances) o))
      (slot-set-using-accessor! o acc v))))

(define (make-kahua-boundp acc)
  (lambda (o)
    (slot-bound-using-accessor? o acc)))

;;=========================================================
;; Persistent baseclass
;;

(define-class <kahua-persistent-base> ()
  (;; unique ID 
   (id    :init-keyword :id :init-form (kahua-db-unique-id))
   ;; management data
   (db    :init-form (current-db))  ; points back to db
   ;; alist of slot data which is in the DB but not in the current
   ;; in-memory class.
   (%hidden-slot-values :init-keyword :%hidden-slot-values :init-value '())
   ;; persistent class generation of the in-db instance
   (%persistent-generation :init-keyword :%persistent-generation :init-value 0)
   )
  :metaclass <kahua-persistent-meta>)

;; this method should be overriden by subclasses for convenience.
(define-method key-of ((obj <kahua-persistent-base>))
  (format "~6,'0d" (ref obj 'id)))

;; Initializing persistent instance:
;;  * (initialize (obj <kahua-persistent-base>)) initializes in-memory
;;   image of persistent object, and registered it to the index table
;;   of the current database.
;;  * To calculate index, we need to retrieve key, so the slot values
;;   have to be set before that.  We can't count on initargs, since
;;   a persistent slot may not have init-keyword.  So, the persistent
;;   object realization routine passes the alist of slot values via
;;   :%realization-slot-values keyword argument, and we set! the slot
;;   values.
;;  * The object is an instance of in-memory persistent class.  It may
;;   be different from in-db persistent class.  The persistent object
;;   deserializer translates the in-db slot values to in-memory slot
;;   values before passing it to :%realization-slot-values argument.

(define-method initialize ((obj <kahua-persistent-base>) initargs)
  (next-method)
  (let ((db (current-db))
        (id (ref obj 'id))
        (rsv (get-keyword :%realization-slot-values initargs #f)))
    (when (hash-table-get (ref db 'instance-by-id) id #f)
      (errorf "instance with same ID (~s) is active (class ~s)"
              id (class-of obj)))
    (when rsv
      ;; we are realizing an instance from the saved one
      (dolist (p rsv)
        (when (assq (car p) (class-slots (class-of obj)))
          (slot-set! obj (car p) (make <kahua-wrapper> :value (cdr p)))))
      ;; obj is marked dirty because of the above setup.
      ;; we revert it to clean.  it is ugly, but it's the easiest
      ;; way to prevent obj from being marked dirty inadvertently.
      (update! (ref db 'modified-instances) (cut delete obj <>)))
    (hash-table-put! (ref db 'instance-by-id) id obj)
    (hash-table-put! (ref db 'instance-by-key)
                     (cons (class-name (class-of obj))
                           (key-of obj))
                     obj)
    ))

(define (find-kahua-class name)
  (or (assq-ref (class-slot-ref <kahua-persistent-meta> 'class-alist) name)
      (error "can't find a class: " name)))

;; Mark a persistent object dirty
(define-method touch-kahua-instance! ((obj <kahua-persistent-base>))
  (let1 db (ref obj 'db)
    (unless (ref db 'active)
      (error "database not active"))
    (unless (memq obj (ref db 'modified-instances))
      (push! (ref db 'modified-instances) obj))))

;; kahua-wrapper is used to mark a slot value that has been just
;; read from the disk, and may contain <kahua-proxy> reference.
;; Once the slot is accessed, the getter traverses its value
;; and replaces <kahua-proxy> references, and reset the slot value
;; for the replaced one---thus the user never see <kahua-wrapper> value.
(define-class <kahua-wrapper> ()
  ((value :init-keyword :value)))

(define-method peel-wrapper ((wrapper <kahua-wrapper>))
  ;; this is inefficient, but for now...
  (define (realize-proxy val)
    (cond ((is-a? val <kahua-proxy>)
           (realize-kahua-proxy val))
          ((list? val)
           (map realize-proxy val))
          ((vector? val)
           (map-to <vector> realize-proxy val))
          (else val)))
  (realize-proxy (ref wrapper 'value)))

(define-class <kahua-proxy> ()
  ((class :init-keyword :class)
   (key   :init-keyword :key)
   ))

(define-method realize-kahua-proxy ((proxy <kahua-proxy>))
  (let1 db (current-db)
    (unless db (error "database not active"))
    (or (hash-table-get (ref db 'instance-by-key)
                        (cons (class-name (ref proxy 'class))
                              (ref proxy 'key))
                        #f)
        (read-kahua-instance db (ref proxy 'class) (ref proxy 'key)))))

;; The bottom-level writer ----------------------------------------
;;   write-kahua-instance calls kahua-write.

;; for now, we don't consider shared structure
(define-method kahua-write ((obj <kahua-persistent-base>) port)
  (define (save-slot s)
    (format #t "(~a . " (car s))
    (serialize-value (cdr s))
    (format #t ")\n"))
  (with-output-to-port port
    (lambda ()
      (receive (generation vals hidden)
          (export-slot-values obj)
        (format #t "#,(kahua-object (~a ~a) ~a\n"
                (class-name (class-of obj)) generation (ref obj 'id))
        (for-each save-slot
                  (if (null? hidden)
                    vals
                    (cons `(%hidden-slot-values . ,hidden) vals)))
        (display ")\n")))))

;; serialization
(define (serialize-value v)
  (cond
   ((any (cut is-a? v <>)
         (list <boolean> <number> <string> <symbol> <keyword>))
    (write v) (display " "))
   ((null? v) (display "()"))
   ((pair? v)
    (display "(")
    (let loop ((v v))
      (cond ((null? v))
            ((pair? v) (serialize-value (car v)) (loop (cdr v)))
            (else (display " . ") (serialize-value v))))
    (display ")"))
   ((vector? v)
    (display "#(")
    (for-each serialize-value v)
    (display ")"))
   ((is-a? v <kahua-persistent-base>)
    (format #t "#,(kahua-proxy ~a ~s)"
            (class-name (class-of v)) (key-of v)))
   ((is-a? v <kahua-proxy>)
    (format #t "#,(kahua-proxy ~a ~s)"
            (class-name (ref v 'class)) (ref v 'key)))
   ((is-a? v <kahua-wrapper>)
    (serialize-value (ref v 'value)))
   (else
    (error "object not serializable:" v))))

(define (kahua-serializable-object? v)
  (or (any (cut is-a? v <>)
           (list <boolean> <number> <string> <symbol> <keyword>
                 <kahua-persistent-base> <kahua-proxy> <kahua-wrapper>))
      (and (pair? v)
           (let loop ((v v))
             (cond ((null? v) #t)
                   ((pair? v)
                    (and (kahua-serializable-object? (car v))
                         (loop (cdr v))))
                   (else
                    (kahua-serializable-object? (cdr v))))))
      (and (vector? v)
           (let loop ((i (- (vector-length v) 1)))
             (if (negative? i)
               #t
               (and (kahua-serializable-object? (vector-ref v i))
                    (loop (- i 1))))))
      ))

;; The bottom-level reader ----------------------------------------
;;   read-kahua-instance will read srfi-10 syntax of
;;   kahua-object and kahua-proxy, which triggers the following
;;   procedures.

(define-reader-ctor 'kahua-object
  (lambda (class-desc id . vals)
    (or (id->kahua-instance id)
        ;; See notes on (initialize (<kahua-persistent-base>)) for
        ;; the :%realization-slot-values argument.
        (let* ((cname (if (pair? class-desc) (car class-desc) class-desc))
               (class (find-kahua-class cname))
               (generation (find-instance-generation class class-desc)))
          (receive (slot-alist save-slots)
              (import-slot-values class generation vals)
            (make class :id id
                  :%realization-slot-values slot-alist
                  :%hidden-slot-values save-slots
                  :%persistent-generation generation))))))

(define-reader-ctor 'kahua-proxy
  (lambda (class-name key)
    (make <kahua-proxy> :class (find-kahua-class class-name) :key key)))

(define (find-instance-generation class class-desc)
  (if (eq? (class-name class) '<kahua-persistent-metainfo>)
    0
    (begin
      (ensure-metainfo class)
      (if (pair? class-desc)
        (begin
          ;; The database may have been updated since the last bind-metainfo.
          (when (> (cadr class-desc) (ref class 'persistent-generation))
            (persistent-class-bind-metainfo class))
          (cadr class-desc))
        (ref class 'persistent-generation)))))

;;=========================================================
;; Persistent metainformation
;;

;; Information of persitent class metaobject is stored using
;; a special persistent class, <kahua-persistent-metainfo>.
;;
;; A persistent class has "in-memory" representation and "in-db"
;; representation.
;;
;; At the beginning, you don't have any instance in the database,
;; nor the "in-db" class.  You only have "in-memory" class that
;; is read from the source code.
;;
;; When the first persistent instance is created, a metainfo structure
;; that records the class information is also created, and stored
;; in the database.  That becomes "in-db" class representation.
;;
;; When you access to the db second time, the metainfo structure is
;; read from the db and compared to the "in-memory" class.  If 
;; two matches, no problem---the schema hasn't been changed.
;;
;; If in-memory class and in-db class doesn't match, there may
;; be two cases.
;;
;;   1. The source code is updated, so in-memory class is newer than
;;      the in-db class.
;;   2. Some other process has used newer sources, and updated the
;;      in-db class, while your process is still using older definition.
;;
;; If the case is 1, we'll update the in-db class, along with any
;; instance.  If the case is 2, we won't touch the in-db class, but
;; we update the in-memory class as if it is redefined (note that at
;; this point there's no instance in-memory, so the instance update
;; protocol is not triggered).

(define-class <kahua-persistent-metainfo> (<kahua-persistent-base>)
  (;; class name
   (name             :allocation :persistent :init-value #f
                     :init-keyword :name)
   ;; current generation & signature
   (generation       :allocation :persistent :init-value 0
                     :init-keyword :persistent-generation)
   (signature        :allocation :persistent :init-value '()
                     :init-keyword :signature)

   ;; The following slots keep the history of the class definitions.

   ;; Every time the class signature is changed, the generation number is
   ;; incremented and the old generation and sigature is pushed into
   ;; this alist.
   (signature-alist  :allocation :persistent :init-value '()
                     :init-keyword :signature-alist)

   ;; Furthermore, if the in-memory class is given a source-id, the
   ;; association of it and generation number is stored here.  It helps
   ;; to find out whether the in-memory class is older than in-db class, or
   ;; the newer source actually adopted the older definitions.
   ;; Source id can be any string, and it is possible that one source id
   ;; corresponds to multiple generations.
   (source-id-map    :allocation :persistent :init-value '()
                     :init-keyword :source-id-map)

   ;; For each generation (except the newest one), a "translation directive"
   ;; is prepared.  Each directive contains information to translate
   ;; an instance's slot value of the generation to the one of the next
   ;; generation, and vice versa.
   ;; The default translation directive is calculated by the difference
   ;; of persistent slots.  In future, an interface will be provided
   ;; to register an arbitrary translation procedures.
   (translator-alist :allocation :persistent :init-value '()
                     :init-keyword :translator-alist)
   ))

(define-method key-of ((info <kahua-persistent-metainfo>))
  (x->string (ref info 'name)))

(define-method ensure-metainfo ((class <kahua-persistent-meta>))
  (unless (ref class 'metainfo)
    (persistent-class-bind-metainfo class))
  (ref class 'metainfo))

;; Calculates class signature.  Currently we take all persistent-allocated
;; slots.
(define-method persistent-class-signature ((class <kahua-persistent-meta>))
  (define (extract-slot-def slot)
    (and (memq (slot-definition-allocation slot) '(:persistent))
         (list (slot-definition-name slot)
               :allocation (slot-definition-allocation slot)
               )))
  (sort (filter-map extract-slot-def (class-slots class))
        (lambda (x y)
          (string<? (symbol->string (car x)) (symbol->string (car y))))))

;; Extracts persistent slot definitions from signature.  For the time
;; being, both are the same, but it may be changed later.
(define (signature->slot-definitions signature)
  (sort-slot-definitions signature))

(define (sort-slot-definitions sdefs)
  (sort sdefs (lambda (a b)
                (string<? (symbol->string (car a))
                          (symbol->string (car b))))))

;; Returns a list of persistent slot definitions of given generation.
(define-method persistent-class-slots ((class <kahua-persistent-meta>)
                                       (generation <integer>))
  (persistent-class-slots (ensure-metainfo class) generation))

(define-method persistent-class-slots ((metainfo <kahua-persistent-metainfo>)
                                       (generation <integer>))
  (cond ((= generation (ref metainfo 'generation))
         (signature->slot-definitions (ref metainfo 'signature)))
        ((assv-ref (ref metainfo 'signature-alist) generation)
         => signature->slot-definitions)
        (else
         (error "persistent-class-slots: class ~a doesn't have generation ~a"
                (ref metainfo 'name) generation))))

;; When an instance of a persistent class is realized for the first
;; time within the process, the in-memory class and the in-DB class
;; are compared.
(define-method persistent-class-bind-metainfo ((class <kahua-persistent-meta>))

  ;; check if two signatures are the same
  (define (signature=? x y) (equal? x y))

  ;; set generation numbers
  (define (set-generation! in-mem in-db metainfo)
    (set! (ref class 'metainfo) metainfo)
    (set! (ref class 'generation) in-mem)
    (set! (ref class 'persistent-generation) in-db))
  
  ;; this class is fresh; create new metainfo.
  (define (register-metainfo signature)
    (let1 info (make <kahua-persistent-metainfo>
                 :name (class-name class)
                 :generation 0
                 :signature signature
                 :source-id-map `((,(ref class 'source-id) 0))
                 :signature-alist `())
      (kahua-db-sync)
      (set-generation! 0 0 info)
      info))

  ;; signature doesn't match.  see if the in-memory class is older than
  ;; the in-db class, and if so, returns the (generation . signature)
  (define (find-generation metainfo signature)
    (and-let* ((idmap (ref metainfo 'source-id-map))
               (generations (assoc-ref idmap (ref class 'source-id))))
      (find (lambda (gen&sig)
              (signature=? (cdr gen&sig) signature))
            (filter-map (cut assv <> (ref metainfo 'signature-alist))
                        generations))))

  ;; we couldn't find matching signature, so we assume the in-memory
  ;; class is newer.  record the newer class signature.
  (define (increment-generation metainfo signature)
    (let* ((oldgen (ref metainfo 'generation))
           (newgen (+ oldgen 1))
           (oldsig (ref metainfo 'signature)))
      (slot-push! metainfo 'signature-alist (cons oldgen oldsig))
      (slot-push! metainfo 'translator-alist
                  (cons oldgen
                        (compute-translation-directive
                         (signature->slot-definitions oldsig)
                         (signature->slot-definitions signature))))
      (set! (ref metainfo 'generation) newgen)
      (set! (ref metainfo 'signature) signature)
      (record-source-id metainfo newgen)
      (set-generation! newgen newgen metainfo)))

  ;; register class' source-id to metainfo
  (define (record-source-id metainfo new-generation)
    (let* ((source-id (ref class 'source-id))
           (p (assoc source-id (ref metainfo 'source-id-map))))
      (if p
        (unless (memv new-generation (cdr p))
          (set-cdr! p (cons new-generation (cdr p)))
          ;; touch the slot, so that it is reflected to db later.
          (set! (ref metainfo 'source-id-map)
                (ref metainfo 'source-id-map)))
        (push! (ref metainfo 'source-id-map)
               (list source-id new-generation)))))

  ;; Main part of persistent-class-bind-metainfo
  (or (eq? (class-name class) '<kahua-persistent-metainfo>)
      (let ((metainfo (find-kahua-instance <kahua-persistent-metainfo>
                                           (x->string (class-name class))))
            (signature (persistent-class-signature class)))
        (cond ((not metainfo) (register-metainfo signature))
              ((signature=? (ref metainfo 'signature) signature)
               ;; in-memory class is up to date.
               (let1 gen (ref metainfo 'generation)
                 (record-source-id metainfo gen)
                 (set-generation! gen gen metainfo)))
              ((find-generation metainfo signature)
               => (lambda (gen&sig)
                    (set-generation! (car gen&sig)
                                     (ref metainfo 'generation)
                                     metainfo)))
              (else
               (increment-generation metainfo signature)))))
  )

;; Translating between in-db slot value alist and in-memory slots
;;
;;   export-slot-values - given in-memory object, extracts
;;     persistent slot values and translates it to fit the
;;     in-db class, and returns three values: the instance generation,
;;     alist of persistent slot values, and alist of saved (hidden)
;;     slot values.
;;
;;   import-slot-values - given alist of slot names & values which
;;     fits in in-db class, translates it to the in-memory slots,
;;     and returns two values: translated slot value alist and
;;     'saved' slot value alist, which contains the information that
;;     exists in-db but not in-memory.
;;
;; Case-by-case analysis of slot translation:
;;
;;   Importing (reading):
;;   * in-db version > in-memory version
;;     DB has been updated, but our process is running with
;;     older source.  If we see an added slot (a slot that exists in-db
;;     but not in-memory), we put it to the hidden-slot-values alist,
;;     so that the value will be kept.  If we see a removed slot
;;     (a slot that exists in-memory but not in-db), we may find the
;;     old value kept in the hidden-slot-values of in-db instance;
;;     otherwise, we leave it out to be initialized in a default way.
;;
;;   * in-memory version < in-db version
;;     We are running newer version.   If we see an added slot (a slot
;;     that exists in-memory but not in-db), we leave it missing so it
;;     is initialized by the default way.  If we see a deleted slot
;;     (a slot that exists in-db but not in-memory), we keep the value
;;     in the hidden-slot-values alist.
;;
;;   Exporting (writing):
;;   * in-db version > in-memory version
;;     If in-db version has added slot, whose value should have been
;;     stored in the hidden-slot-values alist, so we recover the value
;;     from it.
;;
;;   * in-memory version > in-db version
;;     We update in-db version.  The value stored in the hidden-slot-values
;;     are saved as is, so that other processes which uses older versions
;;     can still access the older values.

(define (export-slot-values obj)

  (define (default-slot-values)
    (filter-map (lambda (s)
                  (and (eq? (slot-definition-allocation s) :persistent)
                       (cons (slot-definition-name s)
                             (slot-ref obj (slot-definition-name s)))))
                (class-slots (class-of obj))))

  (let* ((class  (class-of obj))
         (c-gen  (ref class 'generation))
         (p-gen  (ref obj '%persistent-generation))
         (hidden (ref obj '%hidden-slot-values)))
    (if (<= p-gen c-gen)
      (values c-gen (default-slot-values) hidden)
      ;; db is newer.  we need to upgrade in-memory instance.
      (let loop ((gen c-gen)
                 (vals (default-slot-values))
                 (hidden hidden))
        (if (= p-gen gen)
          (values p-gen vals hidden)
          (receive (vals hidden) (translate-up class gen vals hidden)
            (loop (+ gen 1) vals hidden)))))
    ))

(define (import-slot-values class p-gen alist)
  (let ((hidden (assq-ref alist '%hidden-slot-values '()))
        (vals   (alist-delete '%hidden-slot-values alist)))
    (if (eq? (class-name class) '<kahua-persistent-metainfo>)
      (values vals hidden) ;; metainfo isn't managed by generations.
      (let ((c-gen (and (ensure-metainfo class)
                        (ref class 'generation))))

        (define (downgrade gen vals hidden)
          (if (= gen c-gen)
            (values vals hidden)
            (receive (vals hidden) (translate-down class gen vals hidden)
              (downgrade (- gen 1) vals hidden))))

        (define (upgrade gen vals hidden)
          (if (= gen c-gen)
            (values vals hidden)
            (receive (vals hidden) (translate-up class gen vals hidden)
              (upgrade (+ gen 1) vals hidden))))

        ;; Main part of import-slot-values
        (cond ((eqv? c-gen p-gen)
               (values vals hidden)) ;; we are up to date.
              ((< c-gen p-gen)
               (downgrade p-gen vals hidden))
              ((> c-gen p-gen)
               (upgrade p-gen vals hidden)))
        ))))

;; Given two slot list A and B, returns a list of translation directive.
;; <translation-directive> : (<slot-name> . <description>)
;; <description> : :drop   ;; slot is only in A (so it is dropped to make B)
;;               | :add    ;; slot is only in B (so it is added to make B)
;; Assumes both input slot list are sorted.
;; Slots common in both A and B aren't included in the directive list.

(define (compute-translation-directive A-slots B-slots)
  (let loop ((A-slots A-slots) (B-slots B-slots) (dirs '()))
    (cond ((null? A-slots)
           (append! dirs (map (lambda (s) (cons (car s) :drop)) B-slots)))
          ((null? B-slots)
           (append! dirs (map (lambda (s) (cons (car s) :add)) A-slots)))
          ((eq? (caar A-slots) (caar B-slots))
           (loop (cdr A-slots) (cdr B-slots) dirs))
          ((string<? (symbol->string (caar A-slots))
                     (symbol->string (caar B-slots)))
           (loop (cdr A-slots) B-slots (acons (caar A-slots) :drop dirs)))
          (else
           (loop A-slots (cdr B-slots) (acons (caar B-slots) :add dirs))))
    ))

;; Given translation directive and slot value alist, returns
;; a translated slot value alist and hidden slot value alist.
;; Which indicates the conversion direction; either a->b or b->a.
(define (translate-slot-alist directive alist hidden which)
  (let ((src (case which ((a->b) :drop) ((b->a) :add))))

    ;; slot dropped; move the slot value from r to h, if any.
    (define (drop-slot slot r h)
      (cond ((assq slot r) =>
             (lambda (p) (values (alist-delete (car p) r)
                                 (assq-set! h (car p) (cdr p)))))
            (else (values r h))))

    ;; slot added; move the slot value from h to r, if any.
    (define (add-slot slot r h)
      (cond ((assq slot h) =>
             (lambda (p) (values (assq-set! r (car p) (cdr p))
                                 (alist-delete (car p) h))))
            (else (values r h))))

    ;; loop over directive
    (define (translate dir r h)
      (cond ((null? dir)
             (values r h))
            ((eqv? (cdar dir) src)  ;; source dropped
             (receive (r h) (drop-slot (caar dir) r h)
               (translate (cdr dir) r h)))
            (else
             (receive (r h) (add-slot (caar dir) r h)
               (translate (cdr dir) r h)))))
    (translate directive alist hidden)))

(define (translate-up class generation alist hidden)
  (let* ((info (ensure-metainfo class))
         (dir (assq-ref (ref info 'translator-alist) generation)))
    (if (not dir)
      (begin
        (warn "class translator doesn't exist: class ~a, generation ~a"
              (class-name class) generation)
        alist)
      (translate-slot-alist dir alist hidden 'a->b))))

(define (translate-down class generation alist hidden)
  (let* ((info (ensure-metainfo class))
         (dir (assq-ref (ref info 'translator-alist) (- generation 1))))
    (if (not dir)
      (begin
        (warn "class translator doesn't exist: class ~a, generation ~a"
              (class-name class) (- generation 1))
        alist)
      (translate-slot-alist dir alist hidden 'b->a))))

;;=========================================================
;; Database
;;

;; Database class -----------------------------------------
(define current-db (make-parameter #f))

(define-class <kahua-db> ()
  ((path       :init-keyword :path :init-value #f)
   (id-counter :init-keyword :id-counter :init-value 0)
   (active     :init-keyword :active :init-value #f)
   (lock-port  :init-value #f) ;; port opened on lock file
   (instance-by-id  :init-form (make-hash-table 'eqv?))
   (instance-by-key :init-form (make-hash-table 'equal?))
   (modified-instances :init-form '())
   ))

(define-method write-object ((obj <kahua-db>) port)
  (format port "#<kahua-db ~s (~a)>"
          (ref obj 'path)
          (if (ref obj 'active) "active" "inactive")))

(define (kahua-db-unique-id)
  (unless (current-db)
    (error "kahua-db-unique-id: No db is active"))
  (begin0 (ref (current-db) 'id-counter)
          (inc! (ref (current-db) 'id-counter))))

(define-syntax with-db
  (syntax-rules ()
    ((with-db (db dbpath) . body)
     (if (and (current-db)
              (ref (current-db) 'active)
              (equal? (ref (current-db) 'path) dbpath))
       (begin . body)
       (let ((db (kahua-db-open dbpath)))
         (parameterize ((current-db db))
           (with-error-handler
               (lambda (e) (kahua-db-close db #f) (raise e))
             (lambda ()
               (begin0 (begin . body) (kahua-db-close db #t))))))))))

(define (id-counter-path path)
  (build-path path "id-counter"))

;; lock mechanism - we need more robust one later, but just for now...
(define (lock-file-path path)
  (build-path path "lock"))

(define (lock-db db)
  (let1 lock-file (lock-file-path (ref db 'path))
    (unless (file-exists? lock-file)
      ;; This is an old db.  This is only transitional, and may
      ;; be called very rarely, so we just leave this though unsafe.
      (with-output-to-file lock-file (lambda () (newline))))
    (let ((record    (make <sys-flock> :type F_WRLCK))
          (lock-port (open-output-file lock-file :if-exists? :append)))
      (define (try-lock retry)
        (cond ((zero? retry) #f)
              ((sys-fcntl lock-port F_SETLK record)
               (set! (ref db 'lock-port) lock-port) #t)
              (else (sys-sleep 1) (try-lock (- retry 1)))))
      (try-lock 10))))

(define (unlock-db db)
  (and-let* ((lock-port (ref db 'lock-port))
             (record (make <sys-flock> :type F_UNLCK)))
    (sys-fcntl lock-port F_SETLK record)
    #t))

(define (kahua-db-open path)
  (let ((cntfile (id-counter-path path)))
    (if (file-is-directory? path)
      (if (file-is-regular? cntfile)
        (let1 db 
            (make <kahua-db>
              :path path :active #t
              :id-counter (with-input-from-file cntfile read))
          (unless (lock-db db)
            (error "kahua-db-open: couldn't obtain database lock: " path))
          db)
        (error "kahua-db-open: path is not a db: " path))
      (begin
        ;; There could be a race condition here, but it would be very
        ;; low prob., so for now it should be OK.
        (make-directory* path)
        (make-directory* (build-path path "tmp"))
        (with-output-to-file cntfile (cut write 0))
        (let1 db (make <kahua-db> :active #t :path path)
          (unless (lock-db db)
            (error "kahua-db-open: couldn't obtain database lock: " path))
          db))
      )))

(define (kahua-db-sync . maybe-db)
  (let1 db (get-optional maybe-db (current-db))
    (for-each (cut write-kahua-instance db <>)
              (ref db 'modified-instances))
    (set! (ref db 'modified-instances) '())))

(define (kahua-db-close db commit)
  (when commit
    (with-output-to-file (id-counter-path (ref db 'path))
      (cut write (ref db 'id-counter)))
    (kahua-db-sync db))
  (unlock-db db)
  (set! (ref db 'modified-instances) '())
  (set! (ref db 'active) #f))

(define (data-path db class . key)
  (apply build-path
         (ref db 'path)
         (string-trim-both (x->string (class-name class)) #[<>])
         key))

;; Instance I/O ----------------------------------------------

(define (id->kahua-instance id)
  (unless (current-db)
    (error "id->kahua-instance: No db is active"))
  (hash-table-get (ref (current-db) 'instance-by-id) id #f))

(define (class&key->kahua-instance class key)
  (unless (current-db)
    (error "clas&key->kahua-instance: No db is active"))
  (hash-table-get (ref (current-db) 'instance-by-key)
                  (cons (class-name class) key) #f))

(define (find-kahua-instance class key)
  (let1 db (current-db)
    (unless db (error "find-kahua-instance: No database is active"))
    (or (class&key->kahua-instance class key)
        (and (file-exists? (data-path db class key))
             (read-kahua-instance db class key)))))

(define-method read-kahua-instance ((db <kahua-db>)
                                    (class <kahua-persistent-meta>)
                                    (key <string>))
  (call-with-input-file (data-path db class key) read))

(define-method write-kahua-instance ((db <kahua-db>)
                                     (obj <kahua-persistent-base>))
  (let* ((path  (data-path db (class-of obj) (key-of obj))))
    (make-directory* (sys-dirname path))
    (receive (p tmp) (sys-mkstemp (build-path (ref db 'path) "tmp"))
      (with-error-handler
          (lambda (e) (sys-unlink tmp) (raise e))
        (lambda ()
          (kahua-write obj p)
          (close-output-port p)
          (sys-rename tmp path))))))

;;=========================================================
;; "View" as a collection
;;

;; NB: right now, we read all the instances into memory at once.
;; Later we can change the back-end to read it lazily.

(define-class <kahua-collection> (<collection>)
  ((instances :init-keyword :instances :init-value '()))
  )

(define-method make-kahua-collection ((class <kahua-persistent-meta>) . opts)
  (let1 db (current-db)
    (unless db (error "make-kahua-collection: database not active"))
    (make <kahua-collection>
      :instances (map (cut find-kahua-instance class <>)
                      (if (file-is-directory? (data-path db class))
                        (directory-list (data-path db class) :children? #t)
                        '())))))

(define-method call-with-iterator ((coll <kahua-collection>) proc . opts)
  (let1 p (ref coll 'instances)
    (proc (cut null? p)
          (lambda () (let1 r (car p) (pop! p) r)))))
    
(provide "kahua/persistence")
