;;; -*- mode: scheme; coding: utf-8 -*-
;; Persistent on MySQL storage
;;
;;  Copyright (c) 2003-2006 Scheme Arts, L.L.C., All rights reserved.
;;  Copyright (c) 2003-2006 Time Intermedia Corporation, All rights reserved.
;;  See COPYING for terms and conditions of using this software
;;
;; $Id: mysql.scm,v 1.3 2006/09/07 02:54:55 bizenn Exp $

(define-module kahua.persistence.mysql
  (use srfi-1)
  (use kahua.persistence.dbi))

(select-module kahua.persistence.mysql)

(define *DEBUG* #f)
(define (debug-write . args)
  (when *DEBUG*
    (apply format (current-error-port) args)))

;; Debug Facility
;(define dbi-do% dbi-do)
;(define (dbi-do conn sql opts . params)
;  (format (current-error-port) "SQL: ~a\n" sql)
;  (apply dbi-do% conn sql opts params))

(define-class <kahua-db-mysql> (<kahua-db-dbi>)
  ;; Now support :MyISAM and :InnoDB
  ((table-type :init-keyword :table-type :init-value :MyISAM :getter table-type-of)))

(define-method set-default-character-encoding! ((db <kahua-db-mysql>))
  (safe-execute
   (lambda ()
     (dbi-do (connection-of db)
	     (format "set character set ~a" (case (gauche-character-encoding)
					      ((utf-8)  'utf8)
					      ((euc-jp) 'ujis)
					      ((sjis)   'sjis)
					      (else     'binary)))
	     '(:pass-through #t)))))

(define-constant *db-charset-collation*
  (case (gauche-character-encoding)
    ((utf-8)  '(utf8   utf8_general_ci))
    ((euc-jp) '(ujis   ujis_japanese_ci))
    ((sjis)   '(sjis   sjis_japanese_ci))
    (else     '(binary binary))))

;; ID counter in database.
(define-method create-kahua-db-idcount ((db <kahua-db-mysql>))
  (define *create-kahua-db-idcount*
    (format "create table ~a (value integer not null) type=~a" *kahua-db-idcount* (table-type-of db)))
  (define *initialize-kahua-db-idcount*
    (format "insert into ~a values (-1)" *kahua-db-idcount*))
  (let1 conn (connection-of db)
    (dbi-do conn *create-kahua-db-idcount* '(:pass-through #t))
    (dbi-do conn *initialize-kahua-db-idcount* '(:pass-through #t))))

(define-method initialize-kahua-db-idcount ((db <kahua-db-mysql>) n)
  (dbi-do (connection-of db)
	  (format "update ~a set value = ?" *kahua-db-idcount*)
	  '() n))


;; Class table counter
(define-method create-kahua-db-classcount ((db <kahua-db-mysql>))
  (define *create-kahua-db-classcount*
    (format "create table ~a (value integer not null) type=~a" *kahua-db-classcount* (table-type-of db)))
  (define *initialize-kahua-db-classcount*
    (format "insert into ~a values (-1)" *kahua-db-classcount*))
  (let1 conn (connection-of db)
    (dbi-do conn *create-kahua-db-classcount* '(:pass-through #t))
    (dbi-do conn *initialize-kahua-db-classcount* '(:pass-through #t))))
(define-method initialize-kahua-db-classcount ((db <kahua-db-mysql>) n)
  (define *initialize-kahua-db-classcount*
    (format "update ~a set value = ?" *kahua-db-classcount*))
  (dbi-do (connection-of db) *initialize-kahua-db-classcount* '() n))

;; Class - Table mapping table.
(define-method create-kahua-db-classes ((db <kahua-db-mysql>))
  (define create-kahua-db-classes-sql
    (format "create table ~a (
               class_name varchar(255) not null,
               table_name varchar(255) not null,
               constraint pk_~a primary key (class_name),
               constraint uq_~a unique (table_name)
             ) type=~a" *kahua-db-classes* *kahua-db-classes* *kahua-db-classes* (table-type-of db)))
  (dbi-do (connection-of db) create-kahua-db-classes-sql '(:pass-through #t)))

(define-method lock-tables ((db <kahua-db-mysql>) . tables)
  (define (construct-table-lock-sql specs)
    (and (not (null? specs))
	 (call-with-output-string
	   (lambda (out)
	     (format out "lock tables ~a ~a" (caar specs) (cdar specs))
	     (for-each (lambda (spec)
			 (format out ",~a ~a" (car spec) (cdr spec)))
		       (cdr specs))))))
  (and-let* ((query (construct-table-lock-sql (serialize-table-locks tables))))
    (dbi-do (connection-of db) query '(:pass-through #t))))

(define-method unlock-tables ((db <kahua-db-mysql>) . tables)
  (unless (null? tables)
    (dbi-do (connection-of db) "unlock tables" '(:pass-through #t))))

(define-method kahua-db-unique-id ((db <kahua-db-mysql>))
  (define *select-kahua-db-idcount* "select last_insert_id()")
  (define *update-kahua-db-idcount*
    (format "update ~a set value = last_insert_id(value+1)" *kahua-db-idcount*))
  (with-transaction db
    (lambda (conn)
      (with-locking-tables db
	(lambda ()
	  (dbi-do conn *update-kahua-db-idcount* '(:pass-through #t))
	  (x->integer (car (map (cut dbi-get-value <> 0)
				(dbi-do conn *select-kahua-db-idcount* '(:pass-through #t))))))
	*kahua-db-idcount*))))

(define-method class-table-next-suffix ((db <kahua-db-mysql>))
  (define *select-kahua-db-classcount* "select last_insert_id()")
  (define *update-kahua-db-classcount*
    (format "update ~a set value = last_insert_id(value+1)" *kahua-db-classcount*))
  (guard (e ((else (format (current-error-port)
			   "Error: class-table-next-suffix: ~a" (ref e 'message)))))
    (with-transaction db
      (lambda (conn)
	(with-locking-tables db
	  (lambda ()
	    (dbi-do conn *update-kahua-db-classcount* '(:pass-through #t))
	    (x->integer (car (map (cut dbi-get-value <> 0)
				  (dbi-do conn *select-kahua-db-classcount* '(:pass-through #t))))))
	  *kahua-db-classcount*)))))

(define-method create-kahua-class-table ((db <kahua-db-mysql>)
					 (class <kahua-persistent-meta>))
  (define (create-class-table-sql tabname)
    (format "create table ~a (
               keyval varchar(255) binary not null,
               dataval longtext binary not null,
             constraint pk_~a primary key (keyval)
             ) type=~a" tabname tabname (table-type-of db)))
  (let ((cname (class-name class))
	(newtab (format *kahua-class-table-format* (class-table-next-suffix db))))
    (insert-kahua-db-classes db cname newtab)
    (dbi-do (connection-of db) (create-class-table-sql newtab) '(:pass-through #t))
    (register-to-table-map db cname newtab)
    newtab))

(define-method table-should-be-locked? ((db <kahua-db-mysql>)
					(obj <kahua-persistent-base>))
  #t)					; Always should lock the table.

(define-method write-kahua-instance ((db <kahua-db-mysql>)
                                     (obj <kahua-persistent-base>)
				     (tab <string>))
  (define *insert-class-table-format* "insert into ~a values (?, ?)")
  (define *update-class-table-format* "update ~a set dataval = ? where keyval = ?")
  (let* ((conn (connection-of db))
	 (data (call-with-output-string (pa$ kahua-write obj)))
	 (key  (key-of obj)))
    (debug-write "~a: ~a: ~s\n" (if (ref obj '%floating-instance) 'INSERT 'UPDATE) key obj)
					;    (with-locking-tables db
					;      (lambda ()
    (if (ref obj '%floating-instance)
	(dbi-do conn (format *insert-class-table-format* tab) '() key data)
	(dbi-do conn (format *update-class-table-format* tab) '() data key))
					;	)
					;      tab)
    (set! (ref obj '%floating-instance) #f)
    ))

(provide "kahua/persistence/mysql")
