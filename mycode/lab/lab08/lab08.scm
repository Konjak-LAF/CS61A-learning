(define (over-or-under num1 num2) 
  (cond ((< num1 num2) (- 1))
        ((> num1 num2) 1)
        (else 0)
  )
)

(define (composed f g)
  (begin
  (define (h x)
    (f (g x))
  )
  h
  )
)

(define (repeat f n)
  (if (= n 1) f (composed f (repeat f (- n 1))))
)

(define (max a b)
  (if (> a b)
      a
      b))

(define (min a b)
  (if (> a b)
      b
      a))

(define (gcd a b)
  (if (= b 0) a (gcd b (modulo a b)))
)

(define (exp b n)
  (define (helper n so-far)
    (if (= n 0) so-far (helper (- n 1) (* so-far b)))
  )
  (helper n 1))

(define (swap s) 
  (define (helper now rest)
    (cond ((null? rest) now)
          ((null? (cdr rest)) (append now (list (car rest))))
          (else (helper (append now (list (car (cdr rest)) (car rest)) )
                        (cdr (cdr rest)) 
                )
          )
    )
  )
  (helper () s)
)

(define (make-adder num)
  (begin
  (define (adder inc)
  (+ num inc)
  )
  adder)
)
