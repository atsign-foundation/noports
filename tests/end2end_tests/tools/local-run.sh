#!/bin/bash

FULL_PATH_TO_SCRIPT="$(realpath "${BASH_SOURCE[0]}")"
SCRIPT_DIRECTORY="$(dirname "$FULL_PATH_TO_SCRIPT")"
PROJECT_ROOT="$SCRIPT_DIRECTORY/../../.."

act \
-W "$PROJECT_ROOT/.github/workflows/end2end_tests.yaml" \
-j e2e_test \
--env-file "$SCRIPT_DIRECTORY/.env" \
--secret-file "$SCRIPT_DIRECTORY/.secrets" \
"$@"
