                                        ; BSD-3-Clause : Copyright © 2025 Abigale Raeck.
                                        ; Guile bytecodes to Zig types
(use-modules
 (srfi srfi-1)
 (ice-9 match)
 (ice-9 format)
 (language bytecode))

;; "c24" -> '(C . 24)
(define (split-unit unit)
  (let ((idx (string-index unit char-numeric?)))
    (cons
     (string->symbol (string-upcase (substring unit 0 idx)))
     (string->number (substring unit idx)))))

;; low->high bytes
;; 'X8_S12_S12 => '((X . 8) (S . 12) (S . 12))
(define (split-operand-word sym)
  (if (eq? sym 'V32_X8_L24)
      '((V32_X8_L24 . 32)) ;; don't split the var length field (treat as one of a kind case)
      (map split-unit (string-split (symbol->string sym) #\_))))

                                        ; Naming

;; 'uadd/immediate => "uadd_with_immediate"
;; 'u64-imm<? =>  "is_u64_immediate_less_than"
(define (scheme-name->zig-name name)
  (define (sub s rst)
    (list (reverse (string->list s))
          rst))

  (define predicate-name #f)

  (define (is-pred)
    (set! predicate-name #t))

  (define (clean chr-lst)
    (string-append
     (if predicate-name "is_" "")
     (string-trim-both
      (list->string
       (fold (λ (c lst)
               (if (char=? c (car lst) #\_) ;; chomp extra underscores eg. =__=
                   lst
                   (cons c lst)))
             (list (car chr-lst))
             (cdr chr-lst)))
      #\_)))
  
  (let lp ((in (string->list name))
           (out '()))
    (if (nil? in)
        (clean out)
        (let ((p (match in
                   ((and (#\i #\m #\m . rest)
                         (not (#\i #\m #\m #\e . _)))
                    (sub "_immediate_" rest))
                   
                   ((#\< #\= #\? . rest) (is-pred) (sub "_less_than_equal_" rest))
                   ((#\= #\? . rest) (is-pred) (sub "_equal_" rest))
                   ((#\< #\? . rest) (is-pred) (sub "_less_than_" rest))
                   ((#\< #\- . rest) (sub "_from_" rest))
                   ((#\- #\> . rest) (sub "_to_" rest))
                   ((#\+ . rest) (sub "_and_" rest))
                   ((#\! . rest) (sub "_x_" rest))
                   ((#\- . rest) (list '(#\_) rest))
                   ((#\/ . rest) (sub "_with_" rest))
                   ((#\? . rest) (is-pred) `(() ,rest))
                   (((? char-upper-case? c) . rest) `((#\_ ,(char-downcase c)) ,rest))
                   ((c . rest) `((,c) ,rest)))))
          
          (lp (cadr p) (append (car p) out))))))

(define-syntax-rule (inc! place)
  (set! place (1+ place)))

(define field-names (map string (string->list "abcdefghij")))

(define (map-field-names instruction-args)
  (define f-index 0)
  (define x-count 0)

  (define (gensym-x)
    (let ((sym (string-append "_x" (number->string x-count))))
      (inc! x-count)
      sym))

  (define (gensym-f)
    (let ((f (list-ref field-names f-index)))
      (inc! f-index)
      f))

  ;; label
  (map
    (match-lambda
      (('X . _) (gensym-x))
      ((ty . _) (gensym-f)))
    instruction-args))

(define (map-field-types instruction-args)
  (map
    (match-lambda
      (('V32_X8_L24 . _)
       "VarLen")
      (('B . 1)
       "bool")
      (('ZI . 16)
       "i16")
      ((or ('L . n)
           ('LO . n)) 
       (string-append "i" (number->string n)))
      ((_ . n) 
       (string-append "u" (number->string n))))
    instruction-args))

                                        ; Indentation

(define code-indent-size 4)
(define code-indent (make-parameter 0))

(define (current-code-indent)
  (* (code-indent) code-indent-size))

(define-syntax-rule (indent rest ...)
  (parameterize ((code-indent (1+ (code-indent))))
    rest ...))

                                        ; Zig output types

;; "///asd\na: u8" or "a: u8"
(define* (format-field name type #:optional (doc #f))  ;; (format #f "~@[///~a~%~]~v_~a: ~a" doc (current-code-indent) name type)
  (string-append (if doc (format #f "~v_/// ~a~%" (current-code-indent) doc) "")
                 (format #f "~v_~a: ~a" (current-code-indent) name type)))

(define (format-struct instruction-operands)
  (define a (apply append (map split-operand-word instruction-operands)))

  ;; todo: consider asserting that ~V32_X8_L24~ operand is the last member of the instruction

  (unless (and (eq? (caar a) 'X)
               (>= (cdar a) 8))
    (error "expected 8 bit skip"))

  (set-cdr! (car a) (- (cdar a) 8))

  ;; trim the 8 bit opcode
  (when (<= (cdar a) 0)
    (set! a (cdr a)))

  (format #f "packed struct {~%~a~v_}"
          (indent
           (format #f "~{~a,~%~}"
                   (map format-field
                        (map-field-names a)
                        (map-field-types a)
                        (map car a))))
          (current-code-indent)))

(define (format-op operation)
  (match operation
    ((name id type . operands)
     (indent
      (format-field
       (scheme-name->zig-name (symbol->string name))
       (format-struct operands)
       operation)))))

(define (format-instructions-union instructions)
  (format #f "packed union {~%~a~v_}"
          (format #f "~{~a,~%~^~%~}" (map format-op instructions))
          (current-code-indent)))

(define (format-op-name operation)
  (match operation
    ((name id type . args)
     (string-append (make-string (current-code-indent) #\space)
                    (scheme-name->zig-name (symbol->string name))
                    " = "
                    (number->string id)))))

(define (format-instructions-enum instructions)
  (format #f "enum(u8) {~a~v__,~%~v_}"
          (format #f "~%~{~a,~%~}" (indent (map format-op-name instructions)))
          (indent (current-code-indent))
          (current-code-indent)))


(define (format-toplevel instructions)
  (format #t
          "//! Guile VM Bytecodes
//! extracted via =src/extract-bytecodes.scm=

pub const Directive = ~a;
    
pub fn Operand(comptime VarLen: type) type {
    return ~a;
}
"
          (format-instructions-enum instructions)
          (indent (format-instructions-union instructions))))

                                        ; Main

(format-toplevel (instruction-list))


;; (parameterize ((code-indent 0))
;;   (format-struct '(X8_F24 X8_C24 L32)))

;; (parameterize ((code-indent 1))
;;   (format-field "a" "u8" "doc"))

;;(format-field "call" (format-struct '(X8_F24 X8_C24 L32)) '(call 3 ! X8_F24 X8_C24))

;; (cadddr
;;  (map
;;   (match-lambda
;;     ((name id type . args)
;;      ;; expect the first tag to start with x and take 8 bits if
     
;;      (let ((params (apply append (map get-param-sizes args))))
;;        (set-cdr! (car params) (- (cdr (car params)) 8))
;;        (when (<= (cdr (car params)) 0)
;;          (set! params (cdr params)))
       
;;        (list args params)
;;        )))
;;   (instruction-list)))


