
These scripts are for setting up the contexts for the Docker images.

- `setup-*-entrypoint.sh` - sets up the entrypoints by copying from `templates/` then putting it into the appropriate folder. pass in arguments to this script and it will use `sed` to replace the appropriate variables in the template.
- `setup-*-keys.sh` - meant to be used locally, copies from `~/.atsign/keys` and moves them to the appropriate context directory.