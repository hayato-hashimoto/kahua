;; -*- coding: euc-jp ; mode: scheme -*-
;; PostgreSQL�Хå�����ɤΥƥ���
;; $Id: persistence-dbi-pg.scm,v 1.5 2006/10/24 06:14:53 bizenn Exp $

;; Notes:
;;  * �ƥ��ȥ��������Τ�persistence.scm�Τ�Τ�Ȥ���
;;  * postmaster�����äƤ��ꡢ�Ķ��ѿ�$USER�Υ�������Ȥǥѥ����̵����
;;    ������Ǥ����ǥե���ȥǡ����١������Ȥ��뤳�Ȥ�����Ȥ��롣

(use gauche.collection)
(use dbi)
(define *user* (sys-getenv "USER"))
(define *dbname* #`"postgresql:,|*user*|::")

;; ����Υƥ��ȤǺ��줿�ơ��֥뤬�ĤäƤ���Ф���򥯥ꥢ���Ƥ���
(load "./persistence-dbi.scm")
(cleanup-db "pg" *user* "" "")

(load "./persistence.scm")
