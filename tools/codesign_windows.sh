#!/usr/bin/env bash

# This file is a wrapper around Windows' signtool
# Due to the fact that there are a ton of special symbols in the command
# invocation, I've put this very particular wrapper in place to ensure that
# signing is done correctly.

# This file should be sourced into GitHub actions

sign_file() {
  eval "\"$WINDOWS_SIGNTOOL_PATH\" sign $WINDOWS_SIGNTOOL_ARGS \"$1\""
}
