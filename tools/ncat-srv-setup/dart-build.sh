#!/bin/bash

script_dir=$(dirname "$(readlink -f "$0")")
root_dir=$script_dir/../..
build_dir=$script_dir/dart

dart compile exe "$root_dir/packages/dart/sshnoports/bin/srv.dart" -o "$build_dir/srv"
