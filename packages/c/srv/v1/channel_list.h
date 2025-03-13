#ifndef SRV_CHANNEL_LIST_H
#define SRV_CHANNEL_LIST_H
#ifdef __cplusplus
extern "C" {
#endif

#include "channel.h"
#include <pthread.h>

struct channel_list_node {
  struct channel_list_node *next;
  pthread_t tid;
  struct channel channel;
};

int channel_list_find(struct channel_list_node *head, pthread_t tid,
                      struct channel_list_node **result);
int channel_list_pop(struct channel_list_node *head, pthread_t tid,
                     struct channel_list_node **result);
int channel_list_remove(struct channel_list_node *head, pthread_t tid,
                        struct channel_list_node **result);

#ifdef __cplusplus
}
#endif
#endif
