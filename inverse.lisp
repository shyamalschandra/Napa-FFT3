(defvar *inv-base-case* 8)

(defun gen-base-dits (&key window)
  (list `(dit/1 (start ,@(and window '(window-start)))
          (declare (ignorable start
                              ,@(and window '(window-start))))
          ,(and window
                `(setf (aref vec start)
                       (* (aref vec start)
                          (aref ,window window-start))))
          nil)
        `(dit/2 (start ,@(and window '(window-start)))
          (declare (type index start
                         ,@(and window '(window-start))))
          (macrolet ((src (i)
                       `(%window (aref vec (+ start ,i))
                                 ,',window
                                 ,,(if window ``(+ window-start ,i) 0)))
                     (dst (i)
                       `(aref vec (+ start ,i))))
            (let ((s0 (src 0))
                  (s1 (src 1)))
              (setf (dst 0) (+ s0 s1)
                    (dst 1) (- s0 s1))))
          nil)
        `(dit/4 (start ,@(and window '(window-start)))
          (declare (type index start
                         ,@(and window '(window-start))))
          (macrolet ((src (i)
                       `(%window (aref vec (+ start ,i))
                                 ,',window
                                 ,,(if window ``(+ window-start ,i) 0)))
                     (dst (i)
                       `(aref vec (+ start ,i))))
            (let* ((s0 (src 0))
                   (s1 (src 1))
                   (d0+2 (+ s0 s1))
                   (d1+3 (- s0 s1))
                   (s2 (src 2))
                   (s3 (src 3))
                   (d0-2 (+ s2 s3))
                   (d1-3 (mul-i (- s3 s2))))
              (setf (dst 0) (+ d0+2 d0-2)
                    (dst 1) (+ d1+3 d1-3)
                    (dst 2) (- d0+2 d0-2)
                    (dst 3) (- d1+3 d1-3))))
          nil)
        ;; why don't I just generate from split radix again?
        `(dit/8 (start ,@(and window '(window-start)))
          (declare (type index start
                         ,@(and window '(window-start))))
          (macrolet ((src (i)
                       `(%window (aref vec (+ start ,i))
                                 ,',window
                                 ,,(if window ``(+ window-start ,i) 0)))
                     (dst (i)
                       `(aref vec (+ start ,i))))
            (let* ((s0 (src 0))
                   (s1 (src 1))
                   (d0+4+2+6 (+ s0 s1))
                   (d1+5+3+7 (- s0 s1))

                   (s2 (src 2))
                   (s3 (src 3))
                   (d0+4-2-6 (+ s2 s3))
                   (d1+5-3-7 ,(mul-root `(- s2 s3)
                                        2/8))
                   (d0+4 (+ d0+4+2+6 d0+4-2-6))
                   (d2+6 (- d0+4+2+6 d0+4-2-6))
                   (d1+5 (+ d1+5+3+7 d1+5-3-7))
                   (d3+7 (- d1+5+3+7 d1+5-3-7))

                   (s4 (src 4))
                   (s5 (src 5))
                   (d0-4+[-1/4]2-[-1/4]6 (+ s4 s5))
                   (d1-5+[-1/4]3-[-1/4]7 ,(mul-root `(- s4 s5)
                                                    1/8))
                   
                   (s6 (src 6))
                   (s7 (src 7))
                   (d0-4-[-1/4]2+[-1/4]6 (+ s6 s7))
                   (d1-5-[-1/4]3+[-1/4]7 ,(mul-root `(- s6 s7)
                                                    3/8))
                   (d0-4 (+ d0-4+[-1/4]2-[-1/4]6
                            d0-4-[-1/4]2+[-1/4]6))
                   (d2-6 ,(mul-root `(- d0-4+[-1/4]2-[-1/4]6
                                        d0-4-[-1/4]2+[-1/4]6)
                                    2/8))
                   (d1-5 (+ d1-5+[-1/4]3-[-1/4]7
                            d1-5-[-1/4]3+[-1/4]7))
                   (d3-7 ,(mul-root `(- d1-5+[-1/4]3-[-1/4]7
                                        d1-5-[-1/4]3+[-1/4]7)
                                    1/4)))
              (setf (dst 0) (+ d0+4 d0-4)
                    (dst 1) (+ d1+5 d1-5)
                    (dst 2) (+ d2+6 d2-6)
                    (dst 3) (+ d3+7 d3-7)
                    (dst 4) (- d0+4 d0-4)
                    (dst 5) (- d1+5 d1-5)
                    (dst 6) (- d2+6 d2-6)
                    (dst 7) (- d3+7 d3-7))))
          nil)))

