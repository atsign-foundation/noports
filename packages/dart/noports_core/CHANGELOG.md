# 5.0.4

- refactor: move the `findLocalPortIfRequired` function to `EphemeralPortBinder`, a mixin on `SshnpCore`
- fix: call `callFindLocalPortIfRequired` during the initialization of the unsigned sshnp client

# 5.0.3
- feat: Add `--storage-path` option to sshnpd to allow users to specify where 
  it keeps any locally stored data

# 5.0.2

- fix: Add more supported ssh public key types to the send ssh public key filters for sshnpd.

# 5.0.1

- fix: Add more supported ssh public key types to the send ssh public key filters for sshnp.

# 5.0.0

- **BREAKING CHANGE** fix: changed `list-devices` arg from String option to boolean flag.

# 4.0.1

- fix(Pure Dart SSH client): send a keep alive to the server to prevent SSHAuthAbortError

# 4.0.0

- Initial release