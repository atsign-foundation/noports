/**
 * @file noports_log.h
 * @brief Lightweight logging for the NoPorts daemon on Arduino
 *
 * Wraps Serial output. The atSDK's internal log messages are bridged
 * to Serial via the embedded atsdk_atsdk.cpp.
 */

#ifndef NOPORTS_LOG_H
#define NOPORTS_LOG_H

#include <Arduino.h>

// Log levels matching atlogger
#define NOPORTS_LOG_NONE    0
#define NOPORTS_LOG_ERROR   1
#define NOPORTS_LOG_WARN    2
#define NOPORTS_LOG_INFO    3
#define NOPORTS_LOG_DEBUG   4

#ifndef NOPORTS_LOG_LEVEL
  #define NOPORTS_LOG_LEVEL NOPORTS_LOG_INFO
#endif

#define NOPORTS_LOG(level, tag, fmt, ...)                                    \
  do {                                                                       \
    if ((level) <= NOPORTS_LOG_LEVEL) {                                      \
      Serial.printf("[%s][%s] " fmt "\n",                                    \
        (level) == NOPORTS_LOG_ERROR ? "ERROR" :                             \
        (level) == NOPORTS_LOG_WARN  ? "WARN"  :                            \
        (level) == NOPORTS_LOG_INFO  ? "INFO"  : "DEBUG",                    \
        (tag), ##__VA_ARGS__);                                               \
    }                                                                        \
  } while(0)

#define NOPORTS_LOGE(tag, fmt, ...) NOPORTS_LOG(NOPORTS_LOG_ERROR, tag, fmt, ##__VA_ARGS__)
#define NOPORTS_LOGW(tag, fmt, ...) NOPORTS_LOG(NOPORTS_LOG_WARN,  tag, fmt, ##__VA_ARGS__)
#define NOPORTS_LOGI(tag, fmt, ...) NOPORTS_LOG(NOPORTS_LOG_INFO,  tag, fmt, ##__VA_ARGS__)
#define NOPORTS_LOGD(tag, fmt, ...) NOPORTS_LOG(NOPORTS_LOG_DEBUG, tag, fmt, ##__VA_ARGS__)

// Build with -DNOPORTS_HEAP_TRACE to log the internal (DRAM) heap at each
// stage of handling a ping, a session request and a session's end, for
// chasing a per-session leak. Compiles to nothing otherwise.
#ifdef NOPORTS_HEAP_TRACE
  #include <esp_heap_caps.h>
  #define NOPORTS_HEAP_TRACE(tag, stage)                                     \
    NOPORTS_LOGI(tag, "Heap[%s]: internal=%u largest=%u", stage,             \
                 (unsigned)heap_caps_get_free_size(MALLOC_CAP_INTERNAL),      \
                 (unsigned)heap_caps_get_largest_free_block(MALLOC_CAP_INTERNAL))
#else
  #define NOPORTS_HEAP_TRACE(tag, stage) do {} while (0)
#endif

#endif // NOPORTS_LOG_H
