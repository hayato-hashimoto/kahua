;; test admin scripts.  -*-mode:scheme-*-
;; this test isn't for modules, but for actual scripts.
;; kahua-admin �ƥ���

;; $Id: admin.scm,v 1.3 2004/10/19 02:37:34 shiro Exp $

(use gauche.test)
(use gauche.process)
(use gauche.net)
(use file.util)
(use kahua.config)
(use kahua.gsid)

(test-start "kahua-admin script")

;;---------------------------------------------------------------
(test-section "initialization")

(sys-system "rm -rf _tmp _work _cvs _src user.conf")
(sys-mkdir "_tmp" #o755)
(sys-mkdir "_work" #o755)
(sys-mkdir "_work/checkout" #o755)
(sys-mkdir "_work/plugins" #o755)

;; prepre cvs repository
(define repository (sys-normalize-pathname "./_cvs" :absolute #t))

(sys-mkdir "_cvs" #o755)
(run-process "cvs" "-d" repository "init" :wait #t)

(sys-mkdir "_src" #o755)
(sys-mkdir "_src/hello"    #o755)
(sys-mkdir "_src/greeting" #o755)
(sys-mkdir "_src/lister"   #o755)

(copy-file "hello-world.kahua" "_src/hello/hello.kahua")
(copy-file "greeting.kahua"    "_src/greeting/greeting.kahua")
(copy-file "lister.kahua"      "_src/lister/lister.kahua")

(copy-file "../plugins/allow-module.scm"  "_work/plugins/allow-module.scm")

(sys-chdir "./_src")
(run-process "cvs" "-Q" "-d" repository "import" "-m test" "." "vt" "rt"
  :wait #t)

(sys-chdir "../")

(run-process "cvs" "-Q" "-d" repository "checkout" "-d" "_work/checkout" 
	     "hello" "greeting" "lister" :wait #t)

;; copy user.conf
(copy-file "testuser.conf" "user.conf")

;; prepare app-servers file
(with-output-to-file "_work/app-servers"
  (lambda ()
    (write '((hello    :run-by-default 1)
             (greeting :run-by-default 0)
             (lister   :run-by-default 0)
             ))))

(define *config* "./test.conf")
(define *spvr*   #f)
(define *admin*  #f)

;;---------------------------------------------------------------
;; �ƥ��Ȥ�ɬ�פ�2�ĤΥ�����ץȤ�ư���롣
(test-section "run scripts")

;; kahua-spvr ��ư���롣
(test* "start spvr" #t
       (let ((p (run-process "../src/kahua-spvr" "--test"
			     "-c" *config*)))
	 (sys-sleep 3)
	 (and (file-exists? "_tmp/kahua")
	      (or (eq? (file-type "_tmp/kahua") 'socket)
                  (eq? (file-type "_tmp/kahua") 'fifo)))))

;; kahua-admin ��ư���롣
(test* "start admin" 'spvr>
       (let ((p (run-process "../src/kahua-admin" "--test"
			     "-c" *config* 
			     :input :pipe :output :pipe :error :pipe)))
	 (set! *admin* p)
	 (sys-sleep 1)
	 (let* ((out (process-input  *admin*))
		(in  (process-output *admin*)))
	   (read in))))

;;---------------------------------------------------------------
;; �ƥ����ѤΥ桼�ƥ���ƥ���������롣
(test-section "define utilities")

(define (admin-out)
  (process-input *admin*))
(define (admin-in)
  (process-output *admin*))

(define (send msg)
  (let* ((out (admin-out)))
    (write msg out)
    (newline out)))

(define (send&recv msg)
  (let* ((out (admin-out))
	 (in  (admin-in)))
    (read in)      ;; read prompt
    (if (pair? msg)
	(for-each (lambda (e)
		    (write e out) (display " " out)) msg)
	(write msg out))   ;; write command
    (newline out)
    (flush out)
    (read in)))

(define (send&recv-str msg)
  (let* ((out (admin-out))
	 (in  (admin-in)))
    (read in)         ;; read prompt
    (if (pair? msg)
	(for-each (lambda (e)
		    (write e out) (display " " out)) msg)
	(write msg out))   ;; write command
    (newline out)
    (flush out)
    (sys-sleep 2)
    (let1 ret (read-block 1000 in)
	  (newline out)
	  (string-incomplete->complete ret))))

(newline (admin-out))


;;------------------------------------------------------------
;; kahua-admin ��ư����ǧ���롣
(test-section "spvr command test")

;; ls ���ޥ�ɤ�¹ԡ�
;; hello ���ץꥱ������󤬰����ˤ��뤳�Ȥ��ǧ���롣
(test* "admin: ls" #f
       (not (#/wno\s+pid\s+type\s+since\s+wid.+hello/
	     (send&recv-str 'ls))))

;; help ���ޥ�ɤ�¹ԡ�
;; ���ޥ�ɤΥꥹ�Ȥ�ɽ������뤳�Ȥ��ǧ���롣
(test* "admin: help" #t
       (let1 ans (send&recv 'help)
	     (and (list? ans)
		  (< 0 (length ans)))))

;; type ���ޥ�ɤ�¹ԡ�
;; hello greeting lister ��3�ĤΥ��ץꥱ�������ɽ�������
;; ���Ȥ��ǧ���롣
(test* "admin: types" '(hello greeting lister)
       (send&recv 'types))

;; run ���ޥ�ɤΥƥ��ȡ�1���ܡ�
;; greeting ����ư���뤳�Ȥ��ǧ���롣
(test* "admin: run greeting" #f
       (let1 ans (send&recv-str '(run greeting))
	     (not (#/greeting/ ans))))

;; run ���ޥ�ɤΥƥ��ȡ�2���ܡ�
;; lister ����ư���뤳�Ȥ��ǧ���롣
(test* "admin: run lister" #f
       (let1 ans (send&recv-str '(run lister))
	     (not (#/lister/ ans))))

;; kill ���ޥ�ɤΥƥ��ȡ�
;; greeting ��λ�Ǥ��뤳�Ȥ��ǧ���롣
(test* "admin: kill 1(greeting)" #f
       (let1 ans (send&recv-str '(kill 1))
	     (#/greeting/ ans)))

;; reload ���ޥ�ɤΥƥ��ȡ�
;; app-server ����Ͽ����Ƥ���3�ĤΥ��ץꥱ�������
;; ɽ������뤳�Ȥ��ǧ���롣
(test* "admin: reload" '(hello greeting lister)
       (send&recv 'reload))

;; update ���ޥ�ɤΥƥ���
;; hello �򹹿��Ǥ��뤳�Ȥ��ǧ���롣
(test* "admin: update" 'update:
       (send&recv '(update hello)))

;;------------------------------------------------------------
;; kahua-server ����³���� connect ���ޥ�ɤ�ƥ��Ȥ��롣
(test-section "server connect test")

;; ������ֹ� 0 hello ����³�Ǥ��뤳�Ȥ��ǧ���롣
(test* "admin: connect 0(hello)" #t
       (not (not (#/hello/ (send&recv-str '(connect 0))))))

;; ��³�褬 hello �Ǥ��뤳�Ȥ��ǧ���롣
(test* "admin: connect: (kahua-worker-type)" "hello"
       (begin
	 (write '(kahua-worker-type) (admin-out))
	 (newline (admin-out))
	 (flush (admin-out))
	 (read (admin-in))))

;; hello �������ǤǤ��뤳�Ȥ��ǧ���롣
(test* "admin: connect: disconnect" #f
       (begin
	 (write 'disconnect (admin-out))
	 (newline (admin-out))
	 (flush (admin-out))
	 (sys-sleep 1)
	 (not (#/spvr>/ (string-incomplete->complete
			 (read-block 1000 (admin-in)))))))

(newline (admin-out))

;;------------------------------------------------------------
;; cvs ���ޥ�ɤ�ƥ��Ȥ��롣
(test-section "cvs test")

;; cvs update ���ޥ�ɤ�¹ԤǤ��뤳�Ȥ��ǧ���롣
(test* "admin: cvs update" #f
       (not (send&recv-str '(cvs update hello))))

;;------------------------------------------------------------
;; ��ȯ�ԥ�������Ȥ�ƥ��Ȥ��롣
(test-section "developer account test")

;; lsuser ���ޥ�ɤ�¹Ԥ����桼�� gandalf ��ͤ������ˤ��뤳�Ȥ�
;; ��ǧ���롣
(test* "admin: lsuser" '("gandalf")
       (send&recv '(lsuser)))

;; adduser ���ޥ�ɤ�¹Ԥ����桼�� bilbo ����Ͽ�Ǥ��뤳�Ȥ�
;; ��ǧ���롣
(test* "admin: adduser" 'done
       (send&recv '(adduser bilbo baggins)))

;; lsuser ���ޥ�ɤ�¹Ԥ����桼�� gandalf �� bilbo �������ˤ��뤳�Ȥ�
;; ��ǧ���롣
(test* "admin: lsuser" '("gandalf" "bilbo")
       (send&recv '(lsuser)))

;; deluser ���ޥ�ɤ�¹Ԥ����桼�� gandalf �����Ǥ��뤳�Ȥ��ǧ���롣
(test* "admin: deluser" 'done
       (send&recv '(deluser gandalf)))

;; lsuser ���ޥ�ɤ�¹Ԥ����桼�� bilbo ��ͤ������ˤ��뤳�Ȥ��ǧ���롣
(test* "admin: lsuser" '("bilbo")
       (send&recv '(lsuser)))


;;------------------------------------------------------------
;; �ƥ��Ƚ�λ����
(test-section "finalize")

;; shutdown ���ޥ�ɤ�¹Ԥ���kahua-spvr ����λ�Ǥ��뤳�Ȥ��ǧ���롣
(test* "shutdown spvr" '()
       (begin
	 (send&recv 'shutdown)
	 (sys-sleep 1)
	 (directory-list "_tmp" :children? #t)))

;; kahua-admin ����λ���뤳�Ȥ��ǧ���롣
(test* "shutdown admin" #t
       (begin
	 (process-send-signal *admin* SIGTERM)
         (sys-sleep 1) ;; give the spvr time to shutdown ...
	 (process-wait *admin*)))

(test-end)

