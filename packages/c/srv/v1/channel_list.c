#include "channel_list.h"

// TODO
int channel_list_find(struct channel_list_node *head, pthread_t tid,
                      struct channel_list_node **result);
int channel_list_pop(struct channel_list_node *head, pthread_t tid,
                     struct channel_list_node **result);
int channel_list_remove(struct channel_list_node *head, pthread_t tid,
                        struct channel_list_node **result);
