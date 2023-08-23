# How Installation Works

Installation spec for sshnp and sshnpd.

Note: throughout this document anywhere referred to as the daemon side is where
sshnpd is installed, and anywhere referred to as the client side is where sshnp
is installed.

## Shared

### Directories

Each of the following directories in this document are significant and have
their own "nickname" used to reference them.

#### sshnp (~/.sshnp)

For both the client and daemon, this directory contains the local storage
required to run the atClient used by sshnp and sshnpd, each subdirectory in this
directory is named after the atSign for the particular atClient. For the client
side, there is another layer of subdirectories which indexes the storage for
each session created.

On the daemon side, the storage will be contained at ~/.sshnp/storage.
On the client side, the storage will be contained at ~/.sshnp/\<client-id\>/storage

#### sshnp config (~/.sshnp/config)

Standard directory which contains the config files for sshnp (used by the GUI).

#### sshnpd (~/.sshnpd)

Stores non-atClient storage for the daemon side, including:
- logs
- service list file (.service_list)

#### temp (~/.atsign/temp)

A temporary folder used for downloading necessary assets used during the installation process.

#### keys (~/.atsign/keys)

Standard directory which stores the private encryption keys used for the atClient.

#### local bin (~/.local/bin)

Local directory which contains the built binaries and custom scripts.

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
download to the temp directory. With sshnpd generating a subfolder within to
download to (i.e. ~/.atsign/temp/unique-subfolder).

The options `-r` and `-l` alter the default source behaviour. `-r` or
`--repo` accepts the root of the repo to be passed in, and instead the installer
will build the binaries from source (still placing them into the temp folder).

`-l` or `--local` accepts a path to a release archive which is then
unarchived by the installer and used to source the binaries. The installer
expects that the archive file matches the release format mentioned above.

### Putting binaries in place

Binaries are simply copied from the temp directory over to the local bin
(~/.local/bin) directory. It's recommended that this directory is included in
the PATH.

#### Custom binaries and templates



#### Custom services and templates


### Daemon background service/startup

#### Restarting the daemon

#### Killing the daemon

### Config Files

### Docker Hub Version

#### sshnpd image

#### activate_sshnpd image

### end2end test assembly

### sshnpd advanced

#### How to pass additional args at install time

#### How to rename a device
