#ifndef SRC_PTHREAD_HANDLE_H
#define SRC_PTHREAD_HANDLE_H
#ifdef __cplusplus
extern "C" {
#endif

#include <pthread.h>
#include <stdbool.h>

enum pthread_mode {
  pthread_mode_detach, // when we want to signal that the pthread is safe to
                       // detach (use only with one)
  pthread_mode_wait, // when we want to wait for a thread to fully exit (can be
                     // used with many)
};

struct pthread_handle {
  pthread_cond_t cond;
  pthread_mutex_t lock;
  pthread_t state;
  bool is_valid;
  bool is_active;
};

#define pthread_handle_initializer                                             \
  (struct pthread_handle){                                                     \
      .cond = PTHREAD_COND_INITIALIZER,                                        \
      .lock = PTHREAD_MUTEX_INITIALIZER,                                       \
      .state = NULL,                                                           \
      .is_valid = false,                                                       \
      .is_active = true,                                                       \
  };

void free_pthread_handle(struct pthread_handle *handle);
pthread_t pthread_handle_wait(struct pthread_handle *handle);
void pthread_handle_signal(struct pthread_handle *handle);

#ifdef __cplusplus
}
#endif
#endif
