#!/bin/bash
CC="zig cc" \
cmake \
  -DBUILD_SHARED_LIBS=off \
  -DBUILD_TESTS=off \
  -DCMAKE_SYSTEM_NAME="Linux" \
  -DCMAKE_SYSTEM_PROCESSOR="x86_64" \
  -DCMAKE_C_COMPILER_TARGET="x86_64-linux-gnu.2.5" \
  -DCMAKE_AR="$PWD/zig-ar" \
  -DCMAKE_RANLIB="$PWD/zig-ranlib" \
  -DCMAKE_C_FLAGS="-Wno-error -pthread -lrt" \
  -B build
