;; -*- mode: scheme; coding: euc-jp -*- 
(define-module kahua.error-report
  (use gauche.logger)
  (use kahua.util)
  (use kahua.elem)
  
  (export kahua-log-bug kahua-error-report-proc)
  )

(select-module kahua.error-report)

(define (kahua-error-report-proc exc)
  (let ((id (kahua-log-bug exc)))
    (html/
     (head/ (title/ "Error"))
     (body/
      (h1/ "���顼")
      (p/ #`"���顼�ֹ� (,|id|)")
      (p/ "���顼��ȯ�����ޤ������嵭�Υ��顼�ֹ�ȤȤ�˴����Ԥˤ�Ϣ����������")
      (h1/ "�ܺ�")
      (pre/ (kahua-error-string exc #t))
      ))))

;; returns bug-id
(define (kahua-log-bug exc)
  (let ((id (generate-bug-id)))
    (log-format "begin error: (~d)" id)
    (kahua-dump-user)
    (log-format "~a" (kahua-error-string exc #t))
    (log-format "end   error: (~d)" id)
    id))

(define (generate-bug-id)
  (format #f "~d-~d" (sys-time) (modulo (sys-random) 1000)))

(define (kahua-dump-user)
  (with-error-handler
    (lambda (e) (log-format "user dump failed"))
    (lambda ()  (log-format "user ~a" (kahua-current-user-name)))))

(provide "kahua/error-report")