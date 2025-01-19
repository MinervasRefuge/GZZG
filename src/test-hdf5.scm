;; BSD-3-Clause : Copyright © 2025 Abigale Raeck.

(load-extension "zig-out/lib/libguile-hdf5.so" "init_hdf5")

(define-module (hdf5-test)
  #:use-module (ice-9 pretty-print)
  #:use-module ((hdf5) #:prefix hdf5:))

(hdf5:hello-world)


;; http://hdfeos.org/zoo/index_openLaRC_Examples.php
;; https://gamma.hdfgroup.org/ftp/pub/outgoing/NASAHDF/CATS-ISS_L2O_D-M7.2-V2-01_05kmLay.2017-05-01T00-47-40T01-28-41UTC.hdf5
(define hndl-h5
  (hdf5:open-h5 "CATS-ISS_L2O_D-M7.2-V2-01_05kmLay.2017-05-01T00-47-40T01-28-41UTC.hdf5" '()))
(display hndl-h5)
(newline)

(define hndl-group (hdf5:open-h5-group hndl-h5 "/"))
(display hndl-group)
(newline)

(define ginfo (hdf5:h5-group-info hndl-group))
(display ginfo)
(newline)
(display (hdf5:h5-group-info->string ginfo))
(newline)

(display  (length (map (λ (a) (if (string? a) a (cons (car a) (hdf5:link-info2->string (cdr a)))))
                       (hdf5:h5-group-links hndl-group))))
(newline)

;;(pretty-print (link-info2->string))

;;(close-h5-group hndl-group)

(hdf5:close-h5 hndl-h5)


