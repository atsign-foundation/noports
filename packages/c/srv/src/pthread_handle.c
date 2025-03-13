#include "pthread_handle.h"
#include <stdlib.h>

void free_pthread_handle(struct pthread_handle *handle) {
  pthread_mutex_lock(&handle->lock);
  handle->state = NULL;
  handle->is_valid = false;
  handle->is_active = false;
  pthread_cond_destroy(&handle->cond);
  pthread_mutex_unlock(&handle->lock);
  pthread_mutex_destroy(&handle->lock);
}

pthread_t pthread_handle_wait(struct pthread_handle *handle) {
  pthread_mutex_lock(&handle->lock);
  if (!handle->is_valid) {
    pthread_mutex_unlock(&handle->lock);
    return handle->state;
  }

  while (handle->state == NULL)
    pthread_cond_wait(&handle->cond, &handle->lock);
  return handle->state;
}

void pthread_handle_signal(struct pthread_handle *handle) {
  pthread_mutex_lock(&handle->lock);
  if (handle->is_valid) {
    handle->state = pthread_self();
  }
  pthread_mutex_unlock(&handle->lock);
}
