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

- ephemeral ssh key files are not automatically purged from the device
- the ephemeral ssh public keys are not removed from authorized_keys 
automatically

### Likely bugs

Stability around system calls is not well tested, and may not work in all 
environments.
We have done our best to use portable solutions where possible.

### Improvements we will be making

We plan to eliminate a large surface for bugs by removing a redundant step in 
the connection process for sshnp. This step pre-dates end-to-end traffic 
encryption capabilities for noports tech, which we previously solved with an ssh
tunnel. Since we have made this obsolete, we are working on some changes which 
will eliminate the need to generate ephemeral ssh keys, and thus eliminate our 
dependency on ssh-keygen altogether.

## How to build this

The normal way to build this project is with cmake.
You can install cmake through most package managers, or through python's pip.

```bash
cd packages/c/sshnpd
cmake -B build -S .
cmake --build build
```

The sshnpd binary will then be located at `./build/sshnpd`.

## Dependencies

All of the dependencies we are using are automatically installed through cmake.

They are as follows:

1. atsdk (targets: atclient atchops atlogger)
  - the main sdk used to build noports
2. argparse (targets: argparse-static)
  - stored in `../3rdparty/argparse/`
3. srv (targets: srv-lib)
  - stored in `../srv/`
4. mbedtls (targets: mbedtls mbedx509 mbedcrypto everest p256m)
  - transitive dependency of atsdk::atchops
5. cjson (targets: cjson)
  - transitive dependency of atsdk::atclient
6. uuid4 (targets: uuid4-static)
  - transitive dependency of atsdk::atchops

