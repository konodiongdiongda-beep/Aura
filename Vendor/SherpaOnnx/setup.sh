#!/usr/bin/env bash
# Fetch and lay out the sherpa-onnx iOS frameworks + the CAM++ voiceprint model.
#
# Run once after cloning (the .xcframework binaries and the 28 MB model are not
# committed). Idempotent: skips downloads that are already in place.
#
#   ./Vendor/SherpaOnnx/setup.sh
#
# Produces:
#   Vendor/SherpaOnnx/sherpa-onnx.xcframework
#   Vendor/SherpaOnnx/onnxruntime.xcframework
#   AuraVoiceAssistant/Resources/campplus_zh_cn_common.onnx
set -euo pipefail

SHERPA_VERSION="v1.13.2"
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$HERE/../.." && pwd)"
TARBALL_URL="https://github.com/k2-fsa/sherpa-onnx/releases/download/${SHERPA_VERSION}/sherpa-onnx-${SHERPA_VERSION}-ios.tar.bz2"

# 3D-Speaker CAM++ zh-cn 192-dim model (sherpa-onnx pre-exported ONNX, 28 MB).
# NOTE: the GitHub release tag is misspelled upstream ("recongition").
MODEL_URL="https://github.com/k2-fsa/sherpa-onnx/releases/download/speaker-recongition-models/3dspeaker_speech_campplus_sv_zh-cn_16k-common.onnx"
MODEL_DEST="$PROJECT_ROOT/AuraVoiceAssistant/Resources/campplus_zh_cn_common.onnx"

echo "[setup] sherpa-onnx ${SHERPA_VERSION} + CAM++ voiceprint model"

# ---- frameworks ----
if [[ -d "$HERE/sherpa-onnx.xcframework" && -d "$HERE/onnxruntime.xcframework" ]]; then
  echo "[setup] xcframeworks already present, skipping download"
else
  TMP="$(mktemp -d)"
  echo "[setup] downloading iOS frameworks (~78 MB)…"
  curl -L "$TARBALL_URL" -o "$TMP/ios.tar.bz2"
  echo "[setup] extracting…"
  tar xjf "$TMP/ios.tar.bz2" -C "$TMP"
  cp -R "$TMP/build-ios/sherpa-onnx.xcframework" "$HERE/"
  # onnxruntime location varies slightly by release; find it.
  ORT="$(find "$TMP/build-ios" -maxdepth 3 -name 'onnxruntime.xcframework' -type d | head -1)"
  cp -R "$ORT" "$HERE/"
  rm -rf "$TMP"
  echo "[setup] frameworks installed under Vendor/SherpaOnnx/"
fi

# ---- C headers for the Clang module map ----
# The module map's shim.h includes <sherpa-onnx/c-api/c-api.h>. Surface the C
# headers (identical across slices) at a stable, slice-independent location so
# `canImport(sherpa_onnx)` can resolve the module at compile time.
HDR_SRC="$HERE/sherpa-onnx.xcframework/ios-arm64/Headers"
if [[ -d "$HDR_SRC" && ! -d "$HERE/include/sherpa-onnx" ]]; then
  mkdir -p "$HERE/include"
  cp -R "$HDR_SRC/." "$HERE/include/"
  echo "[setup] copied C headers to Vendor/SherpaOnnx/include"
fi

# ---- model ----
mkdir -p "$(dirname "$MODEL_DEST")"
LOCAL_MODEL="$PROJECT_ROOT/../../../Desktop/Talk_now!/voiceprint/models/campplus_zh_cn_common.onnx"
if [[ -f "$MODEL_DEST" ]]; then
  echo "[setup] model already present, skipping"
elif [[ -f "$LOCAL_MODEL" ]]; then
  echo "[setup] copying model from local Talk_now checkout"
  cp "$LOCAL_MODEL" "$MODEL_DEST"
else
  echo "[setup] downloading CAM++ model (~28 MB)…"
  curl -L "$MODEL_URL" -o "$MODEL_DEST"
fi

echo "[setup] done. Re-run 'xcodegen generate' && 'pod install' if needed."
