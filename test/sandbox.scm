;; -*- coding: euc-jp ; mode: scheme -*-
;; test sandbox module.
;; Kahua.sandbox �⥸�塼��Υƥ���

;; $Id: sandbox.scm,v 1.2 2005/07/04 05:09:21 nobsun Exp $


(use gauche.test)
(use kahua.plugin)

(test-start "sandbox test")

(define *sandbox* #f)

;;---------------------------------------------------------------
;; ���ɥƥ���
;; kahua.sandbox �����ɤǤ����ޤ����Υ��󥿡��ե�������������
;; �ʤ����Ȥ��ǧ���롣
(use kahua.sandbox)
(test-module 'kahua.sandbox)


;; ����ɥܥå����⥸�塼�������������줬̵̾�⥸�塼���
;; ���뤳�Ȥ��ǧ���롣
(test* "make sandbox module" "#<module #>"
       (let ((m (make-sandbox-module)))
         (set! *sandbox* m)
         (x->string m)))

;; �����ʼ�³���Υƥ��Ȥ���1��
;; ����ɥܥå����ǵ��Ĥ���Ƥ����³���� car ���Ȥ��뤳�Ȥ��ǧ���롣
(test* "check available binding, car"
       '1
       (eval '(car '(1 2 3)) *sandbox*))

;; �����ʼ�³���Υƥ��Ȥ���2��
;; ����ɥܥå����ǵ��Ĥ���Ƥ����³���� define ���Ȥ��뤳�Ȥ��ǧ���롣
(test* "check available binding, define"
       'square
       (eval '(define (square n) (* n n)) *sandbox*))

;; ���ߡ���«���򤷤����ʼ�³���Υƥ��Ȥ���1��
;; open-input-file ��ɾ������ȥ��顼�ˤʤ뤳�Ȥ��ǧ���롣
(test* "check disablebinding, open-input-file"
       *test-error*
       (eval '(open-input-file "/etc/passwd") *sandbox*))

;; ���ߡ���«���򤷤����ʼ�³���Υƥ��Ȥ���2��
;; open-output-file ��ɾ������ȥ��顼�ˤʤ뤳�Ȥ��ǧ���롣
(test* "check disablebinding, open-output-file"
       *test-error*
       (eval '(open-output-file "evil") *sandbox*))

;; ���ߡ���«���򤷤����ʼ�³���Υƥ��Ȥ���3��
;; call-with-input-file ��ɾ������ȥ��顼�ˤʤ뤳�Ȥ��ǧ���롣
(test* "check disablebinding, call-with-input-file"
       *test-error*
       (eval '(call-with-input-file "/etc/passwd" read-line) *sandbox*))

;; ���ߡ���«���򤷤����ʼ�³���Υƥ��Ȥ���4��
;; call-with-output-file ��ɾ������ȥ��顼�ˤʤ뤳�Ȥ��ǧ���롣
(test* "check disablebinding, call-with-output-file"
       *test-error*
       (eval '(call-with-output-file "evil"
                (lambda (in) (format in "#!/bin/sh\n")
                             (format in "killall gosh")))
             *sandbox*))

;; ���ߡ���«���򤷤����ʼ�³���Υƥ��Ȥ���5��
;; load ��ɾ������ȥ��顼�ˤʤ뤳�Ȥ��ǧ���롣
(test* "check disablebinding, load"
       *test-error*
       (eval '(load "gauche/process") *sandbox*))

;; ���ߡ���«���򤷤����ʼ�³���Υƥ��Ȥ���6��
;; require ��ɾ������ȥ��顼�ˤʤ뤳�Ȥ��ǧ���롣
(test* "check disablebinding, require"
       *test-error*
       (eval '(require "gauche/net") *sandbox*))

;; ���ߡ���«���򤷤����ʼ�³���Υƥ��Ȥ���7��
;; import ��ɾ������ȥ��顼�ˤʤ뤳�Ȥ��ǧ���롣
(test* "check disablebinding, import"
       *test-error*
       (eval '(import kahua.sandbox) *sandbox*))

;; ���ߡ���«���򤷤����ʼ�³���Υƥ��Ȥ���8��
;; select-module ��ɾ������ȥ��顼�ˤʤ뤳�Ȥ��ǧ���롣
(test* "check disablebinding, select-module"
       *test-error*
       (eval '(select-module user) *sandbox*))

;; ���ߡ���«���򤷤����ʼ�³���Υƥ��Ȥ���9��
;; with-module ��ɾ������ȥ��顼�ˤʤ뤳�Ȥ��ǧ���롣
(test* "check disablebinding, with-module"
       *test-error*
       (eval '(with-module user (open-input-file "/etc/passwd"))
             *sandbox*))

;; ���ߡ���«���򤷤����ʼ�³���Υƥ��Ȥ���10��
;; use �ǥץ饰�������Ͽ����Ƥ��ʤ��⥸�塼���ɾ�������
;; ���顼�ˤʤ뤳�Ȥ��ǧ���롣
(test* "check overrided, use"
       *test-error*
       (eval '(use file.util) *sandbox*))

(test-end)

