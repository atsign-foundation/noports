#!/bin/bash

FULL_PATH_TO_SCRIPT="$(realpath "${BASH_SOURCE[0]}")"
SCRIPT_DIRECTORY="$(dirname "$FULL_PATH_TO_SCRIPT")"
PROJECT_ROOT="$SCRIPT_DIRECTORY/../.."

DOCKER_HOST="$(docker context inspect -f '{{.Endpoints.docker.Host}}')"
env DOCKER_HOST="$DOCKER_HOST" \
act \
-W "$PROJECT_ROOT/.github/workflows/end2end_tests.yaml" \
-j e2e_test \
--env-file "$SCRIPT_DIRECTORY/.env" \
--secret-file "$SCRIPT_DIRECTORY/.secrets" \
--bind \
--matrix np:local \
--matrix npd:local \
"$@"
