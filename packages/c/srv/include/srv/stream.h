#ifndef STREAM_H
#define STREAM_H
#include <stddef.h>

typedef struct _aes_transformer aes_transformer_t;
struct _aes_transformer {
  char *key;
  char *iv;
  // TODO: add mac
  int (*transform)(struct _aes_transformer *transfomer, const char *istream,
                   const size_t ilen, char *ostream, size_t *olen);
};

int aes_encrypt_stream(struct _aes_transformer *transfomer, const char *istream,
                       const size_t ilen, char *ostream, size_t *olen);

int aes_decrypt_stream(struct _aes_transformer *transfomer, const char *istream,
                       const size_t ilen, char *ostream, size_t *olen);

#endif