(defun gen-dit (n &key (scale 1d0) window)
  (let ((defs '())
        (base-defs (gen-base-dits :window window))
        (last n))
    (labels ((name (n)
               (intern (format nil "~A/~A" 'dit n)))
             (gen (n)
               (cond
                 ((= n 16)
                  (gen 8)
                  (push
                   `(dit/16 (start ,@(and window '(window-start)))
                     (declare (type index start
                                    ,@(and window '(window-start))))
                     (dit/4 (+ start ,(+ 8 4))
                            ,@(and window
                                   `((+ window-start ,(+ 8 4)))))
                     (dit/4 (+ start 8)
                            ,@(and window
                                   `((+ window-start 8))))
                     ,@(loop
                         for i below 4
                         collect
                         `(let ((x ,(mul-root
                                     `(aref vec (+ start ,(+ i 8)))
                                     (* 1/16 i)
                                     `(aref twiddle ,(+ 8 +twiddle-offset+
                                                        (* 2 i)))))
                                (y ,(mul-root
                                     `(aref vec (+ start ,(+ i 8 4)))
                                     (* 3/16 i)
                                     `(aref twiddle ,(+ 8 +twiddle-offset+
                                                        1
                                                        (* 2 i))))))
                            (setf (aref vec (+ start ,(+ i 8)))
                                  (+ x y)
                                  (aref vec (+ start ,(+ i 8 4)))
                                  (mul+i (- x y)))))
                     (dit/8 start
                            ,@(and window '(window-start)))
                     (for (8 (i start)
                             ,@(and (= n last)
                                    window
                                    `((k window-start))))
                       (let ((x ,(if (= n last)
                                     `(%scale (aref vec i) ,scale)
                                     `(aref vec i)))
                             (y ,(if (= n last)
                                     `(%scale (aref vec (+ i 8)) ,scale)
                                     `(aref vec (+ i 8)))))
                         (setf (aref vec i) (+ x y)
                               (aref vec (+ i 8)) (- x y)))))
                   defs))
                 ((> n *inv-base-case*)
                  (gen (truncate n 2))
                  (let* ((n/2 (truncate n 2))
                         (n/4 (truncate n 4))
                         (name/2 (name n/2))
                         (name/4 (name n/4))
                         (body
                           `(,(name n) (start ,@(and window
                                                     '(window-start)))
                             (declare (type index start
                                            ,@(and window
                                                   '(window-start))))
                             (,name/4 (+ start ,n/2)
                                      ,@(and window
                                             `((+ window-start ,n/2))))
                             (,name/4 (+ start ,(+ n/2 n/4))
                                      ,@(and window
                                             `((+ window-start
                                                  ,(+ n/2 n/4)))))
                             (for (,n/4 (i start)
                                        (k ,(+ n/2 +twiddle-offset+) 2))
                               (let* ((t1 (aref twiddle k))
                                      (t2 (aref twiddle (1+ k)))
                                      (x  (* t1 (aref vec (+ i ,n/2))))
                                      (y  (* t2 (aref vec (+ i ,(+ n/2 n/4))))))
                                 (setf (aref vec (+ i ,n/2))
                                       (+ x y)
                                       (aref vec (+ i ,(+ n/2 n/4)))
                                       (mul+i (- x y)))))
                             (,name/2 start
                                      ,@(and window '(window-start)))
                             (for (,n/2 (i start)
                                        ,@(and (= n last)
                                               window
                                               `((k window-start))))
                               (let ((x ,(if (= n last)
                                             `(%scale (aref vec i) ,scale)
                                             `(aref vec i)))
                                     (y ,(if (= n last)
                                             `(%scale (aref vec (+ i ,n/2))
                                                               ,scale)
                                             `(aref vec (+ i ,n/2)))))
                                 (setf (aref vec          i) (+ x y)
                                       (aref vec (+ i ,n/2)) (- x y)))))))
                    (push body defs))))))
      (gen n)
      `(labels (,@base-defs ,@(nreverse defs))
         (declare (ignorable ,@(mapcar (lambda (x) `#',(car x))
                                       base-defs))
                  (inline ,@(mapcar #'car base-defs)
                          ,(name n)))
         ,(and (<= n *fwd-base-case*)
               (not (eql scale 1d0))
               `(for (,n (i start))
                  (setf (aref vec i) (%scale
                                      (aref vec i)
                                      ,scale))))
         (,(name n) start
          ,@(and window '(window-start)))))))

(defun %dit (vec start n twiddle)
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
                      (rec start3 n/4)
                      (rec start2 n/4)
                      (for (n/4 (i start2)
                                (j start3)
                                (k (+ n/2 +twiddle-offset+) 2))
                           (let* ((t1 (aref twiddle k))
                                  (t2 (aref twiddle (1+ k)))
                                  (x  (* (aref vec i) t1))
                                  (y  (* (aref vec j) t2)))
                             (setf (aref vec i) (+ x y)
                                   (aref vec j) (mul+i (- x y)))))
                      (rec start n/2)
                      (for (n/2 (i start)
                                (j start2))
                           (let ((x (aref vec i))
                                 (y (aref vec j)))
                             (setf (aref vec i) (+ x y)
                                   (aref vec j) (- x y))))))
                   ((= n 2)
                    (let ((s0 (aref vec start))
                          (s1 (aref vec (1+ start))))
                      (setf (aref vec start)      (+ s0 s1)
                            (aref vec (1+ start)) (- s0 s1)))
                    nil))))
    (rec start n)
    vec))
