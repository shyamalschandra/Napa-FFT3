(defvar *fwd-base-case* 32)

(defun gen-flat-dif (n &key (scale 1d0) window)
  (with-vector (n :maxlive 13)
    (let ((last n))
      (labels ((scale (i)
                 (setf (@ i)
                       (op (complex-sample)
                           `(lambda (x)
                              (%window (%scale x ,scale)
                                       ,window
                                       ,i))
                           (@ i))))
               (rec (start n)
                 (cond
                   ((= n 2)
                    (when (and (= n last)
                               (or (not (eql scale 1d0))
                                   window))
                      (scale start)
                      (scale (1+ start)))
                    (butterfly start (1+ start)))
                   ((>= n 4)
                    (let* ((n/2    (truncate n 2))
                           (start2 (+ start n/2))
                           (n/4    (truncate n/2 2))
                           (start3 (+ start2 n/4)))
                      (dotimes (i n/2)
                        (when (= last n)
                          (scale (+ i start))
                          (scale (+ i start2)))
                        (butterfly (+ i start)
                                   (+ i start2)))
                      (rec start n/2)
                      (dotimes (count n/4)
                        (let ((i (+ count start2))
                              (j (+ count start3))
                              (k (+ n/2 +twiddle-offset+
                                    (* 2 count))))
                          (rotate j nil 3/4)
                          (butterfly i j)
                          (rotate i k      (/ (* -1 count) n))
                          (rotate j (1+ k) (/ (* -3 count) n))))
                      (rec start2 n/4)
                      (rec start3 n/4))))))
        (rec 0 n)))))

(defun gen-dif (n &key (scale 1d0) window)
  (let ((defs '())
        (last n))
    (labels ((name (n)
               (intern (format nil "~A/~A" 'dif n)))
             (gen (n &aux (name (name n)))
               (when (member name defs :key #'first)
                 (return-from gen name))
               (cond
                 ((<= n *fwd-base-case*)
                  (push
                   `(,(name n) (start)
                     (declare (type index start)
                              (ignorable start))
                     ,(if (= n last)
                          (gen-flat-dif n :scale scale :window window)
                          (gen-flat-dif n)))
                   defs))
                 ((> n *fwd-base-case*)
                  (gen (truncate n 4))
                  (gen (truncate n 2))
                  (let* ((n/2 (truncate n 2))
                         (n/4 (truncate n 4))
                         (name/2 (name n/2))
                         (name/4 (name n/4))
                         (body
                           `(,(name n) (start)
                             (declare (type index start))
                             (for (,n/2 (i start)
                                        ,@(and (= n last)
                                               window
                                               `((k window-start))))
                               (let ((x ,(if (= n last)
                                             `(%window (%scale (aref vec i) ,scale)
                                                       ,window
                                                       ,(if window 'k 0))
                                             `(aref vec i)))
                                     (y ,(if (= n last)
                                             `(%window (%scale (aref vec (+ i ,n/2))
                                                               ,scale)
                                                       ,window
                                                       ,(if window `(+ k ,n/2) 0))
                                             `(aref vec (+ i ,n/2)))))
                                 (setf (aref vec          i) (+ x y)
                                       (aref vec (+ i ,n/2)) (- x y))))
                             (,name/2 start)
                             (for (,n/4 (i start)
                                        (k ,(+ n/2 +twiddle-offset+) 2))
                               (let ((x  (aref vec (+ i ,n/2)))
                                     (y  (mul-i (aref vec (+ i ,(+ n/2 n/4)))))
                                     (t1 (aref twiddle k))
                                     (t2 (aref twiddle (1+ k))))
                                 (setf (aref vec (+ i ,n/2))
                                       (* t1 (+ x y))
                                       (aref vec (+ i ,(+ n/2 n/4)))
                                       (* t2 (- x y)))))
                             (,name/4 (+ start ,n/2))
                             (,name/4 (+ start ,(+ n/2 n/4))))))
                    (push body defs))))))
      (gen n)
      `(labels (,@(nreverse defs))
         (declare (inline ,(name n)))
         (,(name n) start)))))

(defun %dif (vec start n twiddle)
  (declare (type complex-sample-array vec twiddle)
           (type index start)
           (type size n))
  (labels ((rec (start n)
             (declare (type index start)
                      (type size n))
             (cond ((>= n 4)
                    (let* ((n/2    (truncate n 2))
                           (start2 (+ start n/2))
                           (n/4    (truncate n/2 2))
                           (start3 (+ start2 n/4)))
                      (for (n/2 (i start)
                                (j start2))
                        (let ((x (aref vec i))
                              (y (aref vec j)))
                          (setf (aref vec i) (+ x y)
                                (aref vec j) (- x y))))
                      (rec start n/2)
                      (for (n/4 (i start2)
                                (j start3)
                                (k (+ n/2 +twiddle-offset+) 2))
                        (let ((x (aref vec i))
                              (y (mul-i (aref vec j)))
                              (t1 (aref twiddle k))
                              (t2 (aref twiddle (1+ k))))
                          (setf (aref vec i) (* t1 (+ x y))
                                (aref vec j) (* t2 (- x y)))))
                      (rec start2 n/4)
                      (rec start3 n/4)))
                   ((= n 2)
                    (let ((s0 (aref vec start))
                          (s1 (aref vec (1+ start))))
                      (setf (aref vec start) (+ s0 s1)
                            (aref vec (1+ start)) (- s0 s1)))
                    nil))))
    (rec start n)
    vec))
