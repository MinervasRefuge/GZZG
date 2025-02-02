;; BSD-3-Clause : Copyright © 2025 Abigale Raeck.

(load-extension "zig-out/lib/libgzzg-hdf5.so" "initHDF5")

(define-module (hdf5-test)
  #:use-module (ice-9 pretty-print)
  #:use-module (srfi srfi-1)
  #:use-module ((hdf5) #:prefix hdf5:))

;; todo: deal with failure
(define (call-with-h5-file file fn1)
  (let ((hndl #f))
    (dynamic-wind
      (λ () (set! hndl (hdf5:open-h5 file '())))
      (λ () (fn1 hndl))
      (λ () (hdf5:close-h5 hndl)))))

(define (call-with-h5-group h5-hndl group fn1)
  (let ((hndl #f))
    (dynamic-wind
      (λ () (set! hndl (hdf5:open-group h5-hndl "/")))
      (λ () (fn1 hndl))
      (λ () (hdf5:close-group hndl)))))

(define (call-with-h5-dataset h5-hndl group fn1)
  (let ((hndl #f))
    (dynamic-wind
      (λ () (set! hndl (hdf5:open-dataset h5-hndl group)))
      (λ () (fn1 hndl))
      (λ () (hdf5:close-dataset hndl)))))

(define (call-with-h5-object h5-hndl path fn1)
  (let ((hndl #f))
    (dynamic-wind
      (λ () (set! hndl (hdf5:open-object h5-hndl path)))
      (λ () (fn1 hndl))
      (λ () (hdf5:close-object hndl)))))

;; http://hdfeos.org/zoo/index_openLaRC_Examples.php
;; https://gamma.hdfgroup.org/ftp/pub/outgoing/NASAHDF/CATS-ISS_L2O_D-M7.2-V2-01_05kmLay.2017-05-01T00-47-40T01-28-41UTC.hdf5

;; (call-with-h5-file "CATS-ISS_L2O_D-M7.2-V2-01_05kmLay.2017-05-01T00-47-40T01-28-41UTC.hdf5"
;;   (λ (file-hndl)
;;     (call-with-h5-group file-hndl "/"
;;       (λ (group-hndl)
;;         (let ((links (hdf5:group-links group-hndl)))
;;           (pretty-print links)
;;           (call-with-h5-dataset file-hndl (car (third links))
;;             (λ (ds-hndl)
;;               (let ((ds-type-hndl (hdf5:get-type ds-hndl)))
;;                 (pretty-print (hdf5:get-type-class ds-type-hndl))
;;                 (hdf5:close-type ds-type-hndl))
;;               (let ((space-hndl (hdf5:get-dataset-dataspace ds-hndl)))
;;                 (display "space: ")
;;                 (display space-hndl)
;;                 (newline)
;;                 (hdf5:close-dataspace space-hndl))
;;               (pretty-print ds-hndl)
;;               (let ((prop-hndl (hdf5:get-dataset-plist ds-hndl)))
;;                 (pretty-print (hdf5:get-properties prop-hndl))
;;                 (hdf5:close-plist prop-hndl))
;;               (hdf5:read-dataset ds-hndl))))))))


;;todo check the type of each path
;; (call-with-h5-file "CATS-ISS_L2O_D-M7.2-V2-01_05kmLay.2017-05-01T00-47-40T01-28-41UTC.hdf5"
;;   (λ (file-hndl)
;;     (let ((paths (call-with-h5-group file-hndl "/" hdf5:group-links)))
;;       (pretty-print (map (λ (g) (cons (car g) 
;;                                       (call-with-h5-dataset file-hndl (car g) 
;;                                         (λ (group-hndl) 
;;                                           (let* ((type-hndl (hdf5:get-type group-hndl))
;;                                                  (ntype (hdf5:get-type-class type-hndl)))
;;                                             (hdf5:close-type type-hndl)
;;                                             ntype)))))
;;                          paths)))))

(call-with-h5-file "CATS-ISS_L2O_D-M7.2-V2-01_05kmLay.2017-05-01T00-47-40T01-28-41UTC.hdf5"
                   (λ (file-hndl)
                     (let ((paths (call-with-h5-group file-hndl "/" hdf5:group-links)))
                       (pretty-print (map (λ (g) (call-with-h5-dataset file-hndl (car g)
                                                                       (λ (ds-hndl)
                                                                         (let* ((type-hndl (hdf5:get-type ds-hndl))
                                                                                (ntype (hdf5:get-type-class type-hndl)))
                                                                           (hdf5:close-type type-hndl)
                                                                           (cons (car g) ntype)))))
                                      (filter (λ (g) (eq? 'DATASET (call-with-h5-object file-hndl (car g) hdf5:i-get-type)) )
                                              paths))))))
