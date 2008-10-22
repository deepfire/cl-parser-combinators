(in-package :parser-combinator)

;;; greedy version of repetition combinators

(defun many* (parser)
  (choice1 (mdo (<- x parser)
		(<- xs (many* parser))
		(result (cons x xs)))
	   (result nil)))

(defun many1* (parser)
  (mdo (<- x parser)
       (<- xs (many* parser))
       (result (cons x xs))))

(defun atleast* (parser count)
  (if (zerop count)
      (many* parser)
      (mdo (<- x parser) (<- xs (atleast? parser (1- count))) (result (cons x xs)))))

(defun atmost* (parser count)
  (if (zerop count)
      (result nil)
      (choice1 (mdo (<- x parser) (<- xs (atmost* parser (1- count))) (result (cons x xs))) (result nil))))

(defun between* (parser min max)
  (assert (>= max min))
  (if (zerop min)
      (atmost* parser max)
      (mdo (<- x parser) (<- xs (between* parser (1- min) (1- max))) (result (cons x xs)))))

(defun sepby1* (parser-item parser-separator)
  (mdo (<- x parser-item)
       (<- xs (many* (mdo parser-separator
			  (<- y parser-item)
			  (result y))))
       (result (cons x xs))))

(defun sepby* (parser-item parser-separator)
  (choice1 (sepby1* parser-item parser-separator)
	   (result nil)))

(defun chainl1* (p op)
  (labels ((rest-chain (x)
	     (choice1
	      (mdo (<- f op)
		   (<- y p)
		   (rest-chain (funcall f x y)))
	      (result x))))
    (bind p #'rest-chain)))

(def-cached-parser nat*
  (chainl1* (mdo (<- x (digit?))
		 (result (digit-char-p x)))
	    (result
	     #'(lambda (x y)
		 (+ (* 10 x) y)))))

(def-cached-parser int*
  (mdo (<- f (choice1 (mdo (char? #\-) (result #'-)) (result #'identity)))
       (<- n (nat*))
       (result (funcall f n))))

(defun chainr1* (p op)
  (bind p #'(lambda (x)
	      (choice1
	       (mdo (<- f op)
		    (<- y (chainr1* p op))
		    (result (funcall f x y)))
	       (result x)))))

(defun chainl* (p op v)
  (choice1
   (chainl1* p op)
   (result v)))

(defun chainr* (p op v)
  (choice1
   (chainr1* p op)
   (result v)))
