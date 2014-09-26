## racket-rtmidi ##

FFI wrapper for RtMidi ( http://www.music.mcgill.ca/~gary/rtmidi ) in Racket.

To compile, first extract
http://www.music.mcgill.ca/~gary/rtmidi/release/rtmidi-2.1.0.tar.gz to the
repository root. Then run `make $PLATFORM`, where `PLATFORM` is one of `linux`,
`macosx`, or `windows`.

The wrapper is C++98 and should compile with any modern C++ compiler.

I haven't tried the Windows build with this Makefile; you might need to make
some adjustments.

See `rtmidi-example.rkt` to get started. Documentation and Racket package to
come.
