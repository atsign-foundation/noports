#ifndef ENVIRONMENT_H
#define ENVIRONMENT_H

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

#endif
