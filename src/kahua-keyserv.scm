;; session-key server.
;;
;;  Copyright (c) 2004 Scheme Arts, L.L.C., All rights reserved.
;;  Copyright (c) 2004 Time Intermedia Corporation, All rights reserved.
;;  See COPYING for terms and conditions of using this software
;;
;; $Id: kahua-keyserv.scm,v 1.3 2005/01/18 05:16:37 nobsun Exp $

;; This will eventually becomes generic object broker.  
;; For now, this only handles state session object.
;; This script should be invoked by kahua-spvr.
;; When started, objserv reports the worker id to stdout.

;; Protocol:
;;   For the time being, a distributed object is simply a list of:
;;     (<key> (<name> . <value>) (<name2> . <value2>) ...)
;;   where <key> is a unique string, <name> is an attribute name (symbol)
;;   and <value> is the attribute value.
;;   For object conciseness, the attribute is not recorded if its value is #f.
;;
;;   A client can give the following list as request.
;;     (<key> (<name> . <value>) ...)
;;   The following action(s) is(are) taken:
;;     * If the object with <key> doesn't exist, one is created.
;;     * If (<name> . <value>) is given, the named attribute of
;;       the object is set.
;;   After those actions, the complete object description is
;;   returned to the client.
;;
;;   As a special case, a client can give a request
;;     (#f)
;;   which lets the server allocate a fresh key.
;;
;;   Administrative requests:
;;     (flush <timeout>)
;;        Forces the server to discard keys older than <timeout> seconds.
;;        Replies (<number-of-current-keys>)
;;     (stat)
;;        Replies (<number-of-current-keys>)
;;     (keys)
;;        Replies list of all existing keys
;;
;; This protocol favors simplicity over performance.  It won't scale,
;; so we'll watch out how it behaves.

(use gauche.net)
(use gauche.parseopt)
(use gauche.logger)
(use gauche.selector)
(use util.list)
(use srfi-27)
(use kahua)

(define-constant *default-timeout* (* 3 3600))

(define (main args)
  (let-args (cdr args) ((conf-file "c=s")
                        (user "user=s"))
    (kahua-init conf-file :user user)
    (log-open (kahua-logpath "keyserv") :prefix "~Y ~T ~P[~$]: ")
    (random-source-randomize! default-random-source)
    (let* ((wid (make-worker-id "%keyserv"))
           (sockaddr (worker-id->sockaddr wid (kahua-sockbase)))
           (cleanup (lambda ()
                      (when (is-a? sockaddr <sockaddr-un>)
                        (sys-unlink (sockaddr-name sockaddr))))))
      (set-signal-handler! SIGINT  (lambda _ (cleanup) (exit 0)))
      (set-signal-handler! SIGHUP  (lambda _ (cleanup) (exit 0)))
      (set-signal-handler! SIGTERM (lambda _ (cleanup) (exit 0)))
      (set-signal-handler! SIGPIPE #f)
      (with-error-handler
          (lambda (e)
            (log-format "~a" (kahua-error-string e #t))
            (log-format "Exitting by error")
            (cleanup)
            70)
        (lambda ()
          (run-server wid sockaddr))))
    0))

(define (usage)
  (print "kahua-keyserv [-c <conf-file>][-user <user>]")
  (exit 0))

;; server main loop - similar to kahua-server.  call for refactoring.
(define (run-server worker-id sockaddr)
  (let ((sock (make-server-socket sockaddr :reuse-addr? #t))
        (selector (make <selector>)))
    (define (accept-handler fd flag)
      (handle-request (socket-accept sock)))

    ;; hack
    (when (is-a? sockaddr <sockaddr-un>)
      (sys-chmod (sockaddr-name sockaddr) #o770))
    (format #t "~a\n" worker-id) ;; tell spvr about myself
    (selector-add! selector (socket-fd sock) accept-handler '(r))
    (do () (#f)
      (when (zero? (selector-select selector 60.0e6))
        (sweep-objects *default-timeout*)))
    ))

(define (handle-request client)
  (let* ((input  (socket-input-port client :buffered? #f))
         (output (socket-output-port client))
         (request #f))
    (with-error-handler
        (lambda (e)
          (log-format "~a" (kahua-error-string e #t))
          (socket-shutdown client 2))
      (lambda ()
        (set! request (read input))
        (with-error-handler
            (lambda (e)
              (log-format "~a" (kahua-error-string e #t))
              (display "#f\n" output)
              (flush output)
              (socket-shutdown client 2)
              (socket-close client))
          (lambda ()
            (let1 result 
                (if (and (pair? request)
                         (>= (length request) 1))
                  (case (car request)
                    ((flush)
                     (sweep-objects (x->integer (and (pair? (cdr request))
                                                     (cadr request))))
                     (list (num-objects)))
                    ((stat) (list (num-objects)))
                    ((keys) (all-keys))
                    ((ref) (ref-object (cadr request)))
                    (else
                     (handle-object-command request)))
                  #f)
              (write result output) (newline output)
              (flush output)
              (socket-shutdown client 2)
	      (socket-close client)))
          )))))

(define (handle-object-command request)
  (let loop ((obj (get-object (car request)))
             (attrs (cdr request)))
    (if (null? attrs)
      obj
      (begin (set-cdr! obj (assq-set! (cdr obj) (caar attrs) (cdar attrs)))
             (loop obj (cdr attrs))))))

;; Object pool -------------------------------------------

(define *object-pool* (make-hash-table 'string=?))

(define (get-object key)
  (if (string? key)
    (cond ((hash-table-get *object-pool* key #f)
           => (lambda (k)
                (set! (cdr k) (assq-set! (cdr k) '%ctime (sys-time)))
                k))
          (else
           (let1 newobj `(,key (%ctime . ,(sys-time)))
             (hash-table-put! *object-pool* key newobj)
             newobj)))
    (let loop ()
      (let1 candidate (number->string (random-integer (expt 2 64)) 36)
        (if (hash-table-get *object-pool* candidate #f)
          (loop)
          (get-object candidate))))
    ))

(define (ref-object key)
  (and (string? key)
       (hash-table-get *object-pool* key #f)))

(define (sweep-objects timeout)
  (define now (sys-time))
  (define (check k v)
    (let1 ctime (assq-ref (cdr v) '%ctime)
      (when (and ctime (< ctime (- now timeout)))
        (hash-table-delete! *object-pool* k))))
  (hash-table-for-each *object-pool* check))

;; NB: 0.7.4.1 hash-table-num-entries is broken
(define (num-objects)
  (hash-table-fold *object-pool*
                   (lambda (k v n) (+ n 1))
                   0))

(define (all-keys)
  (hash-table-keys *object-pool*))

;; Local variables:
;; mode: scheme
;; end:
