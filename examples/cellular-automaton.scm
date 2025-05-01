;; cellular-automaton.scm : Example of Guile Foreign Types using GZZG
;; with the example of Cellular Automaton.
;; Copyright (C) 2025  Abigale Raeck
;;
;; This program is free software: you can redistribute it and/or modify
;; it under the terms of the GNU General Public License as published by
;; the Free Software Foundation, either version 3 of the License, or
;; (at your option) any later version.
;;
;; This program is distributed in the hope that it will be useful,
;; but WITHOUT ANY WARRANTY; without even the implied warranty of
;; MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
;; GNU General Public License for more details.
;;
;; You should have received a copy of the GNU General Public License
;; along with this program.  If not, see <https://www.gnu.org/licenses/>.


;; run this program via `zig build run-example-cellular-automaton`

(use-modules
 (srfi srfi-1)
 (ice-9 pretty-print)
 (rnrs bytevectors))

(load-extension (second (program-arguments))  "initPlugin")

(use-modules
 ((cellular-automaton) #:prefix ca:))

;; handy terminal codes
(define cursor-show "\x1B[?25h")
(define cursor-hide "\x1B[?25l")
(define clear "\x1B[2J") 
(define seek-home "\x1B[H")

                                        ; cellular automaton
(define automaton (ca:make-iterator 'wire-world (ca:make-map 22 11)))

(ca:iterator-world!
 automaton
 '("                     "
   "  ***tE              "
   " *     ****          "
   "  *****    *         "
   "          ****       "
   "          *  ******* "
   "          ****       "
   "  ***tE    *         "
   " *     ****          "
   "  Et***              "
   "                     "))

(dynamic-wind
  (λ () 
    (display cursor-hide)
    (display clear))
  (λ ()
    (let lp ((v 100))
      (display seek-home)
      (ca:iterator-next automaton)
      (ca:iterator-print automaton)
      (usleep 80000)
      (when (>= v 1)
        (lp (1- v)))))
  (λ ()
    (display cursor-show)
    (newline)))
