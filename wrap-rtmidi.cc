#include "RtMidi.h"
#include <cstring>
#include <cstdlib>
#include <string>
#include <vector>

typedef void (*wrap_racket_midi_callback_t)(double, size_t, unsigned char*);
typedef void (*wrap_racket_error_callback_t)(int, size_t, const char *);

struct wrap_rtmidi_in {
    RtMidiIn * in;
    wrap_racket_midi_callback_t send_midi;
    wrap_racket_error_callback_t send_error;
};

struct wrap_rtmidi_out {
    RtMidiOut * out;
    wrap_racket_error_callback_t send_error;
};

#define WITH_RACKET_HANDLER(send_error, expr)\
    try {\
        expr ;\
    } catch(RtMidiError & err) {\
        std::string what = err.getMessage();\
        (send_error)(err.getType(), what.length(), what.c_str());\
    }

extern "C" {
    void wrap_rtmidi_midi_callback
    (double deltatime, std::vector<unsigned char> * message, void * w)
    {
        size_t sz = message->size();
        unsigned char * buffer = (unsigned char*)malloc(sz);
        memcpy(buffer, &(*message)[0], sz);
        ((wrap_rtmidi_in*)w)->send_midi(deltatime, sz, buffer);
    }

    wrap_rtmidi_in * wrap_rtmidi_new_in
    (wrap_racket_midi_callback_t send_midi,
     wrap_racket_error_callback_t send_error)
    {
        wrap_rtmidi_in * w = new wrap_rtmidi_in();
        w->in = NULL;
        WITH_RACKET_HANDLER(send_error, w->in = new RtMidiIn());
        w->send_midi = send_midi;
        w->send_error = send_error;
        return w;
    }

    void wrap_rtmidi_delete_in(wrap_rtmidi_in * w)
    {
        if(w->in) {
            delete w->in;
        }
        delete w;
    }

    wrap_rtmidi_out * wrap_rtmidi_new_out
    (wrap_racket_error_callback_t send_error)
    {
        wrap_rtmidi_out * w = new wrap_rtmidi_out();
        w->out = NULL;
        WITH_RACKET_HANDLER(send_error, w->out = new RtMidiOut());
        w->send_error = send_error;
        return w;
    }

    void wrap_rtmidi_delete_out(wrap_rtmidi_out * w)
    {
        if(w->out) {
            delete w->out;
        }
        delete w;
    }

    unsigned int wrap_rtmidi_in_get_port_count(wrap_rtmidi_in * w)
    {
        if(!w->in) {
            return 0;
        }
        unsigned int res = 0;
        WITH_RACKET_HANDLER(w->send_error, res = w->in->getPortCount());
        return res;
    }

    void wrap_rtmidi_in_get_port_name
    (wrap_rtmidi_in * w, unsigned int port_index,
     size_t * length_out, char ** string_out)
    {
        std::string port_name;
        *length_out = 0;
        *string_out = NULL;
        if(!w->in) {
            return;
        }
        WITH_RACKET_HANDLER(w->send_error, port_name = w->in->getPortName(port_index));
        *length_out = port_name.length();
        *string_out = (char*)malloc(sizeof(char) **length_out);
        memcpy(*string_out, port_name.c_str(), sizeof(char) **length_out);
    }

    unsigned int wrap_rtmidi_out_get_port_count(wrap_rtmidi_out * w)
    {
        if(!w->out) {
            return 0;
        }
        unsigned int res = 0;
        WITH_RACKET_HANDLER(w->send_error, res = w->out->getPortCount());
        return res;
    }

    void wrap_rtmidi_out_get_port_name
    (wrap_rtmidi_out * w, unsigned int port_index,
     size_t * length_out, char ** string_out)
    {
        std::string port_name;
        *length_out = 0;
        *string_out = NULL;
        if(!w->out) {
            return;
        }
        WITH_RACKET_HANDLER(w->send_error, port_name = w->out->getPortName(port_index));
        *length_out = port_name.length();
        *string_out = (char*)malloc(sizeof(char) **length_out);
        memcpy(*string_out, port_name.c_str(), sizeof(char) **length_out);
    }

    void wrap_rtmidi_in_open_port
    (wrap_rtmidi_in * w, unsigned int port_index, int is_virtual)
    {
        if(!w->in) {
            return;
        }
        if(is_virtual) {
            WITH_RACKET_HANDLER(w->send_error, w->in->openVirtualPort());
        } else {
            WITH_RACKET_HANDLER(w->send_error, w->in->openPort(port_index));
        }
        WITH_RACKET_HANDLER(w->send_error, w->in->setCallback(wrap_rtmidi_midi_callback, w));
        WITH_RACKET_HANDLER(w->send_error, w->in->ignoreTypes(false, false, false));
    }

    void wrap_rtmidi_in_close_port(wrap_rtmidi_in * w)
    {
        if(w->in) {
            w->in->closePort();
        }
    }

    void wrap_rtmidi_out_open_port
    (wrap_rtmidi_out * w, unsigned int port_index, int is_virtual)
    {
        if(!w->out) {
            return;
        }
        if(is_virtual) {
            WITH_RACKET_HANDLER(w->send_error, w->out->openVirtualPort());
        } else {
            WITH_RACKET_HANDLER(w->send_error, w->out->openPort(port_index));
        }
    }

    void wrap_rtmidi_out_close_port(wrap_rtmidi_out * w)
    {
        if(w->out) {
            w->out->closePort();
        }
    }

    void wrap_rtmidi_out_send_message
    (wrap_rtmidi_out * w, size_t message_sz, unsigned char * message)
    {
        if(!w->out) {
            return;
        }
        static std::vector<unsigned char> buffer;
        buffer.assign(message, message + message_sz);
        w->out->sendMessage(&buffer);
    }

}
