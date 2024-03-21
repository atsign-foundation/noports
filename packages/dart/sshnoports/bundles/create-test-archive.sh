#!/bin/sh

script_dir="$(dirname -- "$(readlink -f -- "$0")")"
time_stamp=$(date +%s)

tempdir="$script_dir/temp-$time_stamp/sshnp"
outfile="$script_dir/sshnp-$time_stamp"

mkdir -p "$tempdir"
cp -R "$script_dir"/core/* "$tempdir/"
cp -R "$script_dir"/shell/* "$tempdir/"

if [ "$(uname)" = 'Darwin' ]; then
	ditto -c -k --keepParent "$tempdir" "$outfile.zip"
else
	tar -cvzf "$outfile.tgz" "$script_dir/temp-$time_stamp"
fi
