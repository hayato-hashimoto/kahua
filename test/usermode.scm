;; test user exclusive mode.
;; �桼�����ѥ⡼�ɤΥƥ���

;; $Id: usermode.scm,v 1.1 2004/04/07 09:55:33 nobsun Exp $

(use gauche.test)
(use gauche.process)
(use gauche.net)
(use file.util)
(use kahua.config)
(use kahua.gsid)

(test-start "user exclusive mode")

;;---------------------------------------------------------------
(test-section "initialization")

(sys-system "rm -rf _tmp _work _cvs _src user.conf")
(sys-mkdir "_tmp" #o755)
(sys-mkdir "_tmp/user" #o755)
(sys-mkdir "_tmp/user/gandalf" #o755)
(sys-mkdir "_work" #o755)
(sys-mkdir "_work/user" #o755)
(sys-mkdir "_work/user/gandalf" #o755)
(sys-mkdir "_work/user/gandalf/checkout" #o755)
(sys-mkdir "_work/user/gandalf/plugins" #o755)

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

(copy-file "../plugins/allow-module.scm"
           "_work/user/gandalf/plugins/allow-module.scm")
(copy-file "testcustom.conf"
           "_work/user/gandalf/custom.conf")


(sys-chdir "./_src")
(run-process "cvs" "-Q" "-d" repository "import" "-m test" "." "vt" "rt"
  :wait #t)

(sys-chdir "../")

(run-process "cvs" "-Q" "-d" repository "checkout" "-d"
             "_work/user/gandalf/checkout" 
	     "hello" "greeting" "lister" :wait #t)

;; copy user.conf
(copy-file "testuser.conf" "user.conf")

;; prepare app-servers file
(with-output-to-file "_work/user/gandalf/app-servers"
  (lambda ()
    (write '((hello    :run-by-default 1)
             (greeting :run-by-default 0)
             (lister   :run-by-default 0)
             ))))

(define *config* "./test.conf")
(define *spvr*   #f)
(define *admin*  #f)
(define *shell*  #f)

;; in order to propagate load-path to child process
(sys-putenv "GAUCHE_LOAD_PATH" "../src:.")
(sys-putenv "PATH" (cond ((sys-getenv "PATH") => (lambda (x) #`"../src:,x"))
                         (else "../src")))

;;---------------------------------------------------------------
;; Test user exclusive mode.
;; Run three programs with -user option.
;; Load custom.conf from user directory then overwrite test.conf and
;; set working directory.
;;
;; �桼�����ѥ⡼�ɥƥ���
;; 3�ĤΥץ����� -user ���ץ�����դ��Ǽ¹ԡ�
;; �桼���ǥ��쥯�ȥ꤫�� custom.conf ���ɤ߹���� test.conf �������
;; ��񤭤�������󥰥ǥ��쥯�ȥ�򥻥åȤ��롣
;; 


;; �ƥ��Ȥ�ɬ�פ�3�ĤΥ�����ץȤ�桼�����ѥ⡼�ɤǵ�ư���롣
(test-section "run scripts in user exclusive mode.")

;; kahua-spvr ��桼�����ѥ⡼�ɤǵ�ư���롣
;; -user ���ץ�����դ��ǵ�ư���뤳�Ȥ��ǧ���롣
(test* "start spvr" #t
       (let ((p (run-process 'gosh "-I../src" "../src/kahua-spvr"
			     "-c" *config* "-user" "gandalf")))
	 (sys-sleep 3)
	 (and (file-exists? "_tmp/user/gandalf/kahua")
	      (eq? (file-type "_tmp/user/gandalf/kahua") 'socket))))

;; kahua-admin ��桼�����ѥ⡼�ɤǵ�ư���롣
;; -user ���ץ�����դ��ǵ�ư���뤳�Ȥ��ǧ���롣
(test* "start admin" 'spvr>
       (let ((p (run-process 'gosh "-I../src" "../src/kahua-admin"
			     "-c" *config* "-user" "gandalf"
			     :input :pipe :output :pipe :error :pipe)))
	 (set! *admin* p)
	 (sys-sleep 1)
	 (let* ((out (process-input  *admin*))
		(in  (process-output *admin*)))
	   (read in))))

;; kahua-admin ��桼�����ѥ⡼�ɤǵ�ư���롣
;; -user ���ץ�����դ��ǵ�ư���뤳�Ȥ��ǧ���롣
(test* "start shell" "Welcome to Kahua."
       (let ((p (run-process 'env "-u" "TERM" "gosh" "-I../src"
                             "../src/kahua-shell"
			     "-c" *config* "-user" "gandalf"
			     :input :pipe :output :pipe :error :pipe)))
	 (set! *shell* p)
	 (sys-sleep 1)
	 (let* ((out (process-input  *shell*))
		(in  (process-output *shell*)))
           (read-line in))
           ))

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

(define (shell-out)
  (process-input *shell*))
(define (shell-in)
  (process-output *shell*))

(define (send-shell msg)
  (let* ((out (shell-out)))
    (write msg out)
    (newline out)))


;;------------------------------------------------------------
;; �桼�����ѥ⡼�ɤǤ� kahua-admin ��ư����ǧ���롣
(test-section "kahua-admin with -user option")

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
;; �桼�����ѥ⡼�ɤǤ� kahua-shell ��ư����ǧ���롣
(test-section "kahua-shell with -user option")


;; ǧ�ڥƥ��ȡ�
;; �桼��ǧ�ڤ�ѥ�����������Ǥ��뤳�Ȥ��ǧ���롣
(test* "shell: login" "select wno> "
       (begin
         (read (shell-in))
         (send-shell 'friend)
         (sys-sleep 1)
         (read-line (shell-in))
         (sys-sleep 1)
         (read-line (shell-in))
         (sys-sleep 1)
         (read-line (shell-in))
         (sys-sleep 1)
         (string-incomplete->complete (read-block 1000 (shell-in)))
         ))

;; �����(��ư��Υ��ץꥱ�������)�ΰ������� hello �������
;; ���ץꥱ�������Ķ�������뤳�Ȥ��ǧ���롣
(test* "shell: select worker" #f
       (begin
         (sys-sleep 1)
         (send-shell '0)
         (sys-sleep 1)
         (not
          (#/hello/
           (string-incomplete->complete (read-block 1000 (shell-in)))
           )))
         )

;; ��³�褬���ץꥱ�������Ķ�(̵̾�⥸�塼��)�Ǥ��뤳�Ȥ��ǧ���롣
(test* "shell: evaluation" "#<module #>"
       (begin
         (sys-sleep 1)
         (send-shell '(current-module))
         (sys-sleep 1)
         (car (string-split
               (string-incomplete->complete (read-block 1000 (shell-in)))
               "\n"))
         )
       )

;;------------------------------------------------------------
;; �ƥ��Ƚ�λ����
;; �ƥ����Ѥ˵�ư�����ץ�����λ���롣
(test-section "finalize")


;; kahua-shell ����λ���뤳�Ȥ��ǧ���롣
(test* "shutdown shell" #t
       (begin
	 (process-send-signal *shell* SIGTERM)
         (sys-sleep 1) ;; give the spvr time to shutdown ...
	 (process-wait *shell*)))

;; kahua-spvr ����λ���뤳�Ȥ��ǧ���롣
(test* "shutdown spvr" '()
       (begin
	 (send&recv 'shutdown)
	 (sys-sleep 1)
	 (directory-list "_tmp/user/gandalf" :children? #t)))

;; kahua-admin ����λ���뤳�Ȥ��ǧ���롣
(test* "shutdown admin" #t
       (begin
	 (process-send-signal *admin* SIGTERM)
         (sys-sleep 1) ;; give the spvr time to shutdown ...
	 (process-wait *admin*)))

(test-end)

