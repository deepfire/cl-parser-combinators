(in-package :parser-combinators-tests)

(defsuite* (basics-tests :in parser-combinators-tests))

(deftest test-parse-string ()
  (let ((parse-result (parse-string (between? #\a nil nil 'string) "aaa")))
    (iter (for should-result in '("aaa" "aa" "a" ""))
          (for is-result = (tree-of (next-result parse-result)))
          (is (string= should-result is-result)))))

(deftest test-parse-string*-complete ()
  (multiple-value-bind (result suffix success front) (parse-string* (between? #\a nil nil 'string) "aaa")
    (is (string= result "aaa"))
    (is (null suffix))
    (is success)
    (is (null front))))

(deftest test-parse-string*-incomplete ()
  (multiple-value-bind (result suffix success front) (parse-string* (between? #\a nil 2 'string) "aaa")
    (is (string= result "aa"))
    (is (= (position-of suffix) 2))
    (is success)
    (is (= (position-of front) 1))))

(deftest test-parse-string*-incomplete2 ()
  (multiple-value-bind (result suffix success front) (parse-string* (breadth? #\a 2 nil 'string) "aaa")
    (is (string= result "aa"))
    (is (= (position-of suffix) 2))
    (is success)
    ;; next character is already consumed by queuing
    (is (= (position-of front) 2))))

(deftest test-parse-string*-complete-arg ()
  (multiple-value-bind (result suffix success front)
      (parse-string* (breadth? #\a 2 nil 'string) "aaa" :complete t)
    (is (string= result "aaa"))
    (is (null suffix))
    (is success)
    ;; next character is already consumed by queuing
    (is (null front))))

(deftest test-parse-string*-complete-first ()
  (multiple-value-bind (result suffix success front)
      (parse-string* (breadth? #\a 2 nil 'string) "aaa" :complete :first)
    (is (null result))
    (is (null suffix))
    (is (null success))
    (is (= (position-of front) 2))))

(deftest test-parse-string*-fail ()
    (multiple-value-bind (result suffix success front)
      (parse-string* #\a "b")
    (is (null result))
    (is (null suffix))
    (is (null success))
    (is (= (position-of front) 0))))

(deftest test-parse-string*-fail-complete ()
    (multiple-value-bind (result suffix success front)
      (parse-string* #\a "ab" :complete t)
    (is (null result))
    (is (null suffix))
    (is (null success))
    (is (= (position-of front) 0))))

(deftest test-parse-string* ()
  (test-parse-string*-complete)
  (test-parse-string*-incomplete)
  (test-parse-string*-incomplete2)
  (test-parse-string*-complete-arg)
  (test-parse-string*-complete-first)
  (test-parse-string*-fail)
  (test-parse-string*-fail-complete))

;; test combinators

(defsuite* combinators-tests)

(deftest test-bind ()
  (is (eql (tree-of (funcall (funcall (mdo #\a #\b) (make-context "ab"))))
           #\b)))

(deftest test-choice ()
  (let ((continuation (funcall (choice (mdo #\a #\b #\a)
                                       (mdo #\a #\b))
                               (make-context "aba"))))
    (is (eql (tree-of (funcall continuation))
             #\a))
    (is (eql (tree-of (funcall continuation))
             #\b))
    (is (null (funcall continuation))))
  (let ((continuation (funcall (choice (mdo #\c #\a #\b #\a)
                                       (mdo #\c #\a #\b))
                               (make-context "aba"))))
    (is (null (funcall continuation)))))

(deftest test-choice1 ()
  (let ((continuation (funcall (choice1 (mdo #\a #\b #\a)
                                        (mdo #\a #\b))
                               (make-context "aba"))))
    (is (eql (tree-of (funcall continuation))
             #\a))
    (is (null (funcall continuation)))))

(deftest test-choices ()
  (let ((continuation (funcall (choices (mdo #\a #\b #\a)
                                       (mdo #\a #\b)
                                       (mdo #\a #\b #\a #\c))
                               (make-context "abac"))))
    (is (eql (tree-of (funcall continuation))
             #\a))
    (is (eql (tree-of (funcall continuation))
             #\b))
    (is (eql (tree-of (funcall continuation))
             #\c))
    (is (null (funcall continuation)))))

(deftest test-choices1 ()
  (let ((continuation (funcall (choices1 (mdo #\a #\b #\a)
                                         (mdo #\c #\a #\b)
                                         (mdo #\c #\a #\b #\a #\c))
                               (make-context "cabac"))))
    (let ((result (funcall continuation)))
      (is (eql (tree-of result)
               #\b))
      (is (= (position-of (suffix-of result))
             3)))
    (is (null (funcall continuation)))))
