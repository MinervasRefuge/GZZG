;; BSD-3-Clause : Copyright © 2025 Abigale Raeck.

(load-extension "zig-out/lib/libgzzg-hdf5.so" "init_hdf5")

(define-module (hdf5-test)
  #:use-module (ice-9 pretty-print)
  #:use-module (srfi srfi-1)
  #:use-module ((hdf5) #:prefix hdf5:))

(hdf5:hello-world)

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


;; http://hdfeos.org/zoo/index_openLaRC_Examples.php
;; https://gamma.hdfgroup.org/ftp/pub/outgoing/NASAHDF/CATS-ISS_L2O_D-M7.2-V2-01_05kmLay.2017-05-01T00-47-40T01-28-41UTC.hdf5

(call-with-h5-file "CATS-ISS_L2O_D-M7.2-V2-01_05kmLay.2017-05-01T00-47-40T01-28-41UTC.hdf5"
  (λ (file-hndl)
    (call-with-h5-group file-hndl "/"
      (λ (group-hndl)
        (let ((links (hdf5:group-links group-hndl)))
          (pretty-print links)
          (call-with-h5-dataset file-hndl (car (third links))
            (λ (ds-hndl)
              (pretty-print ds-hndl))))))))
