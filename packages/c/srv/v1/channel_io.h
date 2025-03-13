#ifndef SRV_CHANNEL_IO_H
#define SRV_CHANNEL_IO_H
#ifdef __cplusplus
extern "C" {
#endif

#include <stdint.h>

enum channel_io_type {
  channel_io_type_unset = 0,
  channel_io_type_rw = 1,
  channel_io_type_bind = 2,
};

struct channel_io {
  void (*free)(struct channel_io *self);
  union {
    // rw methods
    struct {
      int (*send)(struct channel_io *self, const unsigned char *const buffer,
                  uint16_t len);
      int (*recv)(struct channel_io *self, unsigned char *buffer,
                  uint16_t *len);
    };
    // bind methods
    struct {
      int (*accept)(struct channel_io *self, struct channel_io *accepted);
    };
  };
  enum channel_io_type type;
};

#ifdef __cplusplus
}
#endif
#endif
