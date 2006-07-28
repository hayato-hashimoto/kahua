;; -*- coding: euc-jp ; mode: scheme -*-
;; MySQL�Хå�����ɤΥƥ���
;; $Id: persistence-dbi-mysql.scm,v 1.4 2006/07/28 13:09:49 bizenn Exp $

;; Notes:
;;  * �ƥ��ȥ��������Τ�persistence.scm�Τ�Τ�Ȥ���
;;  * mysqld�����äƤ��ꡢ�Ķ��ѿ�$USER�Υ�������Ȥǥѥ����̵����
;;    ������Ǥ���'test'�ǡ����١������Ȥ��뤳�Ȥ�����Ȥ��롣

(use gauche.collection)
(use dbi)
(define *user* (sys-getenv "USER"))
(define *dbname* #`"mysql:,|*user*|::db=test")

;; ����Υƥ��ȤǺ��줿�ơ��֥뤬�ĤäƤ���Ф���򥯥ꥢ���Ƥ���
(load "./persistence-dbi.scm")
(cleanup-db "mysql" *user* "" "db=test")

(load "./persistence.scm")
