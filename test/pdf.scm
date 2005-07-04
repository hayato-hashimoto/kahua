;; -*- coding: euc-jp ; mode: scheme -*-
;; test PDF generation and typesetting
;; kahua.pdf �ƥ���

;; $Id: pdf.scm,v 1.2 2005/07/04 05:09:21 nobsun Exp $

(use gauche.test)
(use file.util)

;;---------------------------------------------------------------
;; �ƥ��ȳ���
(test-start "kahua.pdf")

;; ���ɥƥ���
;; kahua.pdf, kahua.pdf.* �����ɤǤ����ޤ����Υ��󥿡��ե�������
;; �������ʤ����Ȥ��ǧ���롣
(use kahua.pdf)
(test-module 'kahua.pdf)
(test-module 'kahua.pdf.interp)
(test-module 'kahua.pdf.main)
(test-module 'kahua.pdf.monad)
(test-module 'kahua.pdf.srfi-48)
(test-module 'kahua.pdf.state)
(test-module 'kahua.pdf.typeset)
(test-module 'kahua.pdf.util)

;;---------------------------------------------------------------
;; �ƥ����Ѥμ�³����������롣
;;
;;    �Υƥ��ȹ��ܡ�
;;
;;    pdf-01  SXML�����ǽ��ϡ�kahua-web��PDF���ϵ�ǽ��
;;            ��SXML�β��ϡ�ʿó��
;;            �����ܸ�ȱѸ줬���ߤ���ʸ�Ϥ����ǡ���§����
;;            ��PDF��ʸ������
;;
;;    pdf-02  ľ��kahua.pdf�⥸�塼���Ȥä��޷�����
;;            ��PDF����̿��ʱߡ��ʱߡ��ɤ�Ĥ֤������ꡢʸ�����ϡ���ɸ��ž��
;;
(define (pdf-01)
  (let*
      ((data (read (open-input-file "pdf-01.sxml")))
       (data (interp-html-pdf data))
       (data (exec/state (make-state 0 0 #t '() '()) data))
       (data (boxes-of-state data))
       (data (reverse (map reverse-lines data))))
    (with-docdata-to-file "_pdf-01.pdf" (lambda () data))))


(define (pdf-02)
  (with-document-to-file "_pdf-02.pdf"
   (lambda ()
     (let ((helvetica (build-font "Helvetica")))
       (with-page
        (lambda ()
          (in-text-mode
           (set-font (font-name helvetica) 16)
           (move-text 100 750)
           (draw-text "pdf-02"))
        
          (translate 50 600)
        
          (let ((x 50) (y 0))
            (do ((i 0 (+ i 1))
                 (j 8 (* j 1.05)))
                ((= i 4))
              (set-rgb-fill (* 0.1 j) (* 0.3 j) (* 0.1 j))
              (circle x y (* 3 j))
              (close-fill-and-stroke)
              (in-text-mode
               (move-text (- x 20) y)
               (set-gray-stroke 0)
               (set-gray-fill 0)
               (draw-text "Kahua"))
              (set-rgb-fill (* 0.2 j) (* 0.1 j) (* 0.3 j))
              (ellipse (- 500 x) y (* 4 j) (* 3 j))
              (close-fill-and-stroke)
              (in-text-mode
               (move-text (- 480 x) y)
               (set-gray-stroke 0)
               (set-gray-fill 0)
               (draw-text "Gauche"))
              (set! x (+ x 50))
              (set! y (+ y 50))
              ))

          (translate 300 -200)
          (do ((j 0 (+ j 1))
               (i 0.5 (* i 1.05)))
              ((= j 96))
            (in-text-mode
             (set-font (font-name helvetica) i)
             (move-text (* i 3) 0)
             (draw-text "kahua.pdf"))
            (rotate 18))))
       ))))


;; PDF�ե����������ƥ��Ȥ��Σ�
;;   S����ɽ�����줿HTML�ƥ����ȡ�pdf-01.sxml�ˤ��ɤ߹���
;;   �ƥ�������������PDF�ե������������
;;   ����ä���������PDF�ե�����Ȱ��פ��뤳�Ȥ��ǧ���롣
(pdf-01)
(test* "kahua.pdf.typeset" #t (file-equal? "./pdf-01-req.pdf" "./_pdf-01.pdf"))

;; PDF�ե����������ƥ��Ȥ��Σ�
;;   PDF����̿���Ȥäơ��޷���ޤ�PDF�ե������������
;;   ����ä���������PDF�ե�����Ȱ��פ��뤳�Ȥ��ǧ���롣
(pdf-02)
(test* "kahua.pdf" #t (file-equal? "./pdf-02-req.pdf" "./_pdf-02.pdf"))

(test-end)

