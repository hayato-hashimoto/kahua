;;
;;  Copyright (c) 2003 Scheme Arts, L.L.C., All rights reserved.
;;  Copyright (c) 2003 Time Intermedia Corporation, All rights reserved.
;;  See COPYING for terms and conditions of using this software
;;
;; $Id: user.scm,v 1.4 2005/12/13 16:40:00 cut-sea Exp $

(define-module kahua.user
  (use kahua.persistence)
  (use rfc.md5)
  (use srfi-1)
  (use srfi-13)
  (use srfi-27)
  (use gauche.collection)
  (export <kahua-user> kahua-add-user kahua-check-user kahua-find-user
          kahua-user-password-change kahua-user-password-change-force
	  kahua-user-has-role?
	  add-user check-user find-user
	  user-password-change user-password-change-force
	  user-has-role?
	  ))
(select-module kahua.user)

(define-class <kahua-user> (<kahua-persistent-base>)
  ((login-name    :allocation :persistent
                  :init-keyword :login-name :init-value #f)
   (password-hash :allocation :persistent
                  :init-keyword :password-hash :init-value #f)
   (role-alist    :allocation :persistent
                  :init-keyword :role-alist :init-value '())
   (inactive      :allocation :persistent
                  :init-keyword :inactive :init-value #f)
   ))

(define-method key-of ((self <kahua-user>))
  (ref self 'login-name))

(define (kahua-find-user login-name)
  (find-kahua-instance <kahua-user> login-name))

;; for user defined kahua-user subclass
(define-method find-user ((cls <kahua-persistent-meta>) login-name)
  (find-kahua-instance cls login-name))

(define (kahua-add-user login-name password)
  (if (kahua-find-user login-name)
    #f
    (make <kahua-user>
      :login-name login-name
      :password-hash (crypt-passwd password))))

;; for user defined kahua-user subclass
(define-method add-user ((cls <kahua-persistent-meta>) login-name password)
  (if (find-user cls login-name)
      #f
      (make cls
	:login-name login-name
	:password-hash (crypt-passwd password))))

(define (kahua-check-user login-name password)
  (find (lambda (user)
          (and (equal? (ref user 'login-name) login-name)
               (not (ref user 'inactive))
               (match-passwd password (ref user 'password-hash))))
        (make-kahua-collection <kahua-user>)))

;; for user defined kahua-user subclass
(define-method check-user ((cls <kahua-persistent-meta>) login-name password)
  (find (lambda (user)
	  (and (equal? (ref user 'login-name) login-name)
	       (not (ref user 'inactive))
	       (match-passwd password (ref user 'password-hash))))
	(make-kahua-collection cls)))

;; user must be <kahua-user>.  caller must sync db.
(define (kahua-user-password-change user old-password new-password)
  (and (is-a? user <kahua-user>)
       (kahua-check-user (ref user 'login-name) old-password)
       (kahua-user-password-change-force user new-password)
       #t))

;; for user defined kahua-user subclass
(define-method user-password-change ((usr <kahua-user>) old-password new-password)
  (and (check-user (class-of usr) (ref usr 'login-name) old-password)
       (user-password-change-force usr new-password)
       #t))

;; user must be <kahua-user>.  caller must sync db.
(define (kahua-user-password-change-force user new-password)
  (and (is-a? user <kahua-user>)
       (set! (ref user 'password-hash) (crypt-passwd new-password))
       #t))

;; for user defined kahua-user subclass
(define-method user-password-change-force ((usr <kahua-user>) new-password)
  (and (set! (ref usr 'password-hash) (crypt-passwd new-password))
       #t))

;; user may be <kahua-user> object or #f
;; role-alist's spec isn't fixed yet.  for now, we assume it's a list of
;; symbols.
;; ROLES arg is also a list of symbols.  Later we might add move syntax.
(define (kahua-user-has-role? user roles)
  (and (is-a? user <kahua-user>)
       (list? roles)
       (find (lambda (urole) (find (cut eq? <> urole) roles))
             (ref user 'role-alist))))

;; for user defined kahua-user subclass
(define-method user-has-role? ((usr <kahua-user>) roles)
  (and (list? roles)
       (find (lambda (urole) (find (cut eq? <> urole) roles))
	     (ref usr 'role-alist))))

;; internal utility
(define (crypt-passwd passwd)
  (let* ((salt (format "~a~a"
                       (integer->char (+ (random-integer 94) 33))
                       (integer->char (+ (random-integer 94) 33))))
         (enc  (digest-hexify (md5-digest-string (string-append salt passwd))))
         )
    (string-append salt enc)))

(define (match-passwd passwd hashed)
  (let* ((salt (string-take hashed 2))
         (enc  (digest-hexify (md5-digest-string (string-append salt passwd))))
         )
    (string=? (string-drop hashed 2) enc)))

(provide "kahua/user")
