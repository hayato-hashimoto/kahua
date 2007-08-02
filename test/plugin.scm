;; -*- coding: utf-8 ; mode: scheme -*-
;; test plugin module.
;; Kahua.plugin モジュールのテスト

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
;; プラグインモジュールのテストを開始する。
(test-section "plugin")

;; ロードテスト
;; kahua.plugin がロードでき、またそのインターフェイスに齟齬が
;; ないことを確認する。
(use kahua.plugin)
(test-module 'kahua.plugin)

;; プラグインの初期化ができることを確認する。
(test* "initialize plugins" "#<undef>"
       (x->string (initialize-plugins)))

;; プラグインが登録されたことを確認する。
(test* "are there plugins" #t
       (> (length (all-plugins)) 1))

;;---------------------------------------------------------------
;; サンドボックス内でのテスト
(test-section "in a sandbox")

(define *sandbox* (make-sandbox-module))

;; プラグイン srfi-1 をロードする前には filter 手続きがないので、
;; テストに失敗することを確認する。
(test* "no plugin loads yet"
       *test-error*
       (eval '(filter odd? '(1 2 3 4 5))  *sandbox*))

;; プラグイン srfi-1 をロードしたあとに filter 手続きを使えることを
;; 確認する。
(test* "load srfi-1 plugin"
       '(1 3 5)
       (eval '(begin (use srfi-1) (filter odd? '(1 2 3 4 5))) *sandbox*))

;; プラグイン srfi-1 の filter 手続きであることを確認する。
(test* "this is srfi-1's filter"
       (eval 'filter (find-module 'srfi-1))
       (eval 'filter *sandbox*))

;; プラグイン gauche.collection をロードしたあとに filter 手続きが
;; gauche.collectionのものであることを確認する。
(test* "replace filter to the gauche.collections's one"
       (eval 'filter (find-module 'gauche.collection))
       (eval '(begin (use gauche.collection) filter) *sandbox*))

;; プラグイン sendmail をロードする前には sendmail 手続きがないことを
;; 確認する。
(test* "sendmail does not exists"
       *test-error*
       (eval 'sendmail *sandbox*))

;; プラグイン sendmail をロードしたあとに sendmail 手続きがあることを
;; 確認する。
(test* "load sendmail plugin" #t
       (eval '(begin (use-plugin sendmail)
                     (global-variable-bound? (current-module) 'sendmail))
             *sandbox*))

(test-end)
