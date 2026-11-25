(define (caar x) (car (car x)))
(define (cadr x) (car (cdr x)))
(define (cadar x) (car (cdr (car x))))
(define (cdar x) (cdr (car x)))
(define (cddr x) (cdr (cdr x)))

;; Problem 14
;; Returns a list of two-element lists
(define (enumerate s)
  ; BEGIN PROBLEM 14
  (define (helper s i)
    (if (null? s) s
      (cons (list i (car s)) (helper (cdr s) (+ i 1))
      )
    )
  )
  (helper s 0)
  ; END PROBLEM 14
)


;; Problem 15

;; Return the value for a key in a dictionary list
(define (get dict key)
  ; BEGIN PROBLEM 15
  (define (helper s)
    (if (null? s) #f
      (if (eq? key (caar s)) (cadar s)
        (helper (cdr s))
      )
    )
  )
  (helper dict)
  ; END PROBLEM 15
)

;; Return a dictionary list with a (key value) pair
(define (set dict key val)
  ; BEGIN PROBLEM 15
  (define (helper s)
    (if (null? s) (list (list key val))
      (if (eq? key (caar s)) (cons (list key val) (cdr s))
        (cons (car s) (helper (cdr s)))
      )
    )
  )
  (helper dict)
  ; END PROBLEM 15
  )

;; Problem 16

;; implement solution-code
(define (solution-code problem solution)
  ; BEGIN PROBLEM 16
  (define (helper s)
    ; (print s)
    (if (or (null? s) (not (list? s))) s
      (if (list? (car s)) (cons (helper (car s)) (helper (cdr s)))
        (if (eq? (car s) '_____ ) (cons solution (helper (cdr s)))
          (cons (car s) (helper (cdr s)))
        )
      )
    )
  )
  (helper problem)
  ; END PROBLEM 16
  )
