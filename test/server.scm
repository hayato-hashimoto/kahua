;; -*- coding: euc-jp ; mode: scheme -*-
;; Test kahua.server module
;; $Id: server.scm,v 1.4 2005/12/18 12:16:00 cut-sea Exp $

;; The kahua.server in the "real situation" would be tested by
;; worker and spvr tests.  This module tests the surface API.

;; This test also accesses kahua.session.

(use srfi-1)
(use gauche.test)
(use gauche.parameter)
(use kahua.gsid)
(use kahua.session)
(use kahua.test.xml)
(use util.list)

(test-start "kahua.server")
(use kahua.server)
(test-module 'kahua.server)

;;---------------------------------------------------------------
(test-section "initialization")

(test* "kahua-init-server" #t
       (string? (kahua-init-server "dummy")))

(test* "kahua-bridge-name" "kahua.cgi"
       (kahua-bridge-name))

;;---------------------------------------------------------------
(test-section "utilities")

(test* "kahua-merge-headers" '(("a" "b"))
       (kahua-merge-headers '(("a" "b"))))

(test* "kahua-merge-headers" '(("e" "z") ("a" "x") ("c" "d"))
       (kahua-merge-headers '(("a" "b") ("c" "d"))
                            '(("a" "x") ("e" "z"))))

(test* "kahua-merge-headers" '(("c" "p") ("f" "q") ("e" "z") ("a" "x"))
       (kahua-merge-headers '(("a" "b") ("c" "d"))
                            '(("a" "x") ("e" "z"))
                            '(("f" "q") ("c" "p"))))

;;---------------------------------------------------------------
(test-section "dispatcher")

(define (a-cont . _) '(p "a-cont"))

(define (a-renderer body context)
  (values `(html (head (title "test")) (body ,body)) context))

(test* "kahua-default-handler"
       '(html (head (title "test"))
              (body (p "a-cont")))
       (let ((cgsid (session-cont-register a-cont)))
         (kahua-default-handler `(("x-kahua-cgsid" ,cgsid))
                                '()
                                (lambda (h b) b)
                                identity
                                :render-proc a-renderer)))

(test* "kahua-default-handler (stale proc)"
       '(html (head (title "test"))
              (body (p "unknown session key")))
       (kahua-default-handler `(("x-kahua-cgsid" "bongobongo"))
                              '()
                              (lambda (h b) b)
                              identity
                              :render-proc a-renderer
                              :stale-proc (lambda _
                                            '(p "unknown session key"))))

(test* "kahua-default-handler (session state)"
       '(html (head (title "test"))
              (body "kahua!"))
       (let* ((b-cont (lambda ()
                        (let1 state (kahua-context-ref "session-state")
                          (set! (ref state 'a) "kahua!"))))
              (c-cont (lambda ()
                        (let1 state (kahua-context-ref "session-state")
                          (ref state 'a))))
              (cgsid1 (session-cont-register values))
              (cgsid2 (session-cont-register b-cont))
              (cgsid3 (session-cont-register c-cont))
              (sgsid  #f)
              )
         (kahua-default-handler `(("x-kahua-cgsid" ,cgsid1))
                                '()
                                (lambda (h b)
                                  (receive (state cont)
                                      (get-gsid-from-header h)
                                    (set! sgsid state)
                                    #f))
                                identity
                                :render-proc a-renderer)
         (kahua-default-handler `(("x-kahua-sgsid" ,sgsid)
                                  ("x-kahua-cgsid" ,cgsid2))
                                '()
                                (lambda (h b) b)
                                identity
                                :render-proc a-renderer)
         (kahua-default-handler `(("x-kahua-sgsid" ,sgsid)
                                  ("x-kahua-cgsid" ,cgsid3))
                                '()
                                (lambda (h b) b)
                                identity
                                :render-proc a-renderer)
         ))


;;---------------------------------------------------------------
(test-section "entries")

(define-syntax call-entry
  (syntax-rules ()
    ((call-entry entry context)
     (parameterize ((kahua-current-context context))
       ((session-cont-get (symbol->string entry)))))))

(test* "define-entry"
       '(("usr" "var" "www" "xxX" #f "Zzzz")
         (#f #f #f "xxx" "yyy" "zzz")
         (#f #f #f #f #f #f))
       (let ()
         (eval
          '(define-entry (foo a b c :keyword x y z)
             (list a b c x y z))
          (current-module))
         (list
          (call-entry 'foo
                      '(("x-kahua-path-info" ("usr" "var" "www" "zzz"))
                        ("z" "Zzzz")
                        ("x" "xxX")))
          (call-entry 'foo
                      '(("x-kahua-path-info" ())
                        ("x" "xxx")
                        ("y" "yyy")
                        ("z" "zzz")))
          (call-entry 'foo '())
          )))

(test* "define-entry (multi-value bind parameter)"
       '(("usr" "var" "www" ("xxX" "Xxx" "xXx") () ("Zzzz"))
         (#f #f #f ("xxx") ("yyy") ("zzz"))
         (#f #f #f () () ()))
       (let ()
         (eval
          '(define-entry (bar a b c :multi-value-keyword x y z)
             (list a b c x y z))
          (current-module))
         (list
          (call-entry 'bar
                      '(("x-kahua-path-info" ("usr" "var" "www" "zzz"))
                        ("z" "Zzzz")
                        ("x" "xxX" "Xxx" "xXx")))
          (call-entry 'bar
                      '(("x-kahua-path-info" ())
                        ("x" "xxx")
                        ("y" "yyy")
                        ("z" "zzz")))
          (call-entry 'bar '())
          )))

;; make sure 'foo' is registered globally.
(test* "define-entry & session"
       '("usr" "var" "www" "xxX" #f "Zzzz")
       (call-entry 'foo
                   '(("x-kahua-path-info" ("usr" "var" "www" "zzz"))
                     ("z" "Zzzz")
                     ("x" "xxX"))))


;; test :rest argument variations
(let ((env '(("x-kahua-path-info" ("usr" "var" "www" "zzz"))
             ("x" "xxx")
             ("y" "yyy"))))
  (test* "define-entry (:rest arg - 1)"
         '("usr" "var" ("www" "zzz"))
         (let ()
           (eval '(define-entry (foo a b :rest c) (list a b c))
                 (current-module))
           (call-entry 'foo env)))
  (test* "define-entry (:rest arg - 2)"
         '("usr" "var" "www" "zzz")
         (let ()
           (eval '(define-entry (foo :rest a) a)
                 (current-module))
           (call-entry 'foo env)))
  (test* "define-entry (:rest arg - 3)"
         '(("usr" "var" "www" "zzz") "xxx" "yyy")
         (let ()
           (eval '(define-entry (foo :rest a :keyword y x) (list a x y))
                 (current-module))
           (call-entry 'foo env)))
  (test* "define-entry (:rest arg - 3)"
         '(("usr" "var" "www" "zzz") "xxx" "yyy")
         (let ()
           (eval '(define-entry (foo :rest a :keyword y x) (list a x y))
                 (current-module))
           (call-entry 'foo env)))
  (test* "define-entry (:rest arg - 4)"
         '(("usr" "var" "www" "zzz") "xxx" "yyy")
         (let ()
           (eval '(define-entry (foo :keyword y x :rest a) (list a x y))
                 (current-module))
           (call-entry 'foo env)))
  (test* "define-entry (:rest arg - 5)"
         '("usr" "var" ("www" "zzz") "xxx" "yyy")
         (let ()
           (eval '(define-entry (foo a b :keyword y x :rest c) (list a b c x y))
                 (current-module))
           (call-entry 'foo env)))
  (test* "define-entry (:rest arg - 6)"
         '("usr" "var" ("www" "zzz"))
         (let ()
           (eval '(define-entry (foo a b :keyword :rest c) (list a b c))
                 (current-module))
           (call-entry 'foo env)))
  (test* "define-entry (:rest arg - 7)"
         '()
         (let ()
           (eval '(define-entry (foo :rest a) a)
                 (current-module))
           (call-entry 'foo '(("x-kahua-path-info" ())))))
  (test* "define-entry (bad :rest arg - 1)"
         *test-error*
         (eval '(define-entry (foo :rest) #f)
               (interaction-environment)))
  (test* "define-entry (bad :rest arg - 2)"
         *test-error*
         (eval '(define-entry (foo :rest a b) #f)
               (interaction-environment)))
  (test* "define-entry (bad :rest arg - 3)"
         *test-error*
         (eval '(define-entry (foo a b :rest) #f)
               (interaction-environment)))
  (test* "define-entry (bad :rest arg - 4)"
         *test-error*
         (eval '(define-entry (foo a b :rest c d) #f)
               (interaction-environment)))
  (test* "define-entry (bad :rest arg - 5)"
         *test-error*
         (eval '(define-entry (foo a b :rest :keyword x y) #f)
               (interaction-environment)))
  (test* "define-entry (bad :rest arg - 6)"
         *test-error*
         (eval '(define-entry (foo a b :rest c d :keyword x y) #f)
               (interaction-environment)))
  (test* "define-entry (bad :rest arg - 7)"
         *test-error*
         (eval '(define-entry (foo a b :keyword x y :rest) #f)
               (interaction-environment)))
  (test* "define-entry (bad :rest arg - 8)"
         *test-error*
         (eval '(define-entry (foo a b :keyword x y :rest z q) #f)
               (interaction-environment)))
  )

;;---------------------------------------------------------------
(test-section "extra-header element")

(test* "extra-header" '((("foo" "bar")) ())
       (kahua-default-handler
        '()
        '()
        (lambda (h b)
          (list (alist-delete "x-kahua-sgsid" h) b))
        (lambda ()
          '((extra-header (@ (name "foo") (value "bar")))))))

(test* "extra-header" '(("foo" "bar") ("voo" "doo"))
       (kahua-default-handler
        '()
        '()
        (lambda (h b)
          (alist-delete "x-kahua-sgsid" h))
        (lambda ()
          '((html
             (head
              (extra-header (@ (name "foo") (value "bar")))
              (title "hoge"))
             (body
              (p
               (extra-header (@ (name "voo") (value "doo"))))))))))

(test-end)

;; Local variables:
;; mode: scheme
;; end:
