;; Manage application developer's account.
;;
;;  Copyright (c) 2003 Scheme Arts, L.L.C., All rights reserved.
;;  Copyright (c) 2003 Time Intermedia Corporation, All rights reserved.
;;  See COPYING for terms and conditions of using this software
;;
;; $Id: developer.scm,v 1.1 2004/01/29 07:19:18 tahara Exp $


(define-module kahua.developer
  (use srfi-1)
  (use rfc.sha1)
  (use rfc.base64)
  (use file.util)
  (use gauche.parameter)
  (use gauche.fcntl)
  (use gauche.parameter)
  (use kahua.config)
  (export kahua-add-developer kahua-delete-developer
          kahua-check-developer kahua-change-developer-password
          kahua-list-developer))

(select-module kahua.developer)


;; inner data and functions
(define developers (make-parameter '()))

(define (load-developers)
  (developers (load-conf)))

(define (developer-name x) (car x))

(define (developer-password x) (cdr x))

(define (developer-password-set! x pw) (set-cdr! x pw))

(define (developer-exists? name)
  (any (lambda (x) (equal? name (developer-name x)))
       (developers)))

(define (find-developer name)
  (find (lambda (x) (equal? name (developer-name x)))
        (developers)))


;; read/write configuration file
(define (load-conf)
  (let ((conf-file (kahua-userconf-file)))
    (if (file-exists? conf-file)
        (let ((temp (call-with-input-file (kahua-userconf-file) read)))
          (cond ((eof-object? temp) '())
                ((list? temp) temp)
                (else (error "unknown data" temp))))
        (error "userconf file does not exists" conf-file))))

(define (save-conf)
  (let* ((conf-file (kahua-userconf-file))
         (lock-file (string-append conf-file ".lock"))
         (lock-port #f))

    (define (lock)
      (let ((record (make <sys-flock> :type F_WRLCK)))
        (define (try-lock retry)
          (cond ((zero? retry) #f)
                ((sys-fcntl lock-port F_SETLK record) lock-port)
                (else (try-lock (- record 1)))))
        (unless (file-exists? lock-file)
          (with-output-to-file lock-file (lambda () (newline))))
        (set! lock-port (open-output-file lock-file :if-exists? :append))
        (try-lock 10)))

    (define (unlock)
      (let ((record (make <sys-flock> :type F_UNLCK)))
        (sys-fcntl lock-port F_SETLK record)))
    (if (lock)
        (begin
          (let ((temp (developers)))
          (with-output-to-file conf-file (lambda () (write temp)))
          (unlock)))
        (error "can't lock userconf file" conf-file))))


;; misc functions
(define (valid-name? name)
  (and (string? name)
       (>= (string-length name) 3)))

(define (valid-password? password)
  (and (string? password)
       (>= (string-length password) 4)))

(define (gen-password password)
  (base64-encode-string (sha1-digest-string password)))


;; user interface
;; TODO: load-developers should be use implicitly.
(define (kahua-add-developer name password)
  (load-developers)
  (if (developer-exists? name)
      (error "the name already exists." name)
      (begin
        (cond ((not (valid-name? name))
               (error "invalid name" name))
              ((not (valid-password? password))
               (error "invalid password" password))
              (else
               (let ((pw (gen-password password)))
                 (developers
                  (append (developers) `((,name . ,pw))))
                 (save-conf)))))))

(define (kahua-delete-developer name)
  (load-developers)
  (if (developer-exists? name)
      (begin
        (developers
         (remove (lambda (x) (equal? name (developer-name x)))
                 (developers)))
         (save-conf))
      (error "the developer does not exists" name)))

(define (kahua-check-developer name password)
  (load-developers)
  (let ((developer (find-developer name))
        (pw (gen-password password)))
    (if developer
        (equal? pw (developer-password developer))
        #f)))

(define (kahua-change-developer-password name old-password new-password)
  (load-developers)
  (if (kahua-check-developer name old-password)
      (let ((developer (find-developer name)))
        (developer-password-set! developer new-password) #t)
      (error "name and/or password may be incorrect" name)))

(define (kahua-list-developer)
  (load-developers)
  (map (lambda (x) (car x)) (developers)))


(provide "kahua/developer")