;; -*- mode: scheme; coding: utf-8 -*-
;; package maintainance shell script
;;
;;  Copyright (c) 2003-2007 Scheme Arts, L.L.C., All rights reserved.
;;  Copyright (c) 2003-2007 Time Intermedia Corporation, All rights reserved.
;;  See COPYING for terms and conditions of using this software
;;

(use gauche.parseopt)
(use kahua.config)

;;
;; create site bundle
;;

(define (init-site args)
  (let-args args
    ((shared "shared")
     (private "private")
     (owner "o|owner=s")
     (group "g|group=s")
     . sites)
    (if (null? sites)
      (usage)
      (for-each (cut kahua-site-create <> :owner owner :group group :shared? shared) sites))))

(define (main args)
  (let-args (cdr args)
    ((conf-file "c|conf-file=s")
     (site "S|site=s")
     (gosh "gosh=s")
     . restargs)
    (init-site restargs)))

(define (usage)
  (with-output-to-port (current-error-port)
    (lambda ()
      (display "usage: kahua-init [-shared|-private] [-owner=<owner>] [-group=<group>] <site-to-path>\n"))
    (exit)))
