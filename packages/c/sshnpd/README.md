# C sshnpd

## Status

The C version of sshnpd is currently in alpha, we are working hard to deliver a
lighter weight and more widely available version of sshnpd (NoPorts device
daemon).

## Caveats

Because this is still in alpha, and it is dependent on the alpha
[C atSDK](https://github.com/atsign-foundation/at_c), this version of sshnpd is
expected to have both known and unknown bugs as it undergoes extensive testing
and analysis.

### Known bugs

There are some known memory leaks in the current alpha (0.1.0) release. We are
actively addressing the most critical ones first, and will provide valgrind
suppression files for non-critical ones.

In this case, "non-critical memory leaks" includes finite memory leaks which
will not grow with continued use of the software. This can include:

- Memory leaks which are cleaned upon closure of a forked child process
- Memory which should be allocated for the entire life of the main process

### Likely bugs

Stability around system calls is not well tested, and may not work in all
environments. We have done our best to use portable solutions where possible.

## How to build

If you don't already have this repo cloned locally:

```
git clone https://github.com/atsign-foundation/noports
cd noports
```

The preferred way to build this project is with cmake. You can install cmake
through most package managers, or from [PyPI](https://pypi.org/project/cmake/)
using python's pip installer.

We use cmake policy CMP0135, which requires a minimum version of cmake 3.24. If
your package manager doesn't provide a recent enough version, we recommend
installing via PyPI.

With `gcc` (disables warnings found in mbedtls' tests):

```bash
cd packages/c/sshnpd
cmake -B build -S . -DBUILD_SHARED_LIBS=off -DCMAKE_C_COMPILER=gcc -DCMAKE_C_FLAGS="-Wno-calloc-transposed-args -Wno-error -pthread -lrt"
cmake --build build
```

With clang:

```bash
cd packages/c/sshnpd
cmake -B build -S . -DBUILD_SHARED_LIBS=off -DCMAKE_C_COMPILER=clang -DCMAKE_C_FLAGS="-Wno-error -pthread -lrt"
cmake --build build
```

### Link to shared libraries

Linking to shared libraries is not well supported yet, expect difficulties if
you choose to pursue this. We kindly ask that you
[file a GitHub issue](https://github.com/atsign-foundation/noports/issues/new/choose)
if you experience a challenge so that we can improve the build toolchain of No
Ports.

To enable shared libraries you must turn on `BUILD_SHARED_LIBS` like so:
`-DBUILD_SHARED_LIBS=on`.

If you want only cjson to be statically linked (rather than needing `libcjson1`
shared library), cjson provides the following options:

```
option(CJSON_OVERRIDE_BUILD_SHARED_LIBS "Override BUILD_SHARED_LIBS with CJSON_BUILD_SHARED_LIBS" OFF)
option(CJSON_BUILD_SHARED_LIBS "Overrides BUILD_SHARED_LIBS if CJSON_OVERRIDE_BUILD_SHARED_LIBS is enabled" ON)
```

For example, to build with cjson statically linked, but the rest of the
dependencies with shared libraries (if available):
`-DBUILD_SHARED_LIBS=on -DCJSON_OVERRIDE_BUILD_SHARED_LIBS=on -DCJSON_BUILD_SHARED_LIBS=off`

The sshnpd binary will then be located at `./build/sshnpd`.

## Build Confirmation

Run `./build/sshnpd --help` as a quick sanity check that the build was
successful.

## Dependencies

All of the dependencies we are using are automatically installed through cmake.

We are in the process of compiling this information into SBOMs.

They are as follows:

1. atsdk (targets: atclient atchops atlogger) - the main sdk used to build
   noports
2. argparse (targets: argparse-static) - stored in `../3rdparty/argparse/`
3. srv (targets: srv-lib) - stored in `../srv/`
4. mbedtls (targets: mbedtls mbedx509 mbedcrypto everest p256m) - transitive
   dependency of atsdk::atchops
5. cjson (targets: cjson) - transitive dependency of atsdk::atclient
6. uuid4 (targets: uuid4-static) - transitive dependency of atsdk::atchops
