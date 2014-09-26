#lang racket/base
(provide make-rtmidi-in
         make-rtmidi-out
         rtmidi-ports
         rtmidi-open-port
         rtmidi-close-port
         rtmidi-send-message)

(require ffi/unsafe
         ffi/unsafe/define
         ffi/unsafe/custodian
         racket/async-channel
         racket/pretty
         (rename-in racket/contract [-> ->/c]))

(define-ffi-definer define-rtmidi (ffi-lib "wrap-rtmidi"))

(define _rtmidi_in-pointer  (_cpointer 'rtmidi_in))
(define _rtmidi_out-pointer (_cpointer 'rtmidi_out))

(define rtmidi-event-receive-thread
  (thread
   (lambda()
     (let loop ()
       (sync (thread-receive-evt))
       ((thread-receive))
       (loop)))))

(define (transfer-to-event-thread thunk)
  (thread-send rtmidi-event-receive-thread thunk #f))

(define wrap-error-proc
  (lambda(proc)
    (lambda(type sz str)
      (proc type
            (bytes->string/utf-8
             (make-sized-byte-string str sz))))))

(define event-callback-box (make-parameter #f))
(define error-callback-box (make-parameter #f))

(define-rtmidi
  wrap_rtmidi_new_in
  (_fun (_cprocedure (list _double _size _pointer) _void
                     #:wrapper
                     (lambda(proc)
                       (lambda(del sz str)
                         (begin0
                           (proc del
                                 (bytes-copy (make-sized-byte-string str sz))))
                         (free str)))
                     #:async-apply
                     transfer-to-event-thread
                     #:keep
                     (lambda(c) (set-box! (event-callback-box) c)))
        (_cprocedure (list _int _size _pointer) _void
                     #:wrapper wrap-error-proc
                     #:async-apply transfer-to-event-thread
                     #:keep (lambda(c) (set-box! (error-callback-box) c)))
        -> _rtmidi_in-pointer))

(define-rtmidi
  wrap_rtmidi_delete_in
  (_fun _rtmidi_in-pointer -> _void))

(define-rtmidi
  wrap_rtmidi_new_out
  (_fun (_cprocedure (list _int _size _pointer) _void
                     #:wrapper wrap-error-proc
                     #:async-apply transfer-to-event-thread
                     #:keep (lambda(c) (set-box! (error-callback-box) c)))
        -> _rtmidi_out-pointer))

(define-rtmidi
  wrap_rtmidi_delete_out
  (_fun _rtmidi_out-pointer -> _void))

(define-rtmidi
  wrap_rtmidi_in_get_port_count
  (_fun _rtmidi_in-pointer -> _uint))

(define-rtmidi
  wrap_rtmidi_in_get_port_name
  (_fun _rtmidi_in-pointer _uint
        (sz : (_ptr o _size))
        (o  : (_ptr o _pointer))
        -> _void
        -> (begin0
             (bytes->string/utf-8 (make-sized-byte-string o sz))
             (free o))))

(define-rtmidi
  wrap_rtmidi_out_get_port_count
  (_fun _rtmidi_out-pointer -> _uint))

(define-rtmidi
  wrap_rtmidi_out_get_port_name
  (_fun _rtmidi_out-pointer _uint
        (sz : (_ptr o _size))
        (o  : (_ptr o _pointer))
        -> _void
        -> (begin0
             (bytes->string/utf-8 (make-sized-byte-string o sz))
             (free o))))

(define-rtmidi
  wrap_rtmidi_in_open_port
  (_fun _rtmidi_in-pointer _uint _int -> _void))

(define-rtmidi
  wrap_rtmidi_in_close_port
  (_fun _rtmidi_in-pointer -> _void))

(define-rtmidi
  wrap_rtmidi_out_open_port
  (_fun _rtmidi_out-pointer _uint _int -> _void))

(define-rtmidi
  wrap_rtmidi_out_close_port
  (_fun _rtmidi_out-pointer -> _void))

(define-rtmidi
  wrap_rtmidi_out_send_message
  (_fun _rtmidi_out-pointer
        [_size = (bytes-length msg)]
        [msg : _bytes]
        -> _void))

(struct rtmidi-in (ctx chan event-callback-box error-callback-box closed?-box)
  #:property prop:evt (struct-field-index chan))

(struct rtmidi-out (ctx error-callback-box closed?-box))

(define (make-rtmidi-in)
  (define event-chan (make-async-channel))
  (define event-box (box #f))
  (define error-box (box #f))
  (define closed?-box (box #f))
  (define ctx
    (parameterize
        ([event-callback-box event-box]
         [error-callback-box error-box])
      (wrap_rtmidi_new_in
       (lambda(del msg) (async-channel-put event-chan (cons del (bytes->list msg))))
       (lambda(type str)
         (fprintf (current-error-port) "RtMidiIn error (type ~a): ~a~n" type str)))))
  (define in
    (rtmidi-in ctx event-chan event-box error-box closed?-box))
  (define shutdown
   (lambda _
     (when (box-cas! closed?-box #f #t)
       (wrap_rtmidi_delete_in ctx))))
  (register-finalizer in shutdown)
  (register-custodian-shutdown (void) shutdown #:at-exit? #t)
  in)

(define (make-rtmidi-out)
  (define error-box (box #f))
  (define closed?-box (box #f))
  (define ctx
    (parameterize
        ([error-callback-box error-box])
      (wrap_rtmidi_new_out
       (lambda(type str)
         (fprintf (current-error-port) "RtMidiOut error (type ~a): ~a~n" type str)))))
  (define out
    (rtmidi-out ctx error-box closed?-box))
  (define shutdown
   (lambda _
     (when (box-cas! closed?-box #f #t)
       (wrap_rtmidi_delete_out ctx))))
  (register-finalizer out shutdown)
  (register-custodian-shutdown (void) shutdown #:at-exit? #t)
  out)

(define rtmidi/c (or/c rtmidi-in? rtmidi-out?))

(define/contract (rtmidi-ports rtmidi)
  (->/c rtmidi/c (listof string?))
  (define-values (count get-name ctx)
    (cond
      [(rtmidi-in? rtmidi)
       (values wrap_rtmidi_in_get_port_count
               wrap_rtmidi_in_get_port_name
               (rtmidi-in-ctx rtmidi))]
      [(rtmidi-out? rtmidi)
       (values wrap_rtmidi_out_get_port_count
               wrap_rtmidi_out_get_port_name
               (rtmidi-out-ctx rtmidi))]))
  (for/list ([i (in-range 0 (count ctx))])
    (get-name ctx i)))

(define/contract (rtmidi-open-port rtmidi port)
  (->/c rtmidi/c (or/c exact-nonnegative-integer? #f) void?)
  (define-values (open ctx)
    (cond
      [(rtmidi-in? rtmidi)
       (values wrap_rtmidi_in_open_port
               (rtmidi-in-ctx rtmidi))]
      [(rtmidi-out? rtmidi)
       (values wrap_rtmidi_out_open_port
               (rtmidi-out-ctx rtmidi))]))
  (open ctx (if port port 0) (if port 0 1)))

(define/contract (rtmidi-close-port rtmidi)
  (->/c rtmidi/c void?)
  (cond
    [(rtmidi-in? rtmidi)
     (wrap_rtmidi_in_close_port (rtmidi-in-ctx rtmidi))]
    [(rtmidi-out? rtmidi)
     (wrap_rtmidi_out_close_port (rtmidi-out-ctx rtmidi))]))

(define/contract (rtmidi-send-message rtmidi msg)
  (->/c rtmidi-out? (listof byte?) void?)
  (wrap_rtmidi_out_send_message
   (rtmidi-out-ctx rtmidi)
   (list->bytes msg)))
