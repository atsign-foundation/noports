#ifndef SRC_CHANNEL_IO_H
#define SRC_CHANNEL_IO_H
#ifdef __cplusplus
extern "C" {
#endif

#include <srv/params.h>
#include <stdlib.h>

enum channel_io_type {
  channel_io_type_unset = 0,
  channel_io_type_rw = 1,
  channel_io_type_bind = 2,
  channel_io_type_connect = 3,
};

struct channel_io {
  void (*free)(struct channel_io *self);
  union {
    // rw methods
    struct {
      int (*send)(struct channel_io *self, const unsigned char *const buffer,
                  size_t len);
      int (*recv)(struct channel_io *self, unsigned char *buffer, size_t *len);
    };
    // bind methods
    struct {
      int (*accept)(struct channel_io *self, struct channel_io *accepted);
    };
    // connect methods
    struct {
      int (*connect)(struct channel_io *self, struct channel_io *connected);
    };
  };
  enum channel_io_type type;
};

#define channel_io_initializer                                                 \
  (struct channel_io) {                                                        \
    .free = NULL, .send = NULL, .recv = NULL, .type = channel_io_type_unset,   \
  }

struct channel_io *create_channel_io_remote(struct srv_params);
struct channel_io *create_channel_io_local(struct srv_params);

void free_channel_io(struct channel_io *);
int create_channel_io_session(struct channel_io *, struct channel_io **);

#ifdef __cplusplus
}
#endif
#endif
