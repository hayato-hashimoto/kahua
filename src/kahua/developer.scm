;; $id$

;; test kahua.developer

(use gauche.test)
(use srfi-1)
(use file.util)

(test-start "developer")
(use kahua.developer)
(test-module 'kahua.developer)


;; make test environment
(define conf-file (build-path (sys-getcwd) "user.conf"))
(define conf-lock-file (string-append conf-file ".lock"))

(use kahua.config)
(slot-set! (kahua-config) 'userconf-file conf-file)

(sys-system #`"rm -rf ,conf-file ,conf-lock-file")
(sys-system #`"touch ,conf-file")


;; start test
;; ��ȯ�ԥ�����������Υƥ��Ȥ򳫻�

;; ��������Ȱ���ɽ��
;; �ޤ���ͤ���Ͽ���Ƥ��ʤ��Τǡ����ꥹ�Ȥˤʤ롣
(test* "kahua-list-developer" '()
       (kahua-list-developer))

;; ��������� 3��ʬ����Ͽ
;; ������������ #t ���֤���
(test* "kahua-add-developer" #t
       (every (cut eq? <> #t)
              (list (kahua-add-developer "yusei" "^Epc4q-D" '(manager))
                    (kahua-add-developer "admin" "yqX^Vj8q" '(manager))
                    (kahua-add-developer "guest" "N_HHmW6h" '()))))

;; ��������Ȥ���Ͽ
;; �ѥ���ɤ�û���Τ���Ͽ���ԡ����顼�������롣
(test* "kahua-add-developer bad password"
       *test-error*
       (kahua-add-developer "anonymous" "a" '()))

;; �����������Ͽ
;; ̾����û���Τ���Ͽ���ԡ����顼�������롣
(test* "kahua-add-developer bad name"
       *test-error*
       (kahua-add-developer "" "anonymous" '()))

;; ��������Ȱ���ɽ�� ������
;; ���٤���Ͽ����������3�ͤ�̾�����֤���
(test* "kahua-list-developer" '("yusei" "admin" "guest")
       (kahua-list-developer))

;; ��������Ⱥ��
;; guest �������������ƿ����֤���
(test* "kahua-delete-developer" #t
       (kahua-delete-developer "guest"))

;; ��������Ȱ���ɽ�� ������
;; guest ���������Τǡ��Ĥ�2�ͤ�̾�����֤���
(test* "kahua-list-developer" '("yusei" "admin")
       (kahua-list-developer))

;; �����������Ͽ
;; ����������Ȥˡ���������������Ȥ�������������ƿ����֤���
(test* "kahua-add-developer" #t
       (kahua-add-developer "anonymous" "anonymous" '()))

;; ��������Ȱ���ɽ�� ������
;; �ɲä�����������Ȥ�ޤ�ơ�3�ͤ�̾�����֤���
(test* "kahua-list-developer" '("yusei" "admin" "anonymous")
       (kahua-list-developer))

;; ǧ��
;; ��Ͽ����̾���ȥѥ���ɤ����פ���Τǿ����֤���
(test* "kahua-check-developer" #t
       (kahua-check-developer "yusei" "^Epc4q-D"))

;; ǧ�ڣ�����
;; ̾�����ְ�äƤ���Τǵ����֤���
(test* "kahua-check-developer the name not found"
       *test-error*
       (kahua-check-developer "yus" "^Epc4q-D"))

;; ǧ�ڣ�����
;; �ѥ���ɤ��ְ�äƤ���Τǵ����֤���
(test* "kahua-check-developer incorrect password" #f
       (kahua-check-developer "yusei" "^Epc4"))

;; �ѥ�����ѹ�
;; ̾�����ѥ���ɤ��������Τǿ����֤���
(test* "kahua-change-developer-password" #t
       (kahua-change-developer-password "admin" "WpX^krRS"))

;; �ѥ�����ѹ�������
;; ̾�����ְ�äƤ���Τǡ����顼�������롣
(test* "kahua-change-developer-password the name not found"
       *test-error*
       (kahua-change-developer-password "adnim" "WpX^krRS"))


(sys-system #`"rm -rf ,conf-file ,conf-lock-file")

(test-end)