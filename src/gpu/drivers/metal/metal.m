#include "metal.h"

#import <AppKit/AppKit.h>
#import <Metal/Metal.h>

void metal_release(metal_handle_t handle) { [handle release]; }

metal_result_t metal_init_device(metal_device_t *device) {
  @autoreleasepool {
    id<MTLDevice> mtl_device = MTLCreateSystemDefaultDevice();
    *device = mtl_device;
  }
  return METAL_RESULT_OK;
}

metal_result_t metal_init_queue(metal_queue_t *queue,
                                const metal_queue_options_t *options) {
  @autoreleasepool {
    MTLCommandQueueDescriptor *descriptor =
        [[MTLCommandQueueDescriptor alloc] init];
    [descriptor setMaxCommandBufferCount:options->max_command_buffer_count];

    id<MTLCommandQueue> command_queue =
        [options->device newCommandQueueWithDescriptor:descriptor];

    *queue = command_queue;
  }

  return METAL_RESULT_OK;
}

metal_result_t
metal_init_storage_buffer(metal_buffer_t *buffer,
                          const metal_buffer_options_t *options) {
  @autoreleasepool {
    const MTLResourceOptions resource_options = MTLResourceStorageModePrivate;
    id<MTLBuffer> mtl_buffer =
        [options->device newBufferWithLength:options->size
                                     options:resource_options];
    *buffer = mtl_buffer;
  }
  return METAL_RESULT_OK;
}

metal_result_t metal_init_upload_buffer(metal_buffer_t *buffer,
                                        const void *bytes,
                                        const metal_buffer_options_t *options) {
  @autoreleasepool {
    id<MTLBuffer> mtl_buffer =
        [options->device newBufferWithBytes:bytes
                                     length:options->size
                                    options:MTLResourceStorageModeShared];
    *buffer = mtl_buffer;
  }

  return METAL_RESULT_OK;
}
