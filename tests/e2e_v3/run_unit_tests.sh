#!/usr/bin/env bash

script_dir="$(dirname -- "$(readlink -f -- "$0")")"
python3 -m unittest discover -t "$script_dir" -s "$script_dir"
