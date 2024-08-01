#!/bin/bash
CC="zig cc" \
cmake \
  -DBUILD_SHARED_LIBS=off \
  -DBUILD_TESTS=off \
  -DCMAKE_C_COMPILER_TARGET="x86_64-macos-none" \
  -DCMAKE_AR="$PWD/zig-ar" \
  -DCMAKE_RANLIB="$PWD/zig-ranlib" \
  -DCMAKE_C_FLAGS="-Wno-error -pthread" \
  -B build-macos-x64
