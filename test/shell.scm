;; test shell scripts.
;; this test isn't for modules, but for actual scripts.
;; kahua-shell �Υƥ���

;; $Id: shell.scm,v 1.1 2004/04/07 09:55:33 nobsun Exp $

(use gauche.test)
(use gauche.process)
(use gauche.net)
(use file.util)
(use kahua.config)
(use kahua.gsid)

(test-start "kahua-shell script")

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
(define *shell*  #f)

;; in order to propagate load-path to child process
(sys-putenv "GAUCHE_LOAD_PATH" "../src:.")
(sys-putenv "PATH" (cond ((sys-getenv "PATH") => (lambda (x) #`"../src:,x"))
                         (else "../src")))


;;---------------------------------------------------------------
;; kahua-shell �Υƥ��Ȥ򳫻Ϥ��롣
(test-section "run scripts")

;; kahua-shell ���̿����� kahua-spvr ��ư���롣
(test* "start spvr" #t
       (let ((p (run-process 'gosh "-I../src" "../src/kahua-spvr" 
			     "-c" *config*)))
         (set! *spvr* p)
	 (sys-sleep 3)
	 (and (file-exists? "_tmp/kahua")
	      (eq? (file-type "_tmp/kahua") 'socket))))

;; kahua-shell ��ư���롣
(test* "start shell" "Welcome to Kahua."
       (let ((p (run-process 'env "-u" "TERM" "gosh" "-I../src" "../src/kahua-shell"
			     "-c" *config* 
			     :input :pipe :output :pipe :error :pipe)))
	 (set! *shell* p)
	 (sys-sleep 1)
	 (let* ((out (process-input  *shell*))
		(in  (process-output *shell*)))
           (read-line in))
           ))

;;---------------------------------------------------------------
;; �ƥ��Ȥ�ɬ�פʥ桼�ƥ���ƥ���������롣
(test-section "define utilities")

(define (shell-out)
  (process-input *shell*))
(define (shell-in)
  (process-output *shell*))

(define (send msg)
  (let* ((out (shell-out)))
    (write msg out)
    (newline out)))

(define (recv)
  (read (shell-in)))

(define (send&recv msg)
  (let* ((out (shell-out))
	 (in  (shell-in)))
    (read in)      ;; read prompt
    (if (pair? msg)
	(for-each (lambda (e)
		    (write e out) (display " " out)) msg)
	(write msg out))   ;; write command
    (newline out)
    (flush out)
    (read in)))

(define (send&recv-str msg)
  (let* ((out (shell-out))
	 (in  (shell-in)))
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


;;------------------------------------------------------------
;; �����륳�ޥ�ɤ�ƥ���
(test-section "shell command test")

(sys-sleep 3)

;; ǧ�ڥƥ��ȡ�
;; ���ץꥱ������󥵡��Ф�����ץ��ץȤ��Ф뤳�Ȥ��ǧ���롣
(test* "shell: login" "select wno> "
       (begin
         (recv)
         (send 'gandalf)
         (sys-sleep 1)
         (recv)
         (send 'friend)
         (sys-sleep 1)
         (read-line (shell-in))
         (sys-sleep 1)
         (read-line (shell-in))
         (sys-sleep 1)
         (string-incomplete->complete (read-block 1000 (shell-in)))
         ))

;; ǧ�ڤ��줿����³���륢�ץꥱ������󥵡��Ф����򤷤ƥ����󤹤롣
;; �ץ��ץȤ���³��Υ��ץꥱ�������̾(hello)�Ǥ��뤳�Ȥ��ǧ���롣
(test* "shell: select worker" #f
       (begin
         (sys-sleep 1)
         (send '0)
         (sys-sleep 1)
         (not
          (#/hello/
           (string-incomplete->complete (read-block 1000 (shell-in)))
           )))
         )

;; ��³�褬���ץꥱ�������Ǥ��뤫��
;; �����ȥ⥸�塼�뤬̵̾�⥸�塼��(����ɥܥå���)�Ǥ��뤳�Ȥ��ǧ���롣
(test* "shell: evaluation" "#<module #>"
       (begin
         (sys-sleep 1)
         (send '(current-module))
         (sys-sleep 1)
         (car (string-split
               (string-incomplete->complete (read-block 1000 (shell-in)))
               "\n"))
         )
       )


;;------------------------------------------------------------
;; �ƥ��Ȥν�λ������
(test-section "finalize")

;; kahua-spvr ��λ���롣
(process-send-signal *spvr* SIGTERM)

(test* "shutdown shell" #t
       (begin
	 (process-send-signal *shell* SIGTERM)
         (sys-sleep 1) ;; give the spvr time to shutdown ...
	 (process-wait *shell*)))

(test-end)

