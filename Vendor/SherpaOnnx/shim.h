// Umbrella shim for the sherpa-onnx C API. The xcframework exposes its public C
// header at Headers/sherpa-onnx/c-api/c-api.h; Xcode adds that Headers dir to
// the search path when the framework is linked, so this include resolves.
#include "sherpa-onnx/c-api/c-api.h"
