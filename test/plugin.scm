;; test plugin module.
;; Kahua.plugin �⥸�塼��Υƥ���

;; $Id: plugin.scm,v 1.2 2005/06/26 12:27:38 tahara Exp $

(use gauche.test)
(use file.util)
(use kahua.sandbox)
(use kahua.config)


(test-start "plugin manager")

;; --------------------------------------------------------------
(test-section "initialization")
(sys-system "rm -rf _work")
(sys-mkdir "_work" #o775)
(sys-mkdir "_work/plugins" #o775)

(copy-file "../plugins/allow-module.scm" "_work/plugins/allow-module.scm")
(copy-file "../plugins/sendmail.scm" "_work/plugins/sendmail.scm")

(set! (ref (kahua-config) 'working-directory) "./_work")


;;---------------------------------------------------------------
;; �ץ饰����⥸�塼��Υƥ��Ȥ򳫻Ϥ��롣
(test-section "plugin")

;; ���ɥƥ���
;; kahua.plugin �����ɤǤ����ޤ����Υ��󥿡��ե�������������
;; �ʤ����Ȥ��ǧ���롣
(use kahua.plugin)
(test-module 'kahua.plugin)

;; �ץ饰����ν�������Ǥ��뤳�Ȥ��ǧ���롣
(test* "initialize plugins" "#<undef>"
       (x->string (initialize-plugins)))

;; �ץ饰������Ͽ���줿���Ȥ��ǧ���롣
(test* "are there plugins" #t
       (> (length (all-plugins)) 1))

;;---------------------------------------------------------------
;; ����ɥܥå�����ǤΥƥ���
(test-section "in a sandbox")

(define *sandbox* (make-sandbox-module))

;; �ץ饰���� srfi-1 ����ɤ������ˤ� filter ��³�����ʤ��Τǡ�
;; �ƥ��Ȥ˼��Ԥ��뤳�Ȥ��ǧ���롣
(test* "no plugin loads yet"
       *test-error*
       (eval '(filter odd? '(1 2 3 4 5))  *sandbox*))

;; �ץ饰���� srfi-1 ����ɤ������Ȥ� filter ��³����Ȥ��뤳�Ȥ�
;; ��ǧ���롣
(test* "load srfi-1 plugin"
       '(1 3 5)
       (eval '(begin (use srfi-1) (filter odd? '(1 2 3 4 5))) *sandbox*))

;; �ץ饰���� srfi-1 �� filter ��³���Ǥ��뤳�Ȥ��ǧ���롣
(test* "this is srfi-1's filter"
       (eval 'filter (find-module 'srfi-1))
       (eval 'filter *sandbox*))

;; �ץ饰���� gauche.collection ����ɤ������Ȥ� filter ��³����
;; gauche.collection�Τ�ΤǤ��뤳�Ȥ��ǧ���롣
(test* "replace filter to the gauche.collections's one"
       (eval 'filter (find-module 'gauche.collection))
       (eval '(begin (use gauche.collection) filter) *sandbox*))

;; �ץ饰���� sendmail ����ɤ������ˤ� sendmail ��³�����ʤ����Ȥ�
;; ��ǧ���롣
(test* "sendmail does not exists"
       *test-error*
       (eval 'sendmail *sandbox*))

;; �ץ饰���� sendmail ����ɤ������Ȥ� sendmail ��³�������뤳�Ȥ�
;; ��ǧ���롣
(test* "load sendmail plugin" #t
       (eval '(begin (use-plugin sendmail)
                     (symbol-bound? 'sendmail))
             *sandbox*))

(test-end)
