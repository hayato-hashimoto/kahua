;; MySQL�Хå�����ɤΥƥ���
;; $Id: persistence-dbi-mysql.scm,v 1.1 2004/04/07 09:55:33 nobsun Exp $

;; Notes:
;;  * �ƥ��ȥ��������Τ�persistence.scm�Τ�Τ�Ȥ���
;;  * mysqld�����äƤ��ꡢ�Ķ��ѿ�$USER�Υ�������Ȥǥѥ����̵����
;;    ������Ǥ���'test'�ǡ����١������Ȥ��뤳�Ȥ�����Ȥ��롣

(use gauche.collection)
(use dbi)
(define *user* (sys-getenv "USER"))
(define *dbname* #`"mysql:,|*user*|::db=test")

;; ����Υƥ��ȤǺ��줿�ơ��֥뤬�ĤäƤ���Ф���򥯥ꥢ���Ƥ���
(cleanup-db "mysql" *user* "" "db=test")

(load "./persistence.scm")
