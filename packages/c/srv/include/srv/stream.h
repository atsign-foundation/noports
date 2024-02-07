#ifndef STREAM_H
#define STREAM_H
#include <stddef.h>

typedef struct _aes_transformer aes_transformer_t;
struct _aes_transformer {
  char *key;
  char *iv;
  // TODO: add mac
  int (*transform)(const struct _aes_transformer *self, unsigned char *istream,
                   const size_t ilen);
};

int aes_encrypt_stream(const struct _aes_transformer *self,
                       unsigned char *istream, const size_t ilen);

int aes_decrypt_stream(const struct _aes_transformer *self,
                       unsigned char *istream, const size_t ilen);
#endif
