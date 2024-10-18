#ifndef SSHNPD_H
#define SSHNPD_H
#include <unistd.h>

/* Windows Definitions */
#ifdef _WIN32
#define HOMEVAR "USERPROFILE"
#define USERVAR "USERNAME"
#endif

/* Mac / Linux Definitions */
#ifndef _WIN32
#define HOMEVAR "HOME"
#define USERVAR "USER"
#endif

#define ROOT_HOST "root.atsign.org"
#define ROOT_PORT 64

#define PUBLICKEY_PREFIX "public:publickey@"
#define PUBLICKEY_PREFIX_LEN 17

#define SSHNP_NS "sshnp"
#define SSHNP_NS_LEN 5

enum notification_key {
  NK_NONE,
  NK_SSHPUBLICKEY,
  NK_PING,
  NK_SSH_REQUEST,
  NK_NPT_REQUEST,
};

#define NOTIFICATION_KEYS_LEN 5

#endif
