;; Keep configuration parameters
;;
;;  Copyright (c) 2003 Scheme Arts, L.L.C., All rights reserved.
;;  Copyright (c) 2003 Time Intermedia Corporation, All rights reserved.
;;  See COPYING for terms and conditions of using this software
;;
;; $Id: config.scm,v 1.9 2004/02/22 22:00:55 ko1 Exp $
;;
;; This is intended to be loaded by kahua servers to share common
;; configuration parameters.
;;
;; The configuration file is simply loaded.  It must contain
;; an expression that creates a singleton instance of <kahua-config>.
;;
;; (make <kahua-config>
;;   :sockbase ....
;;   :working-directory ...)
;;

(define-module kahua.config
  (use gauche.mop.singleton)
  (use file.util)
  (export kahua-init <kahua-custom> <kahua-config>
          kahua-config
          kahua-sockbase
          kahua-logpath
          kahua-config-file
          kahua-static-document-path
          kahua-static-document-url
          kahua-timeout-mins
          kahua-userconf-file
	  kahua-ping-timeout-sec
	  kahua-ping-interval-sec
          ))
(select-module kahua.config)

(define *kahua-conf-default* "/etc/kahua.conf")

(define-class <kahua-custom> ()
  (;; sockbase - specifies where to open the server socket.
   ;;     Currently only unix domain socket is supported.
   ;;     The socket directory must be writable by kahua processes.
   (sockbase          :init-keyword :sockbase
                      :init-value "unix:/tmp/kahua")
   ;; working-directory - where kahua processes keeps logs and
   ;;     other various info.  This directory must be writable by
   ;;     kahua processes.
   (working-directory :init-keyword :working-directory
                      :init-value "/var/lib/kahua")

   ;; static-document-path - where kahua process puts static documents.
   ;;     Httpd must be able to show the contents under this directory.
   ;;     This directoy must be writable by kahua processes.
   (static-document-path :init-keyword :static-document-path
                         :init-value "/var/www/html/kahua")

   ;; static-document-url - the url path to reference the contents of
   ;;     static-document-path via httpd.
   (static-document-url  :init-keyword :static-document-url
                         :init-value "/kahua")
   
   ;; repository - specifies where to use cvs repository
   (repository :init-keyword :repository
	       :init-value "/var/lib/kahua/cvs")

   ;; timeout-mins - session period of time
   (timeout-mins :init-keyword :timeout-mins
                 :init-value 60)

   
   ;; ping setting
   (ping-timeout-sec :init-keyword :ping-timeout-sec
		     :init-value 120)
   (ping-interval-sec :init-keyword :ping-interval-sec
		      :init-value 30)

   ;; userconf-file - developer account file
   (userconf-file :init-keyword :userconf-file
                  :init-value "/var/lib/kahua/user.conf")


   ;; internal
   (user-mode :init-value #f)
   (conf-file :init-value #f)
   )
  )


(define-class <kahua-config> (<kahua-custom> <singleton-mixin>) ())


(define-method initialize ((self <kahua-config>) initargs)
  (next-method)
  ;; repository path must be absolute(for cvs).
  (let1 reppath (ref self 'repository)
    (if (relative-path? reppath)
      (set! (ref self 'repository)
            (sys-normalize-pathname reppath :absolute #t)))))

(define (sanity-check kahua-conf)
;; do some sanity check
  (let1 wdir (ref kahua-conf 'working-directory)
    (unless (and (file-is-directory? wdir)
                 (file-is-writable? wdir))
      (error "working directory does not exist or is not writable:" wdir))
    (make-directory* (build-path wdir "logs"))
    (make-directory* (build-path wdir "checkout"))))


;; kahua-init [conf-file] [skip-check?]
;; if "skip-check?" is #t, read kahua.conf only(not check 
(define (kahua-init cfile . args)
  (let-keywords* args
      ((user #f)
       (skip-check? #f))
    (let1 cfile (or cfile *kahua-conf-default*)
      (if (file-is-readable? cfile)
        (begin
         (load cfile :environment (find-module 'kahua.config))
         (set! (ref (instance-of <kahua-config>) 'conf-file) cfile)
         ;; for running user-mode
         ;; make <kahua-custom> instance then copy slots value to
         ;; instance of <kahua-config>
         (if user
           (let* ((custom-file
                   (build-path
                    (ref (instance-of <kahua-config>) 'working-directory)
                    "user" user "custom.conf"))
                  (kahua-custom
                   (eval (call-with-input-file custom-file read)
                         (find-module 'kahua.config)))
                  (sockbase (build-path
                             (ref (instance-of <kahua-config>) 'sockbase)
                             "user" user)))
             ;; Copy instance of <kahua-custom> slot values
             ;; to instance of <kahua-config>. This is not good.
             (set! (ref (instance-of <kahua-config>) 'sockbase) sockbase)
             (set! (ref (instance-of <kahua-config>) 'user-mode) user)
             (set! (ref (instance-of <kahua-config>) 'working-directory)
                   (ref kahua-custom 'working-directory))
             (set! (ref (instance-of <kahua-config>) 'static-document-path)
                   (ref kahua-custom 'static-document-path))
             (set! (ref (instance-of <kahua-config>) 'static-document-url)
                   (ref kahua-custom 'static-document-url))
             (set! (ref (instance-of <kahua-config>) 'timeout-mins)
                   (ref kahua-custom 'timeout-mins))
             (set! (ref (instance-of <kahua-config>) 'ping-timeout-sec)
                   (ref kahua-custom 'ping-timeout-sec))
             (set! (ref (instance-of <kahua-config>) 'ping-interval-sec)
                   (ref kahua-custom 'ping-interval-sec))
             ))
         (unless skip-check? (sanity-check (instance-of <kahua-config>)))
         )
      (error "configuration file ~a is not readable.  using default settings."
            cfile))))
  ;; Include working directory to *load-path*.
  ;; We don't use add-load-path here, since it is a macro that does
  ;; work at compile time.
  (push! *load-path*
         (build-path (ref (instance-of <kahua-config>) 'working-directory)
                     "checkout"))
  (instance-of <kahua-config>))


;; utility functions

(define (kahua-config)
  (instance-of <kahua-config>))

(define kahua-sockbase
  (getter-with-setter
   (lambda () (ref (kahua-config) 'sockbase))
   (lambda (base) (set! (ref (kahua-config) 'sockbase) base))))

(define (kahua-logpath filename)
  (build-path (ref (kahua-config) 'working-directory)
              "logs" filename))

(define (kahua-config-file)
  (ref (kahua-config) 'conf-file))

(define (kahua-static-document-path path)
  (build-path (ref (kahua-config) 'static-document-path) path))

(define (kahua-static-document-url path)
  (build-path (ref (kahua-config) 'static-document-url) path))

(define (kahua-timeout-mins)
  (ref (kahua-config) 'timeout-mins))

(define (kahua-ping-timeout-sec)
  (ref (kahua-config) 'ping-timeout-sec))

(define (kahua-ping-interval-sec)
  (ref (kahua-config) 'ping-interval-sec))

(define (kahua-userconf-file)
  (ref (kahua-config) 'userconf-file))

(provide "kahua/config")
