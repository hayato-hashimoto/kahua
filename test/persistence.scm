;; test kahua.persistence
;; Kahua.persistence�⥸�塼��Υƥ���

;; $Id: persistence.scm,v 1.8 2005/12/30 09:23:10 shibata Exp $

(use gauche.test)
(use gauche.collection)
(use file.util)
(use util.list)

;; A hook to use this file for both stand-alone test and
;; DBI-backed-up test.
(define *dbname*
  (if (symbol-bound? '*dbname*)
    (begin (test-start #`"persistence/dbi (,*dbname*)")
           *dbname*)
    (begin (test-start "persistence")
           (build-path (sys-getcwd) "_tmp"))))
(sys-system #`"rm -rf ,*dbname*")

(define-syntax with-clean-db
  (syntax-rules ()
    ((_ (db dbpath) . body)
     (with-db (db dbpath)
       (kahua-db-purge-objs)
       . body))))

;; ���ɥƥ���:
;;   kahua.persistentce�����ɤǤ����ޤ����Υ��󥿥ե�������
;;   �������ʤ����Ȥ��ǧ���롣
(use kahua.persistence)
(test-module 'kahua.persistence)

;;----------------------------------------------------------
;; ����Ū�ʥƥ���
(test-section "database basics")

;;  ¸�ߤ��ʤ��ǡ����١���̾��Ϳ���ƥǡ����١����򥪡��ץ󤷡�
;;  �ǡ����١�������������������뤳�Ȥ��ǧ���롣
(test* "creating database" '(#t #t #t)
       (with-db (db *dbname*)
         (cons (is-a? db <kahua-db>)
               (if (is-a? db <kahua-db-fs>)
                 (list
                  (file-is-directory? *dbname*)
                  (file-exists? (build-path *dbname* "id-counter")))
                 (list
                  (is-a? (ref db 'connection) <dbi-connection>)
                  (is-a? (ref db 'query) <dbi-query>))))))

;;  �ǡ����١�����with-db��ưŪ�����������ͭ���Ǥ��ꡢ
;;  ���γ���̵���ˤʤ뤳�Ȥ��ǧ���롣
(test* "database activeness" '(#t #f)
       (receive (db active?)
           (with-db (db *dbname*) (values db (ref db 'active)))
         (list active? (ref db 'active))))

;;----------------------------------------------------------
;; ���󥹥��󥹺����ƥ���
(test-section "instances")

;;  ��������³���饹������������줬��³�᥿���饹<kahua-persistent-meta>��
;;  ��Ͽ����Ƥ��뤳�Ȥ��ǧ���롣
(define-class <kahua-test> (<kahua-persistent-base>)
  ((quick :allocation :persistent :init-keyword :quick :init-value 'i)
   (quack :init-keyword :quack :init-value 'a)
   (quock :allocation :persistent :init-keyword :quock :init-value 'o))
  :source-id "Rev 1")

(define-method list-slots ((obj <kahua-test>))
  (map (cut ref obj <>) '(id quick quack quock)))

(define (get-test-obj id)
  (find-kahua-instance <kahua-test> (format "~6,'0d" id)))

(test* "metaclass stuff" (list #t <kahua-test>)
       (list (is-a? <kahua-test> <kahua-persistent-meta>)
             (find-kahua-class '<kahua-test>)))

;;  ��³���󥹥��󥹤������������åȤ����������Ƥ��뤳�ȳ�ǧ���롣
(test* "creation (1)" '(1 ii aa "oo")
       (with-clean-db (db *dbname*)
         (list-slots (make <kahua-test> :quick 'ii :quack 'aa :quock "oo"))))

;;  �Ƥӥȥ�󥶥������򳫻Ϥ�����������������³���֥������Ȥ�������
;;  ���Ȥ��ǧ���롣
(test* "read (1)" '(1 ii a "oo")
       (with-clean-db (db *dbname*)
         (list-slots (get-test-obj 1))))

;;  �ҤȤĤΥȥ�󥶥������Ǥ��ѹ��������Υȥ�󥶥������ˤ��ݻ������
;;  ���뤳�Ȥ��ǧ���롣
(test* "modify (1)" '(1 "II" a "oo")
       (begin
         (with-clean-db (db *dbname*)
           (set! (ref (get-test-obj 1) 'quick) "II"))
         (with-clean-db (db *dbname*)
           (list-slots (get-test-obj 1))))
       )

;;  �⤦��Ĥα�³���󥹥��󥹤���������ѹ�����ǽ�Ǥ��뤳�Ȥ��ǧ���롣
;;  �ޤ��������ѹ�����������������³���󥹥��󥹤ˤϱƶ����ʤ����Ȥ�
;;  ��ǧ���롣
(test* "creation (2)" '(2 hh bb "pp")
       (with-clean-db (db *dbname*)
         (list-slots (make <kahua-test> :quick 'hh :quack 'bb :quock "pp"))))

(test* "modify (2)" '(2 "hh" a "PP")
       (begin
         (with-clean-db (db *dbname*)
           (set! (ref (get-test-obj 2) 'quick) "hh")
           (set! (ref (get-test-obj 2) 'quock) "PP"))
         (with-clean-db (db *dbname*)
           (list-slots (get-test-obj 2))))
       )

(test* "read (1)" '(1 "II" a "oo")
       (with-clean-db (db *dbname*)
         (list-slots (get-test-obj 1))))

;;  ��³���饹�������ֹ椬���������������Ƥ��뤳�ȡ����ʤ��
;;  in-memory�����in-db�����0�Ǥ��뤳�Ȥ��ǧ���롣
(test* "generation" '(0 0)
       (with-clean-db (db *dbname*)
         (list (ref <kahua-test> 'generation)
               (ref <kahua-test> 'persistent-generation))))

;;----------------------------------------------------------
;; �ȥ�󥶥������˴ؤ���ƥ���
(test-section "transaction")

;;   ��³���󥹥����ѹ���˥ȥ�󥶥�������error�����Ǥ���
;;   �Ƥӥȥ�󥶥������򳫻Ϥ��ơ���³���󥹥��󥹤��ѹ������
;;   ���ʤ����Ȥ��ǧ���롣
(test* "abort transaciton" '(2 "hh" a "PP")
       (with-error-handler
           (lambda (e)
             (with-clean-db (db *dbname*)
               (list-slots (get-test-obj 2))))
         (lambda ()
           (with-clean-db (db *dbname*)
             (set! (ref (get-test-obj 2) 'quick) 'whoops)
             (error "abort!")))))

;;   ��³���󥹥����ѹ���˰������commit���Ƥ���ޤ����󥹥��󥹤�
;;   �ѹ������ȥ�󥶥�������error�����Ǥ��롣
;;   �Ƥӥȥ�󥶥������򳫻Ϥ��ơ���³���󥹥��󥹤����commit�ޤǤ�
;;   �ѹ������������ʹߤ��ѹ��ϼ����Ƥ��ʤ����Ȥ��ǧ���롣
(test* "commit & abort" '(2 whoops a "PP")
       (with-error-handler
           (lambda (e)
             (with-clean-db (db *dbname*)
               (list-slots (get-test-obj 2))))
         (lambda ()
           (with-clean-db (db *dbname*)
             (set! (ref (get-test-obj 2) 'quick) 'whoops)
             (kahua-db-sync db)
             (set! (ref (get-test-obj 2) 'quock) 'whack)
             (error "abort!")))))

;;----------------------------------------------------------
;; ��³���֥������ȴ֤λ��Ȥ˴ؤ���ƥ���
(test-section "references")

;;   ��³���֥������Ȥؤλ��Ȥ��̤α�³���֥������ȤΥ���åȤ˥��åȤ���
;;   ���ߥåȤǤ��뤳�Ȥ��ǧ���롣
(test* "reference write" #t
       (with-clean-db (db *dbname*)
         (set! (ref (get-test-obj 1) 'quick) (get-test-obj 2))
         (is-a? (ref (get-test-obj 1) 'quick) <kahua-test>)))

;;   �ƤӤ�Ȥα�³���֥������Ȥ��ɤ߽Ф���������α�³���֥������Ȥ�
;;   �������ɤޤ�Ƥ��뤳�Ȥ��ǧ���롣
(test* "reference read" '(2 whoops a "PP")
       (with-clean-db (db *dbname*)
         (list-slots (ref (get-test-obj 1) 'quick))))

;;   �դ��Ĥα�³���֥������Ȥ���ߤ˻��Ȥ�������¤������������줬
;;   ���ߥåȤǤ��뤳�Ȥ��ǧ���롣
(test* "circular reference write" '(#t #t)
       (with-clean-db (db *dbname*)
         (set! (ref (get-test-obj 2) 'quick) (get-test-obj 1))
         (list (eq? (get-test-obj 1) (ref (get-test-obj 2) 'quick))
               (eq? (get-test-obj 2) (ref (get-test-obj 1) 'quick)))))

;;   ���������۴Ļ��ȹ�¤��Ƥ��ɤ߽Ф�����¤���������Ƹ�����Ƥ���
;;   ���Ȥ��ǧ���롣
(test* "circular reference read" '(#t #t)
       (with-clean-db (db *dbname*)
         (list (eq? (get-test-obj 1) (ref (get-test-obj 2) 'quick))
               (eq? (get-test-obj 2) (ref (get-test-obj 1) 'quick)))))

;;----------------------------------------------------------
;; ���饹�����
(test-section "class redefinition")

;(with-clean-db (db *dbname*) (kahua-db-purge-objs))

;; ��³���饹���������롣����åȤ��ѹ����ϰʲ����̤ꡣ

;; Slot changes:
;;  quick - no change (persistent)
;;  quack - no change (transient)
;;  muick - added (persistent)
;;  quock - changed (persistent -> virtual)
(define-class <kahua-test> (<kahua-persistent-base>)
  ((quick :allocation :persistent :init-keyword :quick :init-value 'i)
   (quack :init-keyword :quack :init-value 'a)
   (muick :allocation :persistent :init-keyword :muick :init-value 'm)
   (quock :allocation :virtual
          :slot-ref  (lambda (o) (ref o 'quick))
          :slot-set! (lambda (o v) #f))  ;; to vanish
   )
  :source-id "Rev 2")

;;   ���֥������ȥޥ͡�����ˡ���������줿���饹����Ͽ����Ƥ��뤳�Ȥ��ǧ��
(test* "redefining class" <kahua-test>
       (find-kahua-class '<kahua-test>))

;;   ���󥹥��󥹤����������饹���б����ƥ��åץǡ��Ȥ���뤳�Ȥ��ǧ���롣
(test* "updating instance for new class" #t
       (with-clean-db (db *dbname*)
         (eq? (ref (get-test-obj 1) 'quick)
              (ref (get-test-obj 1) 'quock))))

(test* "updating instance for new class" '(#t #t)
       (with-clean-db (db *dbname*)
         (list (equal? (list-slots (ref (get-test-obj 1) 'quock))
                       (list-slots (get-test-obj 2)))
               (equal? (list-slots (ref (get-test-obj 2) 'quock))
                       (list-slots (get-test-obj 1))))))

;;   ���åץǡ��Ȥ������󥹥��󥹤��Ф����ѹ����ǡ����١�����ȿ�Ǥ���뤳�Ȥ�
;;   ��ǧ���롣
(test* "redefining class (write)" '("M" "M" "M")
       (with-clean-db (db *dbname*)
         (set! (ref (get-test-obj 1) 'muick) '("M" "M" "M"))
         (ref (get-test-obj 1) 'muick)))

(test* "redefining class (read)" '("M" "M" "M")
       (with-clean-db (db *dbname*)
         (ref (get-test-obj 1) 'muick)))

;;   �����������³���饹�������ֹ椬���󥯥���Ȥ���Ƥ��뤳�Ȥ��ǧ���롣
(test* "generation" '(1 1)
       (with-clean-db (db *dbname*)
         (list (ref <kahua-test> 'generation)
               (ref <kahua-test> 'persistent-generation))))

;;----------------------------------------------------------
;; ���֥��饹�Υƥ���
(test-section "subclassing")

;(with-clean-db (db *dbname*) (kahua-db-purge-objs))

;;   ��³���饹<kahua-test>��Ѿ��������֥��饹��������롣
(define-class <kahua-test-sub> (<kahua-test>)
  ((woo :allocation :persistent :init-keyword :woo :init-value "W")
   (boo :allocation :persistent :init-keyword :boo :init-value "B")
   ;; this shadows parent's quock
   (quock :allocation :persistent :init-keyword :quock :init-value #f))
  :source-id "Rev 3")

(define-method list-slots ((obj <kahua-test-sub>))
  (map (cut ref obj <>) '(id quick quack woo boo quock)))

(define-method key-of ((obj <kahua-test-sub>))
  (string-append (ref obj 'woo) (ref obj 'boo)))

;;   ���֥��饹�α�³���󥹥��󥹤��������������졢�Ѿ����줿����åȡ�
;;   �ɲä��줿����åȡ����˥ǡ�������³������뤳�Ȥ��ǧ���롣
(test* "write" '(4 "quick" "quack" "woo" "boo" "quock")
       (with-clean-db (db *dbname*)
         (list-slots
          (make <kahua-test-sub> :quick "quick" :quack "quack"
                :woo "woo" :boo "boo" :quock "quock"))))

(test* "read"  '(4 "quick" a "woo" "boo" "quock")
       (with-clean-db (db *dbname*)
         (list-slots (find-kahua-instance <kahua-test-sub> "wooboo"))))

(test* "write" '(5 i a "wooo" "booo" #f)
       (with-clean-db (db *dbname*)
         (list-slots
          (make <kahua-test-sub> :woo "wooo" :boo "booo"))))

(test* "read"  '(5 i a "wooo" "booo" #f)
       (with-clean-db (db *dbname*)
         (list-slots (find-kahua-instance <kahua-test-sub> "wooobooo"))))

;;   �ƥ��饹�α�³���󥹥��󥹤ؤλ��Ȥ�ޤ๽¤���������
;;   ���줬�ǡ����١�����ȿ�Ǥ���뤳�Ȥ��ǧ���롣
(test* "reference to parent (write)" #t
       (with-clean-db (db *dbname*)
         (let1 obj (find-kahua-instance <kahua-test-sub> "wooboo")
           (set! (ref obj 'quick) (get-test-obj 1))
           (eq? (ref obj 'quick) (get-test-obj 1)))))

(test* "reference to parent (read)" #t
       (with-clean-db (db *dbname*)
         (let1 obj (find-kahua-instance <kahua-test-sub> "wooboo")
           (eq? (ref obj 'quick) (get-test-obj 1)))))

;;   ���λҥ��饹�������ֹ椬���������Ƥ��뤳�Ȥ��ǧ���롣
(test* "generation" '(0 0)
       (with-clean-db (db *dbname*)
         (list (ref <kahua-test-sub> 'generation)
               (ref <kahua-test-sub> 'persistent-generation))))

;;----------------------------------------------------------
;; ��³���֥������ȥ��쥯�����<kahua-collection>�˴ؤ���ƥ���
(test-section "collection")

;;  <kahua-test>��³���饹�������<kahua-test-sub>��³���饹����
;;  ���Υ��饹�α�³���󥹥��󥹤Υ��쥯����󤬺����Ǥ��뤳�Ȥ�
;;  ��ǧ���롣
(test* "kahua-test" '(1 2)
       (sort (with-clean-db (db *dbname*)
               (map (cut ref <> 'id)
                    (make-kahua-collection <kahua-test>)))))

(test* "kahua-test-sub" '("woo" "wooo")
       (sort (with-clean-db (db *dbname*)
               (map (cut ref <> 'woo)
                    (make-kahua-collection <kahua-test-sub>)))))

;; This tests instance-by-key table initialization protocol
;; ��³���쥯�����κ������ˡ�in-memory�ǡ����١����Υ���ǥå����ϥå��夬
;; ���������åȥ��åפ���뤳�Ȥ��ǧ���롣
(test* "kahua-test-sub" '((<kahua-test-sub> . "wooboo")
                          (<kahua-test-sub> . "wooobooo"))
       (with-clean-db (db *dbname*)
         (make-kahua-collection <kahua-test-sub>)
         (sort (hash-table-keys (ref db 'instance-by-key))
               (lambda (a b) (string<? (cdr a) (cdr b))))))

;; <kahua-test>�ȡ�����subclass�Ǥ���<kahua-test-sub>ξ�ԤȤ��
;; ��³���󥹥��󥹤Υ��쥯������<kahua-test>���Ф���
;; make-kahua-collection���Ѥ��ƺ����Ǥ��뤳�Ȥ��ǧ���롥
(test* "kahua-test-subclasses" '(1 2 4 5)
       (sort (with-clean-db (db *dbname*)
               (map (cut ref <> 'id)
                    (make-kahua-collection <kahua-test> :subclasses #t)))))

;;----------------------------------------------------------
;; �᥿��������˴ؤ���ƥ��ȡ���³���饹���ѹ��򥪥֥������ȥޥ͡�����
;; ��ǧ�����������ֹ��ưŪ����Ϳ���ƴ������Ƥ��뤳�Ȥ��ǧ���롣
(test-section "metainfo history")

;; Tests source-id change
;;   ����å�������Ѥ�����source-id�������Ѥ�����³���饹����������
;;   ��³���饹�������ֹ椬�Ѳ����ʤ����ȡ��ѹ�����source-id���������ֹ�ؤ�
;;   �ޥåԥ󥰤����������ꤵ��Ƥ��뤳�Ȥ��ǧ���롣
(define-class <kahua-test-sub> (<kahua-test>)
  ((woo :allocation :persistent :init-keyword :woo :init-value "W")
   (boo :allocation :persistent :init-keyword :boo :init-value "B")
   ;; this shadows parent's quock
   (quock :allocation :persistent :init-keyword :quock :init-value #f))
  :source-id "Rev 4")

(test* "generation with source-id change"
       '("1B" 0 0 (0))
       (with-clean-db (db *dbname*)
         (let1 ins (make <kahua-test-sub>
                     :woo "1" :quick 'q1 :muick 'm1 :quock 'o1)
           (list (key-of ins)
                 (ref <kahua-test-sub> 'generation)
                 (ref <kahua-test-sub> 'persistent-generation)
                 (assoc-ref (ref (ref <kahua-test-sub> 'metainfo)
                                 'source-id-map)
                            "Rev 4")))))

;;   ����ˡ�Source-id���ᤷ����³���饹������������³����åȰʳ���
;;   ����ѹ��Ǥϱ�³���饹�������ֹ椬�Ѳ����ʤ����ȡ������Source-id����
;;   �����ֹ�ؤΥޥåԥ󥰤��������ʤ����Ȥ��ǧ���롣
(define <kahua-test-sub-save> <kahua-test-sub>)

(define-class <kahua-test-sub> (<kahua-test>)
  ((woo :allocation :persistent :init-keyword :woo :init-value "W")
   (boo :allocation :persistent :init-keyword :boo :init-value "B")
   (bar :init-keyword :bar :init-value #f)
   ;; this shadows parent's quock
   (quock :allocation :persistent :init-keyword :quock :init-value #f))
  :source-id "Rev 3")

(test* "generation with source-id change (revert source-id)"
       '("2B" 0 0 (0))
       (with-clean-db (db *dbname*)
         (let1 ins (make <kahua-test-sub> :woo "2")
           (list (key-of ins)
                 (ref <kahua-test-sub> 'generation)
                 (ref <kahua-test-sub> 'persistent-generation)
                 (assoc-ref (ref (ref <kahua-test-sub> 'metainfo)
                                 'source-id-map)
                            "Rev 3")))))

;;   Source-id���ݤä��ޤޱ�³���饹�Υ���å�������ѹ�������³���饹��
;;   �����ֹ椬�ѹ�����뤳�ȡ����������source-id����������ֹ�ؤΥޥåפ�
;;   ʣ����������ꤵ��뤳�Ȥ��ǧ���롣
(define-class <kahua-test-sub> (<kahua-test>)
  ((woo :allocation :persistent :init-keyword :woo :init-value "W")
   (boo :allocation :persistent :init-keyword :boo :init-value "B")
   (bar :allocation :persistent :init-keyword :bar :init-value #f)
   ;; this shadows parent's quock
   (quock :allocation :persistent :init-keyword :quock :init-value #f))
  :source-id "Rev 3")

(test* "generation with source-id change (update)" '(1 1 (1 0))
       (with-clean-db (db *dbname*)
         (make <kahua-test-sub>
           :woo "3" :quick 'q3 :muick 'm3 :quock 'o3 :bar 'b3)
         (list (ref <kahua-test-sub> 'generation)
               (ref <kahua-test-sub> 'persistent-generation)
               (assoc-ref (ref (ref <kahua-test-sub> 'metainfo)
                               'source-id-map)
                          "Rev 3"))))

;;   �嵭��������ݤä��ޤޱ�³���饹��source-id���ѹ�����source-id����
;;   �����ֹ�ؤ�many-to-many�Υޥåԥ󥰤���������������Ƥ��뤳�Ȥ�
;;   ��ǧ���롣
(define-class <kahua-test-sub> (<kahua-test>)
  ((woo :allocation :persistent :init-keyword :woo :init-value "W")
   (boo :allocation :persistent :init-keyword :boo :init-value "B")
   (bar :allocation :persistent :init-keyword :bar :init-value #f)
   ;; this shadows parent's quock
   (quock :allocation :persistent :init-keyword :quock :init-value #f))
  :source-id "Rev 4")

(test* "generation with source-id change (change source-id)" '(1 1 (1 0))
       (with-clean-db (db *dbname*)
         (make <kahua-test-sub> :woo "4" :quock 'o4)
         (list (ref <kahua-test-sub> 'generation)
               (ref <kahua-test-sub> 'persistent-generation)
               (assoc-ref (ref (ref <kahua-test-sub> 'metainfo)
                               'source-id-map)
                          "Rev 4"))))

;;   �Ƥα�³���饹���������뤳�Ȥˤ�ä�<kahua-test-sub>�μ�ư�������
;;   �ȥꥬ���������ѹ����ǡ����١����Υ᥿��������ˤ�ȿ�Ǥ���뤳�Ȥ�
;;   ��ǧ���롣
;;   slot change: drop muick.
(define-class <kahua-test> (<kahua-persistent-base>)
  ((quick :allocation :persistent :init-keyword :quick :init-value 'i)
   )
  :source-id "Rev 3")

(test* "generation with source-id change (change parent)" '(2 2 (2 1 0))
       (with-clean-db (db *dbname*)
         (make-kahua-collection <kahua-test-sub>)
         (list (ref <kahua-test-sub> 'generation)
               (ref <kahua-test-sub> 'persistent-generation)
               (assoc-ref (ref (ref <kahua-test-sub> 'metainfo)
                               'source-id-map)
                          "Rev 4"))))

;;   ���Υƥ��ȤΤ���ˡ��⤦�������ѹ����Ƥ�����
;;   (�ƥ��饹�Ǻ�����줿����å�muick��ҥ��饹������)
(define-class <kahua-test-sub> (<kahua-test>)
  ((woo   :allocation :persistent :init-keyword :woo :init-value "W")
   (boo :allocation :persistent :init-keyword :boo :init-value "B")
   (bee :allocation :persistent :init-keyword :boo :init-value 'bee)
   (muick :allocation :persistent :init-keyword :muick :init-value #f))
  :source-id "Rev 5")

(test* "generation with source-id change (change source-id again)" '(3 3 (3))
       (with-clean-db (db *dbname*)
         (make <kahua-test-sub> :woo "5")
         (list (ref <kahua-test-sub> 'generation)
               (ref <kahua-test-sub> 'persistent-generation)
               (assoc-ref (ref (ref <kahua-test-sub> 'metainfo)
                               'source-id-map)
                          "Rev 5"))))

;;----------------------------------------------------------
;; ���󥹥��󥹤�����֤��ѹ��˴ؤ���ƥ��ȡ��ۤʤ�����α�³���饹��
;; �������줿���󥹥��󥹤˥�����������ݤˡ�����֤μ�ư�Ѵ����Ԥ���
;; ���Ȥ��ǧ���ʲ��Υ����ȤǤϡ�<kahua-test-sub>[n]������n��
;; <kahua-test-sub>���饹�Ǥ��뤳�Ȥ�ɽ�����롣
(test-section "instance translation")

;; �ƥ��ȳ������ˡ����ߤα�³���ȥ졼�������Ƥ��ǧ���Ƥ�����
;; ��³���饹<kahua-test-sub>�������ϰʲ����̤�Ǥ��롣
;; (����[4]�ϰʲ��Υƥ��������������)
;;
;; generation   [0]        [1]         [2]         [3]         [4]
;; ----------------------------------------------------------------
;; p-slots     quick       quick       quick       quick
;;             muick       muick                   muick
;;             woo         woo         woo         woo         woo
;;             boo         boo         boo         boo         boo
;;             quock       quock       quock                   quock
;;                         bar         bar                     bar
;;                                                 bee         bee
;; 
;; source-id   "Rev 3"     "Rev 3"     "Rev 4"     "Rev 5"     "Rev 6"
;;             "Rev 4"     "Rev 4"
;; -------------------------------------------------------
;;
;; ���ߤα�³���饹������
;;   in-memory class:  <kahua-test-sub>[3]
;;   in-db     class:  <kahua-test-sub>[3]
;; ���ߤα�³���󥹥��󥹤�in-db������
;;   "wooboo"    [0]
;;   "woobooo"   [0]
;;   "1B"        [0]
;;   "2B"        [0]
;;   "3B"        [1]
;;   "4B"        [1]
;;   "5B"        [3]

;;   �ޤ���<kahua-test-sub>[0]�Ǻ������줿��³���󥹥��󥹤��ɤ߽Ф���
;;   ���줬<kahua-test-sub>[3]�ι����˥��åץǡ��Ȥ���Ƥ��뤳�Ȥ��ǧ���롣
(test* "translation [0]->[3]"
       '(:slots 
         ((quick . q1) (muick . m1) (woo . "1") (boo . "B") (bee . beebee))
         :hidden
         ((quock . o1))
         :instance-generation 0)
       (with-clean-db (db *dbname*)
         (let1 obj (find-kahua-instance <kahua-test-sub> "1B")
           (set! (ref obj 'bee) 'beebee)
           (list :slots (map (lambda (s) (cons s (ref obj s)))
                             '(quick muick woo boo bee))
                 :hidden (ref obj '%hidden-slot-values)
                 :instance-generation (ref obj '%persistent-generation)))))

;;   ��ö <kahua-test-sub> �����������[2]���ᤷ�����󥹥���"1B"��
;;   ��������������[3]�Ǻ�����줿����å�quock���ͤ����褷�Ƥ��뤳�Ȥ�
;;   ��ǧ���롣

(define-class <kahua-test-sub> (<kahua-test>)
  ((woo   :allocation :persistent :init-keyword :woo :init-value "W")
   (boo :allocation :persistent :init-keyword :boo :init-value "B")
   (bar :allocation :persistent :init-keyword :bar :init-value #f)
   ;; this shadows parent's quock
   (quock :allocation :persistent :init-keyword :quock :init-value #f))
  :source-id "Rev 4")

(test* "translation [3]->[2]"
       '(:class-generations
         (2 3)
         :slots
         ((quick . q1) (woo . "1") (boo . "B") (quock . o1) (bar . #t))
         :hidden
         ((bee . beebee) (muick . m1))
         :instance-generation 3)
       (with-clean-db (db *dbname*)
         (let1 obj (find-kahua-instance <kahua-test-sub> "1B")
           (set! (ref obj 'bar) #t)
           (list :class-generations
                 (list (ref <kahua-test-sub> 'generation)
                       (ref <kahua-test-sub> 'persistent-generation))
                 :slots (map (lambda (s) (cons s (ref obj s)))
                             '(quick woo boo quock bar))
                 :hidden (ref obj '%hidden-slot-values)
                 :instance-generation (ref obj '%persistent-generation)))))

;;   ����[1]�Υ��󥹥���"3B"�ˤ⥢�������������줬����[2]�˥��åץǡ���
;;   ����뤳�Ȥ��ǧ���롣

(test* "translation [1]->[2]"
       '(:class-generations
         (2 3)
         :slots
         ((quick . q3) (woo . "3") (boo . "B") (quock . o3) (bar . b3))
         :instance-generation 1)
       (with-clean-db (db *dbname*)
         (let1 obj (find-kahua-instance <kahua-test-sub> "3B")
           (touch-kahua-instance! obj)
           (list :class-generations
                 (list (ref <kahua-test-sub> 'generation)
                       (ref <kahua-test-sub> 'persistent-generation))
                 :slots (map (lambda (s) (cons s (ref obj s)))
                             '(quick woo boo quock bar))
                 :instance-generation (ref obj '%persistent-generation)))))

;;   �Ƥ�<kahua-test-sub>�����������[3]���ᤷ�����󥹥���"1B", "3B"��
;;   ���줾�쥢���������롣"1B"������[2]���ᤷ���ݤ˾ä�������å�(bee)��
;;   �ڤӡ�"3B"������[2]�˰ܹԤ����ݤ˾ä�������å� (muick) �����褷�Ƥ���
;;   ���Ȥ��ǧ���롣�ޤ����Ʊ�³���󥹥��󥹤�����ϺǤ�ʤ������Τޤ�
;;   (���ʤ����"1B"�Ǥ�[3], "3B"�Ǥ�[2])�Ǥ��뤳�Ȥ��ǧ���롣

(define-class <kahua-test-sub> (<kahua-test>)
  ((woo   :allocation :persistent :init-keyword :woo :init-value "W")
   (boo :allocation :persistent :init-keyword :boo :init-value "B")
   (bee :allocation :persistent :init-keyword :boo :init-value 'bee)
   (muick :allocation :persistent :init-keyword :muick :init-value #f))
  :source-id "Rev 5")

(test* "translation [2]->[3]"
       '(:class-generations
         (3 3)
         :slots
         (((quick . q1) (woo . "1") (boo . "B") (muick . m1) (bee . beebee))
          ((quick . q3) (woo . "3") (boo . "B") (muick . m3) (bee . bee)))
         :instance-generation (3 2))
       (with-clean-db (db *dbname*)
         (let1 objs
             (list (find-kahua-instance <kahua-test-sub> "1B")
                   (find-kahua-instance <kahua-test-sub> "3B"))
           (for-each touch-kahua-instance! objs)
           (list :class-generations
                 (list (ref <kahua-test-sub> 'generation)
                       (ref <kahua-test-sub> 'persistent-generation))
                 :slots (map (lambda (obj)
                               (map (lambda (s) (cons s (ref obj s)))
                                    '(quick woo boo muick bee)))
                             objs)
                 :instance-generation (map (cut ref <> '%persistent-generation)
                                           objs)))))

;; �����ʳ��Ǥγƥ��󥹥��󥹤�in-db������ϼ��Τ褦�ˤʤäƤ��롣
;;   "wooboo"    [0]
;;   "wooobooo"  [0]
;;   "1B"        [3]
;;   "2B"        [0]
;;   "3B"        [3]
;;   "4B"        [1]
;;   "5B"        [3]

;;   ���٤�<kahua-test-sub>�����������[0]�ޤ��᤹������[0]�����[3]��
;;   ��³���󥹥���ʣ�����ɤ߽Ф������Ƥ�in-memory�Ǥ�����[0]��
;;   ���󥹥��󥹤ˤʤäƤ��뤳�Ȥ��ǧ���롣

(define-class <kahua-test> (<kahua-persistent-base>)
  ((quick :allocation :persistent :init-keyword :quick :init-value 'i)
   (quack :init-keyword :quack :init-value 'a)
   (muick :allocation :persistent :init-keyword :muick :init-value 'm)
   (quock :allocation :virtual
          :slot-ref  (lambda (o) (ref o 'quick))
          :slot-set! (lambda (o v) #f))
   )
  :source-id "Rev 2")

(define-class <kahua-test-sub> (<kahua-test>)
  ((woo :allocation :persistent :init-keyword :woo :init-value "W")
   (boo :allocation :persistent :init-keyword :boo :init-value "B")
   ;; this shadows parent's quock
   (quock :allocation :persistent :init-keyword :quock :init-value #f))
  :source-id "Rev 3")

(test* "translation [0]->[0]"
       '(:class-generations
         (0 3)
         :slots
         (((woo . "woo") (boo . "boo") (muick . m) (quock . "quock"))
          ((woo . "wooo") (boo . "booo") (muick . m) (quock . Q)))
         :instance-generation (0 0))
       (with-clean-db (db *dbname*)
         (let1 objs
             (list (find-kahua-instance <kahua-test-sub> "wooboo")
                   (find-kahua-instance <kahua-test-sub> "wooobooo"))
           (set! (ref (cadr objs) 'quock) 'Q)
           (list :class-generations
                 (list (ref <kahua-test-sub> 'generation)
                       (ref <kahua-test-sub> 'persistent-generation))
                 :slots (map (lambda (obj)
                               (map (lambda (s) (cons s (ref obj s)))
                                    '(woo boo muick quock)))
                             objs)
                 :instance-generation (map (cut ref <> '%persistent-generation)
                                           objs)))))

(test* "translation [3]->[0]"
       '(:slots
         (((woo . "1") (boo . "B") (muick . m1) (quock . o1))
          ((woo . "3") (boo . "B") (muick . m3) (quock . o3))
          ((woo . "5") (boo . "B") (muick . #f) (quock . QQ)))
         :instance-generation (3 3 3))
       (with-clean-db (db *dbname*)
         (let1 objs
             (list (find-kahua-instance <kahua-test-sub> "1B")
                   (find-kahua-instance <kahua-test-sub> "3B")
                   (find-kahua-instance <kahua-test-sub> "5B"))
           (set! (ref (caddr objs) 'quock) 'QQ)
           (list :slots (map (lambda (obj)
                               (map (lambda (s) (cons s (ref obj s)))
                                    '(woo boo muick quock)))
                             objs)
                 :instance-generation (map (cut ref <> '%persistent-generation)
                                           objs)))))


;;   �����ǡ�<kahua-test-sub>���������롣���٤�<kahua-test>��
;;   �Ѿ����ʤ����������������[4]�Ȥʤ뤳�Ȥ��ǧ���롣�ޤ���
;;   ������α�³���󥹥��󥹤��ɤ߹��ߡ�����餬�����������
;;   ���åץǡ��Ȥ���Ƥ��뤳�ȡ�����֤�translation�Ǿä�������å�
;;   ���ͤ������Ƥ��ʤ����ȡ����ǧ���롣

(define-class <kahua-test-sub> (<kahua-persistent-base>)
  ((woo :allocation :persistent :init-keyword :woo :init-value "W")
   (boo :allocation :persistent :init-keyword :boo :init-value "B")
   (quock :allocation :persistent :init-keyword :quock :init-value #f)
   (bar :allocation :persistent :init-keyword :bar :init-value #f)
   (bee :allocation :persistent :init-keyword :boo :init-value 'bee)
   )
  :source-id "Rev 6")

(test* "translation [0]->[4]"
       '(:class-generations
         (4 4)
         :slots
         (((woo . "woo") (boo . "boo") (quock . "quock") (bar . #f) (bee . bee))
          ((woo . "wooo") (boo . "booo") (quock . Q) (bar . wooobooo) (bee . bee))
          ((woo . "2") (boo . "B") (quock . #f) (bar . b2) (bee . bee)))
         :instance-generation (0 0 0))
       (with-clean-db (db *dbname*)
         (let1 objs
             (list (find-kahua-instance <kahua-test-sub> "wooboo")
                   (find-kahua-instance <kahua-test-sub> "wooobooo")
                   (find-kahua-instance <kahua-test-sub> "2B"))
           (set! (ref (cadr objs) 'bar) 'wooobooo)
           (set! (ref (caddr objs) 'bar) 'b2)
           (list :class-generations
                 (list (ref <kahua-test-sub> 'generation)
                       (ref <kahua-test-sub> 'persistent-generation))
                 :slots (map (lambda (obj)
                               (map (lambda (s) (cons s (ref obj s)))
                                    '(woo boo quock bar bee)))
                             objs)
                 :instance-generation (map (cut ref <> '%persistent-generation)
                                           objs)))))
       

(test* "translation [1]->[4]"
       '(:slots
         ((woo . "4") (boo . "B") (quock . o4) (bar . b4) (bee . bee))
         :instance-generation 1)
       (with-clean-db (db *dbname*)
         (let1 obj (find-kahua-instance <kahua-test-sub> "4B")
           (set! (ref obj 'bar) 'b4)
           (list :slots (map (lambda (s) (cons s (ref obj s)))
                             '(woo boo quock bar bee))
                 :instance-generation (ref obj '%persistent-generation)))))

(test* "translation [3]->[4]"
       '(:slots
         (((woo . "1") (boo . "B") (quock . o1) (bar . #t) (bee . beebee))
          ((woo . "3") (boo . "B") (quock . o3) (bar . b3) (bee . bee))
          ((woo . "5") (boo . "B") (quock . QQ) (bar . #f) (bee . bee)))
         :instance-generation (3 3 3))
       (with-clean-db (db *dbname*)
         (let1 objs
             (list (find-kahua-instance <kahua-test-sub> "1B")
                   (find-kahua-instance <kahua-test-sub> "3B")
                   (find-kahua-instance <kahua-test-sub> "5B"))
           (for-each touch-kahua-instance! objs)
           (list :slots (map (lambda (obj)
                               (map (lambda (s) (cons s (ref obj s)))
                                    '(woo boo quock bar bee)))
                             objs)
                 :instance-generation (map (cut ref <> '%persistent-generation)
                                           objs)))))

;;   ��ǥ��åץǡ��Ȥ�����³���󥹥��󥹤Τ������ѹ����������
;;   touch-kahua-instance! �ǡֿ���줿�פ�ΤΤߡ���³���󥹥��󥹤�
;;   ���夬��������Ƥ��뤳�Ȥ��ǧ���롣

(test* "translation (instances' persistent generations)"
       '(("1B" . 4) ("2B" . 4) ("3B" . 4) ("4B" . 4) ("5B" . 4)
         ("wooboo" . 0) ("wooobooo" . 4))
       (with-clean-db (db *dbname*)
         (sort
          (map (lambda (obj)
                 (cons (key-of obj)
                       (ref obj '%persistent-generation)))
               (make-kahua-collection <kahua-test-sub>))
          (lambda (a b)
            (string<? (car a) (car b))))))

;;----------------------------------------------------------
;; �ȥ�󥶥����������Υƥ���
(test-section "transaction / default(read-only, no-sync)")

(define-class <transaction-test-1> (<kahua-persistent-base>)
  ((a :init-value 0 :init-keyword :a :allocation :persistent)))

(define-method key-of ((self <transaction-test-1>))
  "key")

(test "ref out of transaction" 1
      (lambda ()
        (let1 object (with-clean-db (db *dbname*)
                       (make <transaction-test-1> :a 1))
          (ref object 'a))))

(test "write in other transaction" #t
      (lambda ()
        (with-clean-db (db *dbname*)
          (let1 object (find-kahua-instance <transaction-test-1> "key")
            (set! (ref object 'a) 2)))
        #t))

(test "check (write in other transaction" 2
      (lambda ()
        (with-clean-db (db *dbname*)
          (let1 object (find-kahua-instance <transaction-test-1> "key")
            (ref object 'a)))))

(test "set! out of transaction" *test-error*
      (lambda ()
        (let1 object (with-clean-db (db *dbname*)
                       (make <transaction-test-1> :a 1))
          (set! (ref object 'a) 1)
          #t)))

(test-section "transaction / access denied")

(define-class <transaction-test-2> (<kahua-persistent-base>)
  ((a :init-value 0 :init-keyword :a :allocation :persistent
      :out-of-transaction :denied)))

(test "ref out of transaction" *test-error*
      (lambda ()
        (let1 object (with-clean-db (db *dbname*)
                       (make <transaction-test-2> :a 0))
          (ref object 'a))))

(test "ref in other transaction" 1
      (lambda ()
        (let1 object (with-clean-db (db *dbname*)
                       (make <transaction-test-2> :a 1))
          (with-clean-db (db *dbname*)
            (ref object 'a)))))

(test "set! out of transaction" *test-error*
      (lambda ()
        (let1 object (with-clean-db (db *dbname*)
                       (make <transaction-test-2> :a 0))
          (set! (ref object 'a) 1))))

(test-section "transaction / read-only auto-sync")

(define-class <transaction-test-3> (<kahua-persistent-base>)
  ((key :init-value #f :init-keyword :key :allocation :persistent)
   (a :init-value 0 :init-keyword :a :allocation :persistent))
  :read-syncer :auto)

(define-method key-of ((self <transaction-test-3>))
  (ref self 'key))

(define (geto key)
  (with-clean-db (db *dbname*)
    (find-kahua-instance <transaction-test-3> key)))

(test "ref out of transaction" 0
      (lambda ()
        (let1 object (with-clean-db (db *dbname*)
                       (make <transaction-test-3> :key "0" :a 0))
          (ref object 'a))))

(define (other-transaction num)
  (with-db (db *dbname*)
    (let1 object (geto "0")
      (set! (ref object 'a) num)))
  (sys-exit 0))

(test "write in other transaction" 1
      (lambda ()
        (let1 object (geto "0")
          (let1 pid (sys-fork)
            (if (= pid 0)
                (other-transaction 1)
                (begin
                  (sys-waitpid pid)
                  (with-db (db *dbname*) (ref object 'a))))))))

(test "overwrite object" 5
      (lambda ()
        (let1 object (geto "0")
          (let1 pid (sys-fork)
            (if (= pid 0)
                (other-transaction 2)
                (begin
                  (sys-waitpid pid)
                  (with-db (db *dbname*) (set! (ref object 'a) 5))
                  (with-db (db *dbname*) (ref object 'a))))))))

; (test-section "transaction / read/write auto-sync")
; (define-class <transaction-test-4> (<kahua-persistent-base>)
;   ((a :init-value 0 :init-keyword :a :allocation :persistent
;       :out-of-transaction :read/write))
;   :read-syncer  :auto
;   :write-syncer :auto)

; (define-method key-of ((self <transaction-test-4>))
;   "key")

; (define object #f)

; (test* "make" #t
;        (with-db (db *dbname*)
;          (set! object (make <transaction-test-4> :a 0))
;          #t))

; (test "write out of transaction" 1
;       (lambda () (set! (ref object 'a) 1) 1))

; ;; �ȥ�󥶥�����󳫻ϻ���on-memory cache��db�˽񤭹��ޤ�
; ;; �뤳�Ȥ��ǧ���롣
; (test* "read in other transaction (auto synched: 1)" 1
;        (with-db (db *dbname*)
;          (ref (find-kahua-instance <transaction-test-4> "key") 'a)))

; ;; ���ȥ�󥶥������ǽ񤭹��ޤ줿�ǡ������̥ȥ�󥶥������
; ;; �ˤ��ɤ߽Ф��뤳�Ȥ��ǧ���롣
; (test* "read in other transaction (auto synched: 2)" 1
;        (with-db (db *dbname*) (ref object 'a)))

;;----------------------------------------------------------
;; unbound�ʥ���åȤΥƥ���
(test-section "unbound slot")

(define-class <unbound-slot-class> (<kahua-persistent-base>)
  ((normal :allocation :persistent :init-value 'val)
   (unbound :allocation :persistent)))

(define-method key-of ((self <unbound-slot-class>))
  (x->string (ref self 'normal)))

(test* "make unbound slot instance" '(val #f)
       (with-clean-db (db *dbname*)
         (let1 obj (make <unbound-slot-class>)
           (list (ref obj 'normal)
                 (slot-bound? obj 'unbound)
                 ))))


(test* "check unbound slot" '(val #f)
       (with-clean-db (db *dbname*)
         (let1 obj (find-kahua-instance <unbound-slot-class> "val")
           (list (ref obj 'normal)
                 (slot-bound? obj 'unbound)
                 ))))

;;----------------------------------------------------------
;; ������᥽�å�initialize��persistent-initialize method�Υ����å�
(test-section "initialize and persistent-initialize method")

(define-class <init-A> (<kahua-persistent-base>)
  ((base1 :allocation :persistent :init-value 0)
   (base2 :allocation :persistent :init-value 0)
   (key :init-value "a" :accessor key-of)))

(define-method persistent-initialize ((obj <init-A>) initargs)
  (update! (ref obj 'base1) (cut + <> 1)))

(define-method initialize ((obj <init-A>) initargs)
  (next-method)
  (update! (ref obj 'base2) (cut + <> 1)))


(test* "make first instance" '(1 1)
       (with-clean-db (db *dbname*)
         (let1 obj (make <init-A>)
           (list (ref obj 'base1)
                 (ref obj 'base2)))))

(test* "find instance" '(1 2)
       (with-clean-db (db *dbname*)
         (let1 obj (find-kahua-instance <init-A> "a")
           (list (ref obj 'base1)
                 (ref obj 'base2)))))

;;----------------------------------------------------------
;; ��³���饹������Υ����å�
(test-section "persistent class redefine")

(define-class <redefine-A> (<kahua-persistent-base>)
  ((base :allocation :persistent :init-value 0)
   (key :init-value "a" :accessor key-of)))

(define-class <redefine-B> (<kahua-persistent-base>)
  ((base :allocation :persistent :init-value 1)
   (key :init-value "b" :accessor key-of)))

(define *id* #f)
(define *id2* #f)

(test* "make first instance(1)" 0
       (with-db (db *dbname*)
         (let1 obj (make <redefine-A>)
           (set! *id* (ref obj 'id))
           (ref obj 'base))))

(redefine-class! <redefine-A> <redefine-B>)

(test* "redefine instance(1)" '(#f 0)
       (with-db (db *dbname*)
                (let1 obj (find-kahua-instance <redefine-A> "a")
                  (set! *id2* (ref obj 'id))
                  (list (eq? *id* (ref obj 'id))
                        (ref obj 'base)))))

(test* "find redefined instance(1)" '(#t 0)
       (with-clean-db (db *dbname*)
                (let1 obj (find-kahua-instance <redefine-B> "a")
           (list (eq? *id2* (ref obj 'id))
                 (ref obj 'base)))))

(define-class <redefine-C> (<kahua-persistent-base>)
  ((base :allocation :persistent :init-value 0)
   (key :init-value "c" :accessor key-of)))

(test* "make first instance(2)" 0
       (with-db (db *dbname*)
         (let1 obj (make <redefine-C>)
           (set! *id* (ref obj 'id))
           (ref obj 'base))))

(define-class <redefine-C> (<kahua-persistent-base>)
  ((base :allocation :persistent :init-value 1)
   (base2 :allocation :persistent :init-value 10)
   (key :init-value "c" :accessor key-of)))

(test* "find redefined instance(2)" '(#t 0 10)
       (with-clean-db (db *dbname*)
                (let1 obj (find-kahua-instance <redefine-C> "c")
           (list (eq? *id* (ref obj 'id))
                 (ref obj 'base)
                 (ref obj 'base2)))))

(test-end)
