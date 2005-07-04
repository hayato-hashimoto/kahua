;; -*- coding: euc-jp ; mode: scheme -*-
;; $Id: user.scm,v 1.2 2005/07/04 05:09:21 nobsun Exp $

;; test kahua.user

(use gauche.test)
(use srfi-2)
(use rfc.md5)
(use kahua.persistence)
(use file.util)

(test-start "user")
(use srfi-1)
(use kahua.user)
(test-module 'kahua.user)

(define *dbname* (build-path (sys-getcwd) "_tmp"))
(sys-system #`"rm -rf ,*dbname*")

(test* "kahua-check-user (in the empty db)" #f
       (with-db (db *dbname*)
         (kahua-check-user "shiro" "shiro")))

(test* "kahua-add-user" #t
       (with-db (db *dbname*)
         (every (cut is-a? <> <kahua-user>)
                (list (kahua-add-user "shiro"  "manapua")
                      (kahua-add-user "nobsun" "punahou")
                      (kahua-add-user "admin"  "kamehameha")))))

(test* "kahua-find-user" "shiro"
       (with-db (db *dbname*)
         (and-let* ((u (kahua-find-user "shiro")))
           (ref u 'login-name))))

(test* "kahua-find-user" #f
       (with-db (db *dbname*)
         (and-let* ((u (kahua-find-user "shirok")))
           (ref u 'login-name))))

(test* "kahua-add-user (dup)" #f
       (with-db (db *dbname*)
         (kahua-add-user "nobsun" "makapuu")))

(test* "kahua-add-user (non-dup)" #t
       (with-db (db *dbname*)
         (not (not (kahua-add-user "guest" "molokai")))))
         
(test* "kahua-check-user" "shiro"
       (with-db (db *dbname*)
         (and-let* ((u (kahua-check-user "shiro" "manapua")))
           (ref u 'login-name))))

(test* "kahua-check-user" #f
       (with-db (db *dbname*)
         (and-let* ((u (kahua-check-user "shiro" "makapuu")))
           (ref u 'login-name))))

(test* "kahua-check-user" #f
       (with-db (db *dbname*)
         (and-let* ((u (kahua-check-user "shirok" "makapuu")))
           (ref u 'login-name))))

(test-end)
