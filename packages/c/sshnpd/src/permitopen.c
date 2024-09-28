#include "sshnpd/permitopen.h"
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <sys/errno.h>

int parse_permitopen(char *input, char ***permitopen_hosts, uint16_t **permitopen_ports, size_t *permitopen_len,
                     bool is_logger_available) {
  const char *TAG = "parse_permitopen";
  int sep_count = 0;
  int permitopen_end = strlen(input);

  for (int i = 0; i < permitopen_end; i++) {
    if (input[i] == ':') {
      sep_count++;
      input[i] = '\0';
    }

    if (input[i] == ',') {
      input[i] = '\0';
    }
  }

  // malloc pointers to each string, but don't malloc any more memory for individual char storage
  *permitopen_hosts = malloc((sep_count) * sizeof(char *));
  *permitopen_ports = malloc((sep_count) * sizeof(uint16_t));
  if (*permitopen_hosts == NULL) {
    if (is_logger_available) {
      atlogger_log(TAG, ATLOGGER_LOGGING_LEVEL_ERROR, "Failed to allocate memory for permitopen\n");
    } else {
      printf("Failed to allocate memory for permitopen\n");
    }
    free(*permitopen_hosts);
    free(*permitopen_ports);
    return 1;
  }

  int pos = 0;
  for (int i = 0; i < sep_count; i++) {
    // Add the host to the host list
    (*permitopen_hosts)[i] = input + pos;
    // Jump to the port string
    pos += strlen(input + pos) + 1;
    if (input[pos] == '*') {
      (*permitopen_ports)[i] = 0;
      if (input[pos + 1] != '\0') {
        // error received a string other than '*' for port
        if (is_logger_available) {
          atlogger_log(TAG, ATLOGGER_LOGGING_LEVEL_ERROR,
                       "Argument error, received %s for port, must be a number 1-65535 or '*'", input + pos);
        } else {
          printf("Argument error, received %s for port, must be a number 1-65535 or '*'", input + pos);
        }
        free(*permitopen_hosts);
        free(*permitopen_ports);
        return 1;
      }
    } else {
      char *end;
      long num = strtol(input + pos, &end, 10);
      if (end == input + pos || *end != '\0' || errno == ERANGE) {
        if (is_logger_available) {
          atlogger_log(TAG, ATLOGGER_LOGGING_LEVEL_ERROR,
                       "Argument error, received %s for port, must be a number 1-65535 or '*'", input + pos);
        } else {
          printf("Argument error, received %s for port, must be a number 1-65535 or '*'", input + pos);
        }
        free(*permitopen_hosts);
        free(*permitopen_ports);
        return 1;
      }

      (*permitopen_ports)[i] = (uint16_t)num;
    }

    // Jump to the host string
    //
    pos = pos + strlen(input + pos) + 1;
  }

  *permitopen_len = sep_count;
  return 0;
}

bool should_permitopen(permitopen_params *params) {
  const char *TAG = "should_permitopen";

  for (int i = 0; i < params->permitopen_len; i++) {
    // permitopen_port[i] = 0 is equivalent to '*'
    if (params->permitopen_ports[i] == 0 || params->permitopen_ports[i] == params->requested_port) {
      if (params->permitopen_hosts[i][0] == '*' && strlen(params->permitopen_hosts[i]) == 1) {
        return true;
      }
      if (strcmp(params->permitopen_hosts[i], params->requested_host) == 0) {
        return true;
      }
    }
  }

  return false;
}
