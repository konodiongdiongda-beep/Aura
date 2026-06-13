#ifndef AURA_AEC_H
#define AURA_AEC_H

#include <stdbool.h>
#include <stdint.h>
#include <stddef.h>

#ifdef __cplusplus
extern "C" {
#endif

typedef struct Aec Aec;

Aec *AecNew(uintptr_t frame_size,
            int32_t filter_length,
            uint32_t sample_rate,
            bool enable_preprocess);

void AecCancelEcho(Aec *aec_ptr,
                   const int16_t *rec_buffer,
                   const int16_t *echo_buffer,
                   int16_t *out_buffer,
                   uintptr_t buffer_length);

void AecDestroy(Aec *aec_ptr);

#ifdef __cplusplus
}
#endif

#endif
