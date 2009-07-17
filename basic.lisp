(in-package :parser-combinators)

;;; operate on list of tokens

(defclass parser-possibility ()
  ((tree :accessor tree-of :initarg :tree :initform nil)
   (suffix :accessor suffix-of :initarg :suffix :initform nil)))


;;; lazy results

;;; continuation is a thunk returning parser-possibility or nil

(defclass parse-result-store ()
  ((storage      :accessor storage-of      :initarg :storage      :initform (make-array 3 :initial-element nil))
   (counter      :accessor counter-of      :initarg :counter :initform 0)
   (continuation :accessor continuation-of :initarg :continuation :initform (constantly nil))))

(defgeneric nth-result (n parse-result-store)
  (:method (n (parse-result-store null))
    (declare (ignore n parse-result-store))
    nil)
  (:method (n (parse-result-store parse-result-store))
    (with-accessors ((storage storage-of)
                     (counter counter-of)
                     (continuation continuation-of))
        parse-result-store
      (if (< n counter)
          (svref storage n)
          (when continuation
            (iter (for i from counter to n)
                  (for next-result = (funcall continuation))
                  (when (= i (length storage))
                    (let ((old-storage storage))
                      (setf storage (make-array (* 2 (length storage)) :initial-element nil))
                      (setf (subseq storage 0 i) old-storage)))
                  (setf (svref storage i) next-result)
                  (unless next-result
                    (setf continuation nil))
                  (while next-result)
                  (finally (setf counter (1+ i))
                           (return next-result))))))))

(defclass parse-result ()
  ((store   :accessor store-of   :initarg :store :initform nil)
   (current :accessor current-of :initarg :current :initform -1)))

(defun make-parse-result (continuation)
  (make-instance 'parse-result :store
                 (make-instance 'parse-result-store :continuation continuation)))

(defun current-result (parse-result)
  (when (= (current-of parse-result) -1)
    (next-result parse-result))
  (nth-result (current-of parse-result) (store-of parse-result)))

(defun next-result (parse-result)
  (incf (current-of parse-result))
  (current-result parse-result))

(defun gather-results (parse-result)
  (let ((current-result (current-result parse-result))
        (continuation-results
         (iter (for result next (next-result parse-result))
               (while result)
               (collect result))))
    (when current-result
      (cons current-result continuation-results))))

(defun copy-parse-result (parse-result)
  (make-instance 'parse-result :store (store-of parse-result)))

;;; here parser spec is list of (pattern optional-guard comprehension)
;;; using do-like notation, <- is special

;;; list of either monads: (monad parameters), name bindings (<- name monad)
;;; simple, no let

(eval-when (:compile-toplevel :load-toplevel :execute)
  (defun do-notation (monad-sequence bind ignore-gensym)
    (match monad-sequence
      ((_monad . nil)
       _monad)
      (((<- _name _monad) . _)
       `(,bind ,_monad
               #'(lambda (,_name)
                   ,(do-notation (cdr monad-sequence) bind ignore-gensym))))
      ((_monad . _)
       `(,bind ,_monad
               #'(lambda (,ignore-gensym)
                   (declare (ignore ,ignore-gensym))
                   ,(do-notation (cdr monad-sequence) bind ignore-gensym)))))))

(defmacro mdo (&body spec)
  "Combinator: use do-like notation to sequentially link parsers. (<- name parser) allows capturing of return values."
  (with-unique-names (ignore-gensym)
    (do-notation spec 'bind ignore-gensym)))

(defmacro def-pattern-parser (name &body parser-patterns)
  (with-unique-names (parameter)
    `(defun ,name (,parameter)
       (match ,parameter
         ,@(iter (for spec in parser-patterns)
                 (collect
                     (match spec
                       ((_pattern (where _guard) . _spec)
                        (list* _pattern (where _guard) _spec))
                       ((_pattern (where-not _guard) . _spec)
                        (list* _pattern (where-not _guard) _spec))
                       ((_pattern . _spec)
                        (list* _pattern _spec))
                       (_ (error "Error when constructing parser ~a" name)))))))))

(def-pattern-parser psat
  (_predicate (mdo (<- x (item)) (if (funcall _predicate x) (result x) (zero)))))

(defparameter *curtail-table* (make-hash-table))
(defparameter *memo-table* (make-hash-table))

(defun parse-string (parser string)
  "Parse a string, return list of possible parse trees. Return remaining suffixes as second value. All returned values may share structure."
  (let ((*memo-table* (make-hash-table))
        (*curtail-table* (make-hash-table)))
    (funcall parser (make-context string))))
