#!/bin/bash
set -eu
FULL_PATH_TO_SCRIPT="$(realpath "${BASH_SOURCE[0]}")"
SCRIPT_DIRECTORY="$(dirname "$FULL_PATH_TO_SCRIPT")"
cd "$SCRIPT_DIRECTORY"
cd ..

cmake -S . -B build -DCMAKE_BUILD_TYPE=Debug -DCMAKE_C_COMPILER=gcc -DBUILD_SHARED_LIBS=off -DCMAKE_C_FLAGS="-Wno-calloc-transposed-args -Wno-error -pthread -lrt"

cmake --build build
