#ifndef METAL_H
#define METAL_H

#include <stdint.h>

/**
 * Opaque ptr to any objc id or protocol.
 *
 * This is used to prevent objc imports bloating this header
 */
typedef void *metal_handle_t;
#define METAL_NULL_HANDLE (metal_handle_t)0

/** TODO: Documentation */
typedef enum {
  METAL_RESULT_OK,
  METAL_RESULT_UNKNOWN,

  METAL_RESULT_INVALID_HEAP_FOR_BUFFER_WITH_BYTES,
} metal_result_t;

/** TODO: Documentation */
typedef metal_handle_t metal_device_t;

/** TODO: Documentation */
void metal_release(metal_handle_t handle);

/** TODO: Documentation */
metal_result_t metal_init_device(metal_device_t *device);

/** TODO: Documentation */
typedef struct {
  metal_device_t device;
  uint32_t max_command_buffer_count;
} metal_queue_options_t;

/** TODO: Documentation */
typedef metal_handle_t metal_queue_t;

/** TODO: Documentation */
metal_result_t metal_init_queue(metal_queue_t *queue,
                                const metal_queue_options_t *options);

/** TODO: Documentation */
typedef struct {
  metal_device_t device;
  uint32_t size;
} metal_buffer_options_t;

/** TODO: Documentation */
typedef metal_handle_t metal_buffer_t;

/** TODO: Documentation */
metal_result_t metal_init_storage_buffer(metal_buffer_t *buffer,
                                         const metal_buffer_options_t *options);

/** TODO: Documentation */
metal_result_t metal_init_upload_buffer(metal_buffer_t *buffer,
                                        const void *bytes,
                                        const metal_buffer_options_t *options);
#endif // METAL_H
