#ifndef SSHNPD_AUTHORIZATION_H
#define SSHNPD_AUTHORIZATION_H

#include "sshnpd/params.h"
#include <stdbool.h>
#include <stddef.h>

#define SSHNPD_ATSIGN_MAX_LEN 55
#define SSHNPD_ATSIGN_BUFFER_LEN (SSHNPD_ATSIGN_MAX_LEN + 2)

int sshnpd_normalize_atsign(const char *input, char *out, size_t out_len);

#endif
