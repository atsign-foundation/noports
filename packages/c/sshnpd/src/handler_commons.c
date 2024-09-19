#include "atchops/rsa.h"
#include <atchops/constants.h>
#include <atchops/rsa_key.h>
#include <atlogger/atlogger.h>
#include <string.h>

#define LOGGER_TAG "VERIFY_REQUEST_SIGNATURE"

int verify_envelope_signature(atchops_rsa_key_public_key publickey, const unsigned char *payload,
                              unsigned char *signature, const char *hashing_algo, const char *signing_algo) {
  int ret = 0;

  atchops_md_type mdtype;

  if (strcmp(hashing_algo, "sha256") == 0) {
    mdtype = ATCHOPS_MD_SHA256;
  } else {
    atlogger_log(LOGGER_TAG, ATLOGGER_LOGGING_LEVEL_ERROR, "Unsupported hash type for rsa verify\n");
    return -1;
  }

  ret = atchops_rsa_verify(&publickey, ATCHOPS_MD_SHA256, payload, strlen((char *)payload), signature);
  if (ret != 0) {
    atlogger_log(LOGGER_TAG, ATLOGGER_LOGGING_LEVEL_ERROR, "verify_envelope_signature (failed)\n");
    return -1;
  }

  atlogger_log(LOGGER_TAG, ATLOGGER_LOGGING_LEVEL_DEBUG, "verify_envelope_signature (success)\n");

  return ret;
}
