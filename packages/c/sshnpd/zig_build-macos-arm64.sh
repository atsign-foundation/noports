#!/bin/bash
CC="zig cc" \
cmake \
  -DBUILD_SHARED_LIBS=off \
  -DBUILD_TESTS=off \
  -DCMAKE_C_COMPILER_TARGET="aarch64-macos-none" \
  -DCMAKE_AR="$PWD/zig-ar" \
  -DCMAKE_RANLIB="$PWD/zig-ranlib" \
  -DCMAKE_C_FLAGS="-Wno-error -pthread" \
  -B build-macos-arm64
cmake --build build-macos-arm64
