;; -*- coding: euc-jp ; mode: scheme -*-
;; PostgreSQL�Хå�����ɤΥƥ���
;; $Id: persistence-dbi-pg.scm,v 1.3 2006/02/04 07:39:40 shibata Exp $

;; Notes:
;;  * �ƥ��ȥ��������Τ�persistence.scm�Τ�Τ�Ȥ���
;;  * postmaster�����äƤ��ꡢ�Ķ��ѿ�$USER�Υ�������Ȥǥѥ����̵����
;;    ������Ǥ����ǥե���ȥǡ����١������Ȥ��뤳�Ȥ�����Ȥ��롣

(use gauche.collection)
(use dbi)
(define *user* (sys-getenv "USER"))
(define *dbname* #`"pg:,|*user*|::")

;; ����Υƥ��ȤǺ��줿�ơ��֥뤬�ĤäƤ���Ф���򥯥ꥢ���Ƥ���
(let* ((d (dbi-make-driver "pg"))
       (c (dbi-make-connection d *user* "" ""))
       ;; (q (dbi-make-query c))
       (r (dbi-do c "select table_name from kahua_db_classes"))
       (tables (and r (map (cut dbi-get-value <> 0) r))))
  (dolist (table tables)
    (dbi-do c #`"drop table ,|table|"))
  (dbi-do c "drop table kahua_db_idcount")
  (dbi-do c "drop table kahua_db_classes")
  (dbi-close c)
  )

(load "./persistence.scm")
