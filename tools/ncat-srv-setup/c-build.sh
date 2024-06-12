#!/bin/bash

script_dir=$(dirname "$(readlink -f "$0")")
root_dir=$script_dir/../..
build_dir=$script_dir/c

cmake -S "$root_dir/packages/c/srv" -B "$build_dir"
sudo cmake --build "$build_dir"
