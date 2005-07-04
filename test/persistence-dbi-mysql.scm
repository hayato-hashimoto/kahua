;; -*- coding: euc-jp ; mode: scheme -*-
;; MySQL��В�Ò��������ɒ�Β�ƒ�����
;; $Id: persistence-dbi-mysql.scm,v 1.2 2005/07/04 05:09:21 nobsun Exp $

;; Notes:
;;  * ��ƒ����Ȓ�������������Β��persistence.scm��Β�⒤Β��Ȓ�����
;;  * mysqld��������Ò�ƒ����꒡���Ē����ђ��$USER��Β�����������Ȓ�ǒ�ђ�������ɒ̵������
;;    ��풥�������ǒ�����'test'��ǒ�������ْ����������Ȓ����뒤���Ȓ�������Ȓ����뒡�

(use gauche.collection)
(use dbi)
(define *user* (sys-getenv "USER"))
(define *dbname* #`"mysql:,|*user*|::db=test")

;; ������Β�ƒ����Ȓ�ǒ�钤쒤���ƒ����֒�뒤���Ē�Ò�ƒ����쒤В����쒤򒥯��꒥������ƒ�����
(cleanup-db "mysql" *user* "" "db=test")

(load "./persistence.scm")
