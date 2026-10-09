#!/bin/bash
TARGET="x86_64-linux-gnu.2.17"
CC="zig cc -target ${TARGET}" \
cmake \
  -B build-linux-x64-gnu
  -DCMAKE_SYSTEM_NAME="Linux" \
  -DCMAKE_SYSTEM_PROCESSOR="x86_64" \
  -DCMAKE_C_FLAGS="-Wno-error -pthread -Oz -flto=thin -ffunction-sections -fdata-sections -fno-asynchronous-unwind-tables -fno-unwind-tables" \ 
  -DCMAKE_EXE_LINKER_FLAGS="-flto=thin -Wl,--gc-sections -Wl,--strip-all -Wl,--as-needed -pthread -lrt" \
  -DCMAKE_C_CREATE_STATIC_LIBRARY="zig ar qc <TARGET> <LINK_FLAGS> <OBJECTS>; zig ranlib <TARGET>" \
  -DBUILD_SHARED_LIBS=OFF \
  -DBUILD_TESTS=OFF
cmake --build build-linux-x64-gnu

