# Bash Installer

A look behind the scenes of the bash installers for sshnp and sshnpd.

## Shared

### Release Format

Releases are contained in a zip file on macOS and tgz on linux.
macOS releases have all binaries notarized.

Binaries included in the release:
- at_activate
- sshnp
- sshnpd
- sshrv
- sshrvd


```
archive root
├── LICENSE
├── <binaries>
└── templates
    └── ...
```

### Sourcing binaries

Both sshnp and sshnp source their binaries similarly. By default they both will
download to ~/.atsign/temp. With sshnpd generating a subfolder within to
download to (i.e. ~/.atsign/temp/unique-subfolder).

The options `-r` and `-l` alter the default source behaviour. `-r` or
`--repo` accepts the root of the repo to be passed in, and instead the installer
will build the binaries from source (still placing them into the temp folder).

`-l` or `--local` accepts a path to a release archive which is then
unarchived by the installer and used to source the binaries. The installer
expects that the archive file matches the release format mentioned above.


