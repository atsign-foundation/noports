#!/bin/bash
rm -f conan.lock
conan lock create conanfile.py -nr
jq '.build_requires = []' conan.lock > conan.lock.tmp && mv conan.lock.tmp conan.lock