// Link-time allocation tracer for chasing a per-session heap leak.
//
// Only compiled into a trace build: build with
//   -DNOPORTS_HEAP_TRACE -Wl,--wrap=malloc -Wl,--wrap=free -Wl,--wrap=calloc
//   -Wl,--wrap=realloc -Wl,--wrap=_malloc_r -Wl,--wrap=_free_r
//   -Wl,--wrap=_calloc_r -Wl,--wrap=_realloc_r
// Every allocation made through libc (the SDK, cJSON, mbedtls, the C++
// runtime) is recorded with a short backtrace; heap_trace_checkpoint(), called
// from loop() when the device is idle, lists the blocks allocated since the
// previous idle checkpoint that are still live, grouped by call stack, so a
// batch of sessions between two idle points leaves exactly its leaks on the
// list. Decode the PCs with xtensa-esp32s3-elf-addr2line -pfiaC -e firmware.elf.
#ifdef NOPORTS_HEAP_TRACE
#include <Arduino.h>
#include <esp_debug_helpers.h>
#include <soc/cpu.h>
#include <freertos/FreeRTOS.h>
#include <string.h>
#include <sys/reent.h>

extern "C" {
void *__real_malloc(size_t);
void  __real_free(void *);
void *__real_calloc(size_t, size_t);
void *__real_realloc(void *, size_t);
void *__real__malloc_r(struct _reent *, size_t);
void  __real__free_r(struct _reent *, void *);
void *__real__calloc_r(struct _reent *, size_t, size_t);
void *__real__realloc_r(struct _reent *, void *, size_t);
}

#define TRACE_DEPTH 5
#define TRACE_SLOTS 768

struct TraceRec {
  void    *p;
  uint32_t size;
  uint32_t seq;
  uint32_t pc[TRACE_DEPTH];
};

static TraceRec s_table[TRACE_SLOTS];
static uint32_t s_seq = 0;
static uint32_t s_mark = 0;        // seq at the last idle checkpoint
static uint32_t s_dropped = 0;     // allocations not recorded: table full
static portMUX_TYPE s_mux = portMUX_INITIALIZER_UNLOCKED;

// Return addresses up the stack from the allocation site; the first two or
// three frames are this file's own functions and are listed as such.
static void IRAM_ATTR capture(uint32_t *pc) {
  esp_backtrace_frame_t f;
  esp_backtrace_get_start(&f.pc, &f.sp, &f.next_pc);
  for (int i = 0; i < TRACE_DEPTH; i++) {
    pc[i] = esp_cpu_process_stack_pc(f.pc);
    if (!esp_backtrace_get_next_frame(&f)) {
      for (int j = i + 1; j < TRACE_DEPTH; j++) pc[j] = 0;
      return;
    }
  }
}

static void IRAM_ATTR record(void *p, size_t size) {
  if (p == NULL) return;
  uint32_t pc[TRACE_DEPTH];
  capture(pc);
  portENTER_CRITICAL(&s_mux);
  uint32_t seq = ++s_seq;
  for (int i = 0; i < TRACE_SLOTS; i++) {
    if (s_table[i].p == NULL) {
      s_table[i].p = p;
      s_table[i].size = (uint32_t)size;
      s_table[i].seq = seq;
      memcpy(s_table[i].pc, pc, sizeof(pc));
      portEXIT_CRITICAL(&s_mux);
      return;
    }
  }
  s_dropped++;
  portEXIT_CRITICAL(&s_mux);
}

static void IRAM_ATTR forget(void *p) {
  if (p == NULL) return;
  portENTER_CRITICAL(&s_mux);
  for (int i = 0; i < TRACE_SLOTS; i++) {
    if (s_table[i].p == p) {
      s_table[i].p = NULL;
      break;
    }
  }
  portEXIT_CRITICAL(&s_mux);
}

extern "C" {
void *__wrap_malloc(size_t n) { void *p = __real_malloc(n); record(p, n); return p; }
void *__wrap_calloc(size_t a, size_t b) { void *p = __real_calloc(a, b); record(p, a * b); return p; }
void *__wrap_realloc(void *o, size_t n) { void *p = __real_realloc(o, n); if (p) { forget(o); record(p, n); } return p; }
void  __wrap_free(void *p) { forget(p); __real_free(p); }
void *__wrap__malloc_r(struct _reent *r, size_t n) { void *p = __real__malloc_r(r, n); record(p, n); return p; }
void *__wrap__calloc_r(struct _reent *r, size_t a, size_t b) { void *p = __real__calloc_r(r, a, b); record(p, a * b); return p; }
void *__wrap__realloc_r(struct _reent *r, void *o, size_t n) { void *p = __real__realloc_r(r, o, n); if (p) { forget(o); record(p, n); } return p; }
void  __wrap__free_r(struct _reent *r, void *p) { forget(p); __real__free_r(r, p); }

// Lists the live blocks allocated since the previous checkpoint, grouped by
// call stack, then starts a new window. Call only when the device is idle.
void heap_trace_checkpoint(void) {
  static TraceRec snap[192];
  static bool counted[192];
  portENTER_CRITICAL(&s_mux);
  uint32_t since = s_mark, upto = s_seq, dropped = s_dropped;
  int n = 0;
  for (int i = 0; i < TRACE_SLOTS && n < 192; i++) {
    if (s_table[i].p != NULL && s_table[i].seq > since) snap[n++] = s_table[i];
  }
  s_mark = s_seq;
  portEXIT_CRITICAL(&s_mux);

  Serial.printf("HeapTrace: window seq %lu..%lu, %d live blocks allocated in it (dropped %lu)\n",
                (unsigned long)since, (unsigned long)upto, n, (unsigned long)dropped);
  memset(counted, 0, sizeof(bool) * n);
  for (int i = 0; i < n; i++) {
    if (counted[i]) continue;
    int count = 0;
    uint32_t bytes = 0;
    for (int j = i; j < n; j++) {
      if (!counted[j] && memcmp(snap[j].pc, snap[i].pc, sizeof(snap[i].pc)) == 0) {
        counted[j] = true;
        count++;
        bytes += snap[j].size;
      }
    }
    Serial.printf("HeapTrace: %3d blocks %6lu bytes", count, (unsigned long)bytes);
    for (int k = 0; k < TRACE_DEPTH; k++) Serial.printf(" 0x%08lx", (unsigned long)snap[i].pc[k]);
    Serial.printf("\n");
  }
  Serial.printf("HeapTrace: end\n");
}
}
#endif
