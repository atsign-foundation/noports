#include <atchops/base64.h>
#include <atlogger/atlogger.h>
#include <srv/stream.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>

int main() {
  const char *b64key = "1DPU9OP3CYvamnVBMwGgL7fm8yB1klAap0Uc5Z9R79g=";
  const char *iv = "1234567890ABCDEF";

  const char *input1 = "ABCDEFGHIJKLMNOPQRSTUVWXYZ";
  size_t len1 = strlen(input1);
  const char *input2 = "ABCDEFGHIJKLMNOPQRSTUVWXYZFOOABCDEFGHIJKLMNOPQRSTUVWXYZ";
  size_t len2 = strlen(input2);
  int res = 0;

  unsigned char key[32];
  size_t olen;
  res = atchops_base64_decode((unsigned char *)b64key, strlen(b64key), key, 32, &olen);
  if (res != 0 || olen != 32) {
    printf("Base 64 decrypt key failed\n");
    return res;
  }

  atclient_atlogger_set_logging_level(ATLOGGER_LOGGING_LEVEL_DEBUG);
  // Encrypt transfomer 1
  printf("Setup et1\n");
  chunked_transformer_t et1;
  mbedtls_aes_init(&et1.aes_ctr.ctx);
  mbedtls_aes_setkey_enc(&et1.aes_ctr.ctx, key, 256);
  memcpy(&et1.aes_ctr.nonce_counter, iv, 16);
  memset(&et1.aes_ctr.stream_block, 0, 16);
  et1.aes_ctr.nc_off = 0;
  et1.transform = aes_ctr_crypt_stream;

  // Decrypt transfomer 1
  printf("Setup dt1\n");
  chunked_transformer_t dt1;
  mbedtls_aes_init(&dt1.aes_ctr.ctx);
  mbedtls_aes_setkey_enc(&dt1.aes_ctr.ctx, key, 256);
  memcpy(&dt1.aes_ctr.nonce_counter, iv, 16);
  memset(&dt1.aes_ctr.stream_block, 0, 16);
  dt1.aes_ctr.nc_off = 0;
  dt1.transform = aes_ctr_crypt_stream;

  printf("Setup buffers\n");
  char buffer1[len1];
  char output1[len1];
  // iterate byte for byte through input1 and do stream encrypt
  // and then decrypt, recording middle point and final output
  unsigned char *c = malloc(sizeof(char));
  unsigned char *o = malloc(sizeof(char));
  printf("iterating through %lu bytes\n", len1);
  for (size_t i = 0; i < len1; i++) {
    *c = input1[i];
    printf("byte %lu\n", i + 1);
    res = et1.transform(&et1, 1, (unsigned char *)c, (unsigned char *)o);
    if (res != 0) {
      printf("Encrypt failed at byte %lu\n", i + 1);
      free(c);
      free(o);
      return res;
    }
    *c = *o;
    buffer1[i] = *c;
    printf("Encypted byte %lu -  '%d'->'%d'\n", i + 1, input1[i], buffer1[i]);
    res = dt1.transform(&dt1, 1, (unsigned char *)c, (unsigned char *)o);
    if (res != 0) {
      printf("Decrypt failed at byte %lu\n", i + 1);
      free(c);
      return res;
    }
    output1[i] = *o;
    printf("Decrypted byte %lu -  '%d'->'%d'\n", i + 1, buffer1[i], output1[i]);
  }

  free(c);
  printf(" input1: %s\n", input1);
  printf("buffer1: %s\n", buffer1);
  printf("output1: %s\n", output1);

  res = strcmp(input1, output1);
  mbedtls_aes_free(&et1.aes_ctr.ctx);
  mbedtls_aes_free(&dt1.aes_ctr.ctx);
  return res;
}
