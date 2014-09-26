#lang racket
(require "rtmidi.rkt")

;; Create RtMidiIn and RtMidiOut
(define in (make-rtmidi-in))
(define out (make-rtmidi-out))

;; List input and output ports
(define in-ports (rtmidi-ports in))
(printf "Input ports: ~a~n" in-ports)

(define out-ports (rtmidi-ports out))
(printf "Output ports: ~a~n" out-ports)

;; Open the first input and output port, if any

(unless (empty? in-ports)
  (rtmidi-open-port in 0))

(unless (empty? out-ports)
  (rtmidi-open-port out 0))

;; Send a note
(rtmidi-send-message out (list #b10010000 65 127))
(sleep 0.2)
(rtmidi-send-message out (list #b10000000 65 127))

;; Read incoming messages until break
(let loop ()
  (pretty-print (sync in))
  (loop))