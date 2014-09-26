.PHONY: clean linux windows macosx
CXXFLAGS += -I./rtmidi-2.1.0 -fPIC -D__RTMIDI_DEBUG__ -g

linux: CXXFLAGS += -D__LINUX_ALSA__
linux: LDFLAGS += -lasound -lpthread
linux: wrap-rtmidi.so

windows: LDFLAGS += -lwinmm
windows: wrap-rtmidi.so

macosx: CXXFLAGS += -D__MACOSX_CORE__
macosx: LDFLAGS += -framework CoreMIDI -framework CoreAudio -framework CoreFoundation
macosx: wrap-rtmidi.dylib

wrap-rtmidi.so: wrap-rtmidi.o rtmidi-2.1.0/RtMidi.o
	$(CXX) $(LDFLAGS) -fPIC -shared -o $@ $^

wrap-rtmidi.dylib: wrap-rtmidi.so
	ln -fs wrap-rtmidi.so wrap-rtmidi.dylib

clean:
	rm -f wrap-rtmidi.so wrap-rtmidi.dylib wrap-rtmidi.o rtmidi-2.1.0/RtMidi.o
