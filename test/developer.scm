;; test kahua.developer
;; Kahua.developer �⥸�塼��Υƥ���

;; $Id: developer.scm,v 1.1 2004/04/07 09:55:32 nobsun Exp $

(use gauche.test)
(use srfi-1)
(use file.util)
(use kahua.config)

;;---------------------------------------------------------------
;; start test
;; ��ȯ�ԥ�����������Υƥ��Ȥ򳫻Ϥ��롣
(test-start "developer")

;; �ƥ��ȴĶ�����
(define conf-file (build-path (sys-getcwd) "user.conf"))
(define conf-lock-file (string-append conf-file ".lock"))


(slot-set! (kahua-config) 'userconf-file conf-file)

(sys-system #`"rm -rf ,conf-file ,conf-lock-file")
(sys-system #`"touch ,conf-file")


;; ���ɥƥ���
;; kahua.developer �����ɤǤ����ޤ����Υ��󥿡��ե�������������
;; �ʤ����Ȥ��ǧ���롣
(use kahua.developer)
(test-module 'kahua.developer)

;; ��������Ȱ���ɽ�������ܡ�
;; �ޤ���ͤ���Ͽ���Ƥ��ʤ��Τǡ����ꥹ�Ȥˤʤ뤳�Ȥ��ǧ���롣
(test* "kahua-list-developer" '()
       (kahua-list-developer))

;; ��������� 3��ʬ����Ͽ���롣
;; ������������ #t ���֤����Ȥ��ǧ���롣
(test* "kahua-add-developer" #t
       (every (cut eq? <> #t)
              (list (kahua-add-developer "yusei" "^Epc4q-D" '(manager))
                    (kahua-add-developer "admin" "yqX^Vj8q" '(manager))
                    (kahua-add-developer "guest" "N_HHmW6h" '()))))

;; ��������Ȥ���Ͽ���롣
;; �ѥ���ɤ�û���Τ���Ͽ���Ԥ����顼�������뤳�Ȥ��ǧ���롣
(test* "kahua-add-developer bad password"
       *test-error*
       (kahua-add-developer "anonymous" "a" '()))

;; �����������Ͽ���롣
;; ̾����û���Τ���Ͽ���Ԥ������顼�������뤳�Ȥ��ǧ���롣
(test* "kahua-add-developer bad name"
       *test-error*
       (kahua-add-developer "" "anonymous" '()))

;; ��������Ȱ���ɽ�������ܡ�
;; ���٤���Ͽ����������3�ͤ�̾�����֤����Ȥ��ǧ���롣
(test* "kahua-list-developer" '("yusei" "admin" "guest")
       (kahua-list-developer))

;; ��������Ȥ������롣
;; guest �������������� #t ���֤����Ȥ��ǧ���롣
(test* "kahua-delete-developer" #t
       (kahua-delete-developer "guest"))

;; ��������Ȱ���ɽ�������ܡ�
;; guest ���������Τǡ��Ĥ�2�ͤ�̾�����֤����Ȥ��ǧ���롣
(test* "kahua-list-developer" '("yusei" "admin")
       (kahua-list-developer))

;; ��������Ȥ���Ͽ���롣
;; ����������Ȥˡ���������������Ȥ��������#t ���֤����Ȥ��ǧ���롣
(test* "kahua-add-developer" #t
       (kahua-add-developer "anonymous" "anonymous" '()))

;; ��������Ȱ���ɽ�������ܡ�
;; �ɲä�����������Ȥ�ޤ�ơ�3�ͤ�̾�����֤����Ȥ��ǧ���롣
(test* "kahua-list-developer" '("yusei" "admin" "anonymous")
       (kahua-list-developer))

;; ǧ�ڥƥ��ȣ����ܡ�
;; ��Ͽ����̾���ȥѥ���ɤ����פ���Τ� #t ���֤����Ȥ��ǧ���롣
(test* "kahua-check-developer" #t
       (kahua-check-developer "yusei" "^Epc4q-D"))

;; ǧ�ڥƥ��ȣ����ܡ�
;; ̾�����ְ�äƤ���Τ� #f ���֤����Ȥ��ǧ���롣
(test* "kahua-check-developer the name not found" #f
       (kahua-check-developer "yus" "^Epc4q-D"))

;; ǧ�ڥƥ��ȣ����ܡ�
;; �ѥ���ɤ��ְ�äƤ���Τ� #f ���֤����Ȥ��ǧ���롣
(test* "kahua-check-developer incorrect password" #f
       (kahua-check-developer "yusei" "^Epc4"))

;; �ѥ�����ѹ������ܡ�
;; ̾�������ѥ���ɤ��������Τ� #t ���֤����Ȥ��ǧ���롣
(test* "kahua-change-developer-password" #t
       (kahua-change-developer-password "admin" "WpX^krRS"))

;; �ѥ�����ѹ������ܡ�
;; ̾�����ְ�äƤ���Τǡ����顼�������뤳�Ȥ��ǧ���롣
(test* "kahua-change-developer-password the name not found"
       *test-error*
       (kahua-change-developer-password "adnim" "WpX^krRS"))

;; �ѥ�����ѹ������ܡ�
;; �ѥ���ɤ�û���Τǡ����顼�������뤳�Ȥ��ǧ���롣
(test* "kahua-change-developer-password password too short"
       *test-error*
       (kahua-change-developer-password "adnim" "Wp"))

(sys-system #`"rm -rf ,conf-file ,conf-lock-file")

(test-end)
