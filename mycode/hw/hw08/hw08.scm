(define (ascending? s) 
    (cond ((null? s) #t)
          ((null? (cdr s)) #t)
          (else (and (<= (car s) (car (cdr s))) (ascending? (cdr s)) )   )
    
    )

)

(define (my-filter pred s)
    (cond ((null? s) s)
          ((pred (car s)) (append (list (car s)) (my-filter pred (cdr s))))
          (else (my-filter pred (cdr s)))
    )
)

(define (interleave lst1 lst2)
    (cond ((null? lst1) lst2)
          ((null? lst2) lst1)
          (else (append (list (car lst1) (car lst2)) (interleave (cdr lst1) (cdr lst2))
                )
          )
    )
)

(define (no-repeats s)
    (if (null? s) s
        (cons (car s) (no-repeats (filter (lambda (x) (not (= x (car s)))) (cdr s))
                      )
        )
    )
)
