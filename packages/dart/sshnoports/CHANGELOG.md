# NoPorts changelog

<!-- pyml disable md034-->

## v5.15.1

* fix: Trust our brew tap when used with brew => 6
* feat: Container detection, Use tarball for headless install

## v5.15.0

* feat: auto select best RV
* fix: Better handling of sudo for universal.sh

## v5.14.13

* feat: sshnpd doctor by @LilianGRD
* ci: Codesign most deeply nested binary first and add np_admin

## v5.14.12

* feat: npp.dart
* feat: npp_client.dart

## v5.14.11

* build: add another copy of windows msi, without the version number in the filename

## v5.14.10

* feat: Update universal.sh to use packages where possible.

## v5.14.9

* build: Ensure noports binary is packaged
* fix: noports cli now accepts --version
* ci: Add trigger for homebrew-tap

## v5.14.8

* ci: Workflow to trigger update of apt and rpm repos

## v5.14.7

* build: Create .deb and .rpm packages
* docs: Add CHANGELOG.md
* feat: remove caching of public key client side in npt and sshnp
* feat: npt, srv, srvd, sshnp, sshnpd --version
* feat: next iteration of policy "npp"
* fix: Ensure SBOM tags are unique
* fix(actions): explicitly declare wix versions
* fix: shell startup script error with arguments
* fix: allow policy default value to fallthrough

## v5.14.6

* fix: Ensure correct token permission for signing images
* fix(noports_core): fix breaking changes from at_commons 5.8.0
* ci: Workflow to keep windows-signer self hosted runner alive
* feat: Noports CLI implementation
* chore: update sshnoports version to 5.14.6
* chore: update noports_core to 6.10.5 and dart run melos bootstrap

## v5.14.5

* fix: reduce npt control channel heartbeat interval from 30m to 5m
* fix: found and wrapped failed notification with a try block

## v5.14.4

* fix: fixed edge case where daemons could become unresponsive after persistent
  adverse network conditions
* feat: NoPorts Desktop. Automatic open of URI if selected after connection
  established
* fix: create default tool tip on tray Icon
* fix: Tool Tray behavior fixed on Windows and settings window now opens when
  click from tool tray

## v5.14.3

* fix: In the RelayAuthVerifiers, handle all exceptions the same way, so none
  are uncaught within an isolate
* fix: Fixed UI issues in NoPorts Desktop
* fix: Update appName in EnrollmentRequest to use Constants.namespace.
* fix: noports desktop switching atsigns refreshes authorisation and policy
  screen.
* fix: disable background when enrolling

## v5.14.2

* feat(noports): Enable redundancy support for Policy Servers
* feat: sshnpd: 'inline' srv execution, 'strict' mode, notification pre-
  processing
* fix: always do policy check even if policy atSign is same as client atSign
* feat: add `--help` flag to srv, and some additional usage info
* feat: Noports session logging
* fix(windows): high cpu usage in windows service
* feat: add `debug` flag to noports daemon
* fix: remove `late` from AtEventConfig?
* fix: Fix bug where sshnpd could become unresponsive when using proxy service
* fix: `*:*` for permit-open NoPorts Desktop UI
* fix: pick up version of at_server_status which has been patched to work with
  atServer proxy services
* fix: have desktop app emit notifications with same namespaces as the np_admin
  service does
* fix: policy cache on edit/save
* docs: update changelog for Desktop app release 1.7.0+24
* build: noports_core: update pubspec and changelog for release 6.9.0
* feat(noports): consume at_client v3.9.2 to enable redundancy support for
  Policy Servers
* ci: Ensure cosign binary is in place
* chore: remove old windows installer
* feat: windows-msi certupdater script
* docs: How to verify SLSA and image signing
* chore: remove legacy installers and update windows readme
* ci: Complete ps1 removal
* feat: sshnpd: 'inline' srv execution, 'strict' mode, notification pre-
  processing
* fix: always do policy check even if policy atSign is same as client atSign
* feat: add `--help` flag to srv, and some additional usage info
* fix: srvd.dart respects ENABLE_SNOOP environment variable
* feat: support to run multiple Policy Servers at the same time
* feat: noPorts desktop allow IPv6 numeric entries
* feat: Noports session logging
* chore: prepare for v5.14.0 release
* fix(windows): high cpu usage in windows service
* feat: add `debug` flag to noports daemon
* fix: remove `late` from AtEventConfig?
* build: release 5.14.1

## v5.14.1

* feat(noports): Enable redundancy support for Policy Servers
* feat: sshnpd: 'inline' srv execution, 'strict' mode, notification pre-
  processing
* fix: always do policy check even if policy atSign is same as client atSign
* feat: add `--help` flag to srv, and some additional usage info
* feat: Noports session logging
* fix(windows): high cpu usage in windows service
* feat: add `debug` flag to noports daemon
* fix: remove `late` from AtEventConfig?
* fix: `*:*` for permit-open NoPorts Desktop UI
* fix: pick up version of at_server_status which has been patched to work with
  atServer proxy services
* fix: have desktop app emit notifications with same namespaces as the np_admin
  service does
* fix: policy cache on edit/save
* docs: update changelog for Desktop app release 1.7.0+24
* build: noports_core: update pubspec and changelog for release 6.9.0
* feat(noports): consume at_client v3.9.2 to enable redundancy support for
  Policy Servers
* ci: Ensure cosign binary is in place
* chore: remove old windows installer
* feat: windows-msi certupdater script
* docs: How to verify SLSA and image signing
* chore: remove legacy installers and update windows readme
* ci: Complete ps1 removal
* feat: sshnpd: 'inline' srv execution, 'strict' mode, notification pre-
  processing
* fix: always do policy check even if policy atSign is same as client atSign
* feat: add `--help` flag to srv, and some additional usage info
* fix: srvd.dart respects ENABLE_SNOOP environment variable
* feat: support to run multiple Policy Servers at the same time
* feat: noPorts desktop allow IPv6 numeric entries
* feat: Noports session logging
* chore: prepare for v5.14.0 release
* fix(windows): high cpu usage in windows service
* feat: add `debug` flag to noports daemon
* fix: remove `late` from AtEventConfig?
* build: release 5.14.1

## v5.14.0

* fix: `*:*` for permit-open NoPorts Desktop UI
* fix: pick up version of at_server_status which has been patched to work with
  atServer proxy services
* fix: have desktop app emit notifications with same namespaces as the np_admin
  service does
* fix: policy cache on edit/save
* docs: update changelog for Desktop app release 1.7.0+24
* build: noports_core: update pubspec and changelog for release 6.9.0
* feat(noports): consume at_client v3.9.2 to enable redundancy support for
  Policy Servers
* ci: Ensure cosign binary is in place
* chore: remove old windows installer
* feat: windows-msi certupdater script
* docs: How to verify SLSA and image signing
* chore: remove legacy installers and update windows readme
* ci: Complete ps1 removal
* feat: sshnpd: 'inline' srv execution, 'strict' mode, notification pre-
  processing
* fix: always do policy check even if policy atSign is same as client atSign
* feat: add `--help` flag to srv, and some additional usage info
* fix: srvd.dart respects ENABLE_SNOOP environment variable
* feat: support to run multiple Policy Servers at the same time
* feat: noPorts desktop allow IPv6 numeric entries
* feat: Noports session logging
* chore: prepare for v5.14.0 release

## v5.13.0

* feat: policy server heartbeat + noports desktop status light
* chore: `pinController.text.toUpperCase()`
* feat: proxy support for `npt_flutter`
* fix: npt_flutter read the correct heartbeat key namespace and unify the
  heartbeat rpc notifications to use `sshnp` namespace
* feat: `useRemoteAtServer:true` in `atClient.getKeys`
* fix: policy status light and npp_atserver time synchronization
* chore: update version to 1.6.2+21 and remove policy status light and …
* fix: use KillMode=process for sshnpd.service
* feat: Consume atkeys pass-phrase changes in noports
* feat: sshnpd config file support using config package
* feat(tools): introduce windows-msi as new installation method on windows
* fix(windows-msi): fix config and event viewer errors
* fix(windows-msi): config wasn't being placed in ProgramData and service
  install was trying to start
* fix: pick up bug fix to at_client_mobile.KeyChainManager
* feat: windows codesign
* docs: Correct repo name
* docs: CHANGELOG.md 1.6.0+19 and 1.6.1+20
* chore: update version to 1.6.1+20 and msix_version to 1.6.1.0
* ci: Add Docker image signing and more SLSA
* fix: Permissions for combine images step
* fix: Remove SLSA for workflow
* build: unset `engine-strict=true` so that dependabot can run to completion
* ci: Add SLSA to images
* docs: Link to public sbomified profile
* chore: update version to 1.6.3+22 and change log.
* @srieteja made their first contribution in https://github.com/atsign-
  foundation/noports/pull/2207

## v5.12.1

* feat: standardize our binaries with `--root-server`
* feat: add `--license-key` alias for `cramkey` when running `at_activate
  onboard`
* feat: add a warning message before onboarding attempts to cut keys that
  presents a message explaining importance of backing up keys and prompting the
  user asking if they understand the risks of not backing up keys
* made it so that passing `--cramkey` (or `--license-key`) to the `onboard`
  command will skip the warning message inherently
* add a `--yes` | `-y` flag to the `onboard` command to skip this warning
  message
* Added proxy support for: `at_activate onboard --rootServer
  proxy:<host>:<port>`
* Added proxy support for: `at_activate enroll --rootServer proxy:<host>:<port>`
* feat: add `--root-server` option to specify root server domain (alias for
  backwards compatibility: `--root-domain`)
* feat: created mutex for sshnpd for load balancing/redundancy etc
* feat: Added --local-host <IP/FQDN> to NPT
* chore: Consistent use of debian:stable-{DATE}-slim
* fix: Use -p flag for mkdir
* chore: Ensure addgroup command is available
* test: added unit test for profile.dart.
* chore: Ensure addgroup is in place for Trixie based Dart images
* ci: Switch from go install to GitHub Action for osv-scanner
* fix(npt_flutter): support flutter stable 3.35.1
* build: upgrade at_commons dependency to 5.6.1; more osv scanning
* docs: Add sbomify badge
* feat: Add SBOM using Conan lock file
* fix: Move checkout to before download
* ci: Add COMPONENT_NAME of csshnpd to SBOM
* feat: npt_flutter basic policy + ui top bar + 443 checkbox in profile edit
  form
* feat: NoPorts Desktop keep alive checkbox
* build: run dart run build_runner build during CI
* build: update version.dart in sshnoports and noports_core for release
* docs(automated): Update docs from Gitbook
* docs(automated): Update docs from Gitbook
* fix: linux build for NoPorts desktop

## v5.12.0

* feat: standardize our binaries with `--root-server`
* feat: created mutex for sshnpd for load balancing/redundancy etc
* feat: Added --local-host <IP/FQDN> to NPT
* chore: Consistent use of debian:stable-{DATE}-slim
* fix: Use -p flag for mkdir
* chore: Ensure addgroup command is available
* test: added unit test for profile.dart.
* chore: Ensure addgroup is in place for Trixie based Dart images
* ci: Switch from go install to GitHub Action for osv-scanner
* fix(npt_flutter): support flutter stable 3.35.1
* build: upgrade at_commons dependency to 5.6.1; more osv scanning
* docs: Add sbomify badge
* feat: Add SBOM using Conan lock file
* fix: Move checkout to before download
* ci: Add COMPONENT_NAME of csshnpd to SBOM
* feat: npt_flutter basic policy + ui top bar + 443 checkbox in profile edit
  form
* feat: NoPorts Desktop keep alive checkbox
* build: run dart run build_runner build during CI
* build: update version.dart in sshnoports and noports_core for release
* docs(automated): Update docs from Gitbook
* docs(automated): Update docs from Gitbook
* fix: linux build for NoPorts desktop

## v5.11.2

* feat: Enable daemons and policy service to use the same atSign
* feat: add `--help` flag to the sshnpd binary
* feat: twin keys for control socket and data sockets
* feat: Have npt send a heartbeat over the npt control socket. These heartbeats
  are intended to let zealous network intermediaries know that the npt control
  socket is not dead
* feat: Allow clients (npt, sshnp, noports desktop app, etc.) to request the use
  of port 443 on the relay for this session, rather than a pair of random ports
* feat: New & stronger authentication (ESCR - Encrypted Signed Challenge
  Response) of new socket connections to the relay, eliminating potential for
  replay attacks
* fix: make sure ~/.ssh is owned by the user
* fix: better srvd exception handling
* feat: improve time-to-session

## v5.11.1

* feat: Enable daemons and policy service to use the same atSign
* feat: add `--help` flag to the sshnpd binary
* feat: twin keys for control socket and data sockets
* feat: Have npt send a heartbeat over the npt control socket. These heartbeats
  are intended to let zealous network intermediaries know that the npt control
  socket is not dead
* feat: Allow clients (npt, sshnp, noports desktop app, etc.) to request the use
  of port 443 on the relay for this session, rather than a pair of random ports
* feat: New & stronger authentication (ESCR - Encrypted Signed Challenge
  Response) of new socket connections to the relay, eliminating potential for
  replay attacks
* fix: make sure ~/.ssh is owned by the user
* fix: better srvd exception handling

## v5.11.0

* fix: Enable daemons and policy service to use the same atSign
* feat: add `--help` flag to the sshnpd binary
* feat: twin keys for control socket and data sockets
* feat: Have npt send a heartbeat over the npt control socket. These heartbeats
  are intended to let zealous network intermediaries know that the npt control
  socket is not dead
* feat: Allow clients (npt, sshnp, noports desktop app, etc.) to request the use
  of port 443 on the relay for this session, rather than a pair of random ports
* feat: New & stronger authentication (ESCR - Encrypted Signed Challenge
  Response) of new socket connections to the relay, eliminating potential for
  replay attacks

## v5.10.0

* feat: Have npt send a heartbeat over the npt control socket. These heartbeats
  are intended to let zealous network intermediaries know that the npt control
  socket is not dead
* feat: Allow clients (npt, sshnp, noports desktop app, etc.) to request the use
  of port 443 on the relay for this session, rather than a pair of random ports
* feat: New & stronger authentication (ESCR - Encrypted Signed Challenge
  Response) of new socket connections to the relay, eliminating potential for
  replay attacks

## v5.9.4

* fix: Ensure at_activate is on PATH and that it writes to correct dir

## v5.9.3

* fix: ensure srvd always handles resets properly
* feat: srvd: default `per-session-storage` to true

## v5.9.2

* fix: universal sh
* fix: policy admin webapp: fix main.js to work with svelte 5
* feat: better feedback to users from the activate CLI

## v5.9.1

* feat: Added Dockerfiles for sshnp and npt then updated automation to update
  dockerhub containers on release
* fix: Have relays bind ports before locking the response mutex
* fix: device name help in sshnpd

## v5.9.0

* feat: enable load balancing across multiple NoPorts relay services for a given
  relay atSign in https://github.com/atsign-foundation/noports/pull/1796
* build: Update various atPlatform dependencies to pick up other fixes /
  enhancements (at_client 3.4.1, at_cli_commons 2.0.0, at_onboarding_cli 1.8.3,
  at_auth 2.1.0, at_lookup 3.0.51, at_commons 5.3.0)

## v5.8.7

* feat(breaking): at_activate interface for C
* ci: Update to build and package at_activate binary
* fix: always try to create systemd conf dir

## v5.8.6

* ci: Workaround for armv7 on arm64 runners

## v5.8.5

* ci: Move armv7 build back to x64 runner

## v5.8.4

* ci: Reinstantiate riscv64 build (using Arm runner)
* ci: Use arm runner for arm64 and armv7 images

## v5.8.3

* Maintenance and dependency updates.

## v5.8.2

* fix: fresh install universal.sh systemd

## v5.8.1

* fix: Typos and UI issues addressed.
* fix: stable monitor connections in c sshnpd
* chore: version number updated and dependency overrides added fot meta.
* feat: add activate_cli and executables
* chore: update atsdk version
* chore: update dependencies

## v5.8.0

* Maintenance and dependency updates.

## v5.7.0

* A simple NoPorts policy service `npp_atserver`
* An API to manage NoPorts policy rules `npp_admin`
* A web UI which uses the API (bundled with `npp_admin`)
* Full documentation is being created
  [here](https://docs.noports.com/reference/policy)
* fix: fix issues which would occur when a large number of sockets are created
  concurrently in https://github.com/atsign-foundation/noports/pull/1509
* This change greatly improves the stability of http/https pages which load a
  large number of assets very quickly.
* With this change, using web applications over a bare noports tunnel should be
  suitable for nearly all use-cases.
* fix: Use `restart` (rather than `start`) for systemd service in
  https://github.com/atsign-foundation/noports/pull/1409
* feat: Better defaults for sshnpd's --permit-open in https://github.com/atsign-
  foundation/noports/pull/1353
* fix: Ensure npt rejects malformed atSign args in https://github.com/atsign-
  foundation/noports/pull/1332
* feat: use SshnpRequest class and validate against permissions in
  https://github.com/atsign-foundation/noports/pull/1381
* fix: Add no-encrypt-traffic option to npt in https://github.com/atsign-
  foundation/noports/pull/1401
* Can be useful for test rigs. Should _not_ be used for production.
* fix: allow leading underscore in device name in https://github.com/atsign-
  foundation/noports/pull/1427
* fix: Fix the regular expression for the daemon's notification subscription in
  https://github.com/atsign-foundation/noports/pull/1557
* ci: Replace Syft with sbomify in https://github.com/atsign-
  foundation/noports/pull/1536
* ci: Refactor web admin to separate noarch job in https://github.com/atsign-
  foundation/noports/pull/1553
* The release notes above summarize the changes for the scripts / binaries / etc
  available via this releases' assets.
* In the full change log below, there are many other changes
* Changes to the C implementation will be included once the C daemon is GA
* Changes to the NoPorts Desktop app will be covered in the NoPorts Desktop's
  release notes.

## v5.7.0-alpha-8

* docs(automated): Update docs from Gitbook
* chore: Greater consistency in spacing and formatting of options
* ci: Replace Syft with sbomify
* ci: Don't always cleanup
* ci: Refactor web admin to separate noarch job

## v5.7.0-alpha-7

* fix: fix issues seen in "multi" mode when a large number of sockets are
  created concurrently
* build: update policy admin api pubspec.lock
* build: exclude policy admin webapp assets from the docker distributions
* build: multibuild.yaml: Exclude riscv64 from other_build's platform list

## v5.7.0-alpha-6

* fix: np admin static serving
* feat: use the `AtRpc.allowAll` flag introduced by at_client version 3.2.0
* fix: profile screen and all other screens associated with the profile screen
  updated to the Figma design.
* chore: use git dependency instead of path

## v5.7.0-alpha-5

* ci: policy docker build
* fix: don't include dist in path
* fix: remove link from dockerfile
* feat: policy service beta

## v5.6.1

* fix: handle chmod errors in dart
* fix: more time for npt control socket creation
* fix: (i) fix race condition in daemon-side multi srv; (ii) add `\n` separator
  to npt control messages
* fix: use wrapped chown method in all places
* ci: parallel e2e tests
* docs: Update Readme
* test: Add unit tests
* fix: e2e tests crashing
* fix: When running npt in keep-alive mode then the keep-alive loop should never
  exit due to an exception from `npt.run()`
* test: Add unit test related to sshnpd
* feat:  adding activation inside universal.sh
* fix: ensure NptImpl's `preRun` is being executed only once when npt cli is run
  without the `-x` flag

## v5.5.0

* ci: skip e2e only docs
* docs(automated): Update docs from Gitbook
* feat: npt: added 'keep-alive' flag, and an adjustable session timeout
* fix: ensure directories we create as root are chown-ered to user

## v5.4.0

* feat: C daemon
* docs: Put copy of LICENSE in repo root
* ci: Add cppcheck for static analysis of C packages
* feat: [c daemon] verify_envelope_signature
* feat: powershell installation script
* fix: add universal.ps1 to multibuild.yaml
* fix: include .ps1 for signing
* fix: make sure necessary directories exist
* fix: C SSHNPD memory leaks before SSH connection established
* fix: use correct arch in multibuild.yaml
* feat: quiet mode (-q | --quiet) + sshd check
* fix: skipping macOS related tasks due to name change
* fix: remove duplicate os' in our build matrix
* @realvarx made their first contribution in https://github.com/atsign-
  foundation/noports/pull/1120

## v5.3.0

* This version changes the default storage location which was previously
  `$HOME/.sshnp`, so this directory is no longer generated when it should be.
  The patch for this bug is already included in the next release (v5.4.0 - a
  pre-release version as of writing this).
* Before installing, run this command:
* fix: Update terminal fontstyle and size
* feat: Key Bindings to navigate between terminal tabs and change terminal font
  size
* fix: 902 noports desktop enhancements v4
* fix: locked up session can now be closed
* fix: Multibuild workflow notifications
* docs(automated): Update docs from Gitbook
* fix: tweak buildBinaries for consistency
* docs(automated): Update docs from Gitbook
* docs(automated): Update docs from Gitbook
* feat: Add check for keys in .ssh
* chore: Consolidate dependabot directories
* docs(automated): Update docs from Gitbook
* docs(automated): Update docs from Gitbook
* feat: feedback email added to support screen
* feat: sshpublickey permissions
* feat: More robust downloading
* feat: No ports desktop 1.0.0+5
* fix: urgent patch on python sshnpd
* fix: python sshnpd threading issue
* chore: cleanup unused dependencies in sshnpdpy
* docs: Fix double logo on PyPI
* fix: Working directory for PyPI README diff
* docs: Update README with more detailed instructions
* fix: Working directory for README generation
* fix: sshnp: various arg parsing issues
* ci: Add SBOMs and SLSA attestation to Dart and Python releases
* fix: make the user own local/bin with sudo
* build: use the trunk branch from the dartssh2 fork at
  https://github.com/atsign-foundation/dartssh2
* gkc: fix 1061
* test: Add e2e tests using APKAM keys
* feat: Update Data Plane Diagram
* fix: key management dialogs updated to allow text to scale based on d…
* fix: Ssh no ports desktop 1.0.0+6
* feat: add --quiet flag to the sshnp and npt CLIs
* feat: make daemon storage location map to its device name
* fix: Added default value for bin/srv's `local-host` option
* fix: snake case validation for device name
* feat: set a 1-minute ttln (notification time-to-live)
* feat: No double ssh when sockets encrypted
* @TylerTrott made their first contribution in https://github.com/atsign-
  foundation/noports/pull/1069

## v5.2.1-rc1

* SBOMs and SLSA

## v5.2.0

* Policy plane for delegated authorization
* Fixes and improvements to universal.sh installer
* fix: the rest of universal installer
* chore: remove legacy scripts
* chore: add slim build to promote script
* docs(automated): Update docs from Gitbook
* fix: sudo suggest
* ci: build sshnpd for windows
* ci: run unit_tests on release branches
* feat: install srv as part of the client installation process
* feat: Include allowed services in ping
* feat(sshnpd): deprecate -u in favor of -h
* ci: Release automation
* ci: Automate tagging of latest releases
* docs(automated): Update docs from Gitbook
* chore: deprecate -h, only -f needed for list-devices
* feat: NoPorts policy plane aka delegated authorization
* fix: srv binary missing message, add more detail
* fix: a bunch of small universal.sh bugs
* fix: Correct prefix for temp branch
* fix: Ownership should be applied to .atsign rather than keys subdirectory

## v5.2.0-rc1

* fix: the rest of universal installer
* chore: remove legacy scripts
* chore: add slim build to promote script
* docs(automated): Update docs from Gitbook
* fix: sudo suggest
* ci: build sshnpd for windows
* ci: run unit_tests on release branches
* feat: install srv as part of the client installation process
* feat: Include allowed services in ping
* feat(sshnpd): deprecate -u in favor of -h
* ci: Release automation
* ci: Automate tagging of latest releases
* docs(automated): Update docs from Gitbook
* chore: deprecate -h, only -f needed for list-devices
* feat: NoPorts policy plane aka delegated authorization
* fix: srv binary missing message, add more detail
* fix: a bunch of small universal.sh bugs

## v5.1.1-rc.1

* fix: the rest of universal installer
* chore: remove legacy scripts
* chore: add slim build to promote script
* docs(automated): Update docs from Gitbook
* fix: sudo suggest

## v5.1.0

* Added npt (No Ports tunnel) client which allows the creation of a No Ports tcp
  tunnel without ssh.
* New universal.sh installer for macos and linux included with the release (docs
  will be available on docs.noports.com soon)
* This new installer will help guide you through installing no ports for either
  client, device or both
* The client will also have an ease of use script called np.sh, which will be
  installed to `$HOME/.local/bin`
* chore: added msix config
* chore: Release v5.0.2
* fix: profiles are refreshed when first sync after onboarding is completed
* fix: bool fields remains the value the user selected
* docs(automated): Update docs from Gitbook
* 776 onboarding widget too large for the minimum desktop size
* Sshnp gui with composition
* docs(automated): Update docs from Gitbook
* chore: improve installer config documentation
* fix: dependency hell
* feat: have the daemon support multiple manager atSigns
* chore: show the correct params in the config file
* docs(automated): Update docs from Gitbook
* feat: updated faq.md
* docs(automated): Update docs from Gitbook
* feat: create slim version of sshnpd docker container that connects to hosts
  sshd
* feat: npt (NoPorts Tunnel) - noports but without ssh
* build: update socket_connector dependency to published version 2.1.0
* docs(automated): Update docs from Gitbook
* docs(automated): Update docs from Gitbook
* docs(automated): Update docs from Gitbook
* docs: Update README.md logo
* docs: Update README.md logo
* fix: Correct handling of mixed-case device names
* fix: testing feedback fixes implemented
* fix: 786 no ports desktop enhancements
* ci: ensure that dependencies are being properly kept up to date
* docs(automated): Update docs from Gitbook
* fix: No port desktop 1.0.0+4
* docs(automated): Update docs from Gitbook
* test: e2e tests iteration 2
* feat: npt: use different session keys for each socket pair
* ci: universal.sh tagged version build output
* feat: universal versioned installer
* test: fix flaking e2e test (DRAFT)
* feat: Updated bundle file to mention comma separated list of atsigns …
* docs: Link scorecard badge to viewer
* @sachins-geekyants made their first contribution in https://github.com/atsign-
  foundation/noports/pull/698
* @jenmonroe made their first contribution in https://github.com/atsign-
  foundation/noports/pull/810

## v5.1.0-rc.11

* chore: added msix config
* chore: Release v5.0.2
* fix: profiles are refreshed when first sync after onboarding is completed
* fix: bool fields remains the value the user selected
* docs(automated): Update docs from Gitbook
* 776 onboarding widget too large for the minimum desktop size
* Sshnp gui with composition
* docs(automated): Update docs from Gitbook
* chore: improve installer config documentation
* fix: dependency hell
* feat: have the daemon support multiple manager atSigns
* chore: show the correct params in the config file
* docs(automated): Update docs from Gitbook
* feat: updated faq.md
* docs(automated): Update docs from Gitbook
* feat: create slim version of sshnpd docker container that connects to hosts
  sshd
* feat: npt (NoPorts Tunnel) - noports but without ssh
* build: update socket_connector dependency to published version 2.1.0
* docs(automated): Update docs from Gitbook
* docs(automated): Update docs from Gitbook
* docs(automated): Update docs from Gitbook
* docs: Update README.md logo
* docs: Update README.md logo
* fix: Correct handling of mixed-case device names
* fix: testing feedback fixes implemented
* fix: 786 no ports desktop enhancements
* ci: ensure that dependencies are being properly kept up to date
* docs(automated): Update docs from Gitbook
* fix: No port desktop 1.0.0+4
* docs(automated): Update docs from Gitbook
* test: e2e tests iteration 2
* feat: npt: use different session keys for each socket pair
* ci: universal.sh tagged version build output
* feat: universal versioned installer
* test: fix flaking e2e test (DRAFT)
* feat: Updated bundle file to mention comma separated list of atsigns …
* @sachins-geekyants made their first contribution in https://github.com/atsign-
  foundation/noports/pull/698
* @jenmonroe made their first contribution in https://github.com/atsign-
  foundation/noports/pull/810

## v5.1.0-rc.9

* chore: added msix config
* chore: Release v5.0.2
* fix: profiles are refreshed when first sync after onboarding is completed
* fix: bool fields remains the value the user selected
* docs(automated): Update docs from Gitbook
* 776 onboarding widget too large for the minimum desktop size
* Sshnp gui with composition
* docs(automated): Update docs from Gitbook
* chore: improve installer config documentation
* fix: dependency hell
* feat: have the daemon support multiple manager atSigns
* chore: show the correct params in the config file
* docs(automated): Update docs from Gitbook
* feat: updated faq.md
* docs(automated): Update docs from Gitbook
* feat: create slim version of sshnpd docker container that connects to hosts
  sshd
* feat: npt (NoPorts Tunnel) - noports but without ssh
* build: update socket_connector dependency to published version 2.1.0
* docs(automated): Update docs from Gitbook
* docs(automated): Update docs from Gitbook
* docs(automated): Update docs from Gitbook
* docs: Update README.md logo
* docs: Update README.md logo
* fix: Correct handling of mixed-case device names
* fix: testing feedback fixes implemented
* fix: 786 no ports desktop enhancements
* ci: ensure that dependencies are being properly kept up to date
* docs(automated): Update docs from Gitbook
* fix: No port desktop 1.0.0+4
* docs(automated): Update docs from Gitbook
* test: e2e tests iteration 2
* feat: npt: use different session keys for each socket pair
* ci: universal.sh tagged version build output
* feat: universal versioned installer
* test: fix flaking e2e test (DRAFT)
* feat: Updated bundle file to mention comma separated list of atsigns …
* @sachins-geekyants made their first contribution in https://github.com/atsign-
  foundation/noports/pull/698
* @jenmonroe made their first contribution in https://github.com/atsign-
  foundation/noports/pull/810

## v5.1.0-rc.8

* chore: added msix config
* chore: Release v5.0.2
* fix: profiles are refreshed when first sync after onboarding is completed
* fix: bool fields remains the value the user selected
* docs(automated): Update docs from Gitbook
* 776 onboarding widget too large for the minimum desktop size
* Sshnp gui with composition
* docs(automated): Update docs from Gitbook
* chore: improve installer config documentation
* fix: dependency hell
* feat: have the daemon support multiple manager atSigns
* chore: show the correct params in the config file
* docs(automated): Update docs from Gitbook
* feat: updated faq.md
* docs(automated): Update docs from Gitbook
* feat: create slim version of sshnpd docker container that connects to hosts
  sshd
* feat: npt (NoPorts Tunnel) - noports but without ssh
* build: update socket_connector dependency to published version 2.1.0
* docs(automated): Update docs from Gitbook
* docs(automated): Update docs from Gitbook
* docs(automated): Update docs from Gitbook
* docs: Update README.md logo
* docs: Update README.md logo
* fix: Correct handling of mixed-case device names
* fix: testing feedback fixes implemented
* fix: 786 no ports desktop enhancements
* ci: ensure that dependencies are being properly kept up to date
* docs(automated): Update docs from Gitbook
* fix: No port desktop 1.0.0+4
* docs(automated): Update docs from Gitbook
* test: e2e tests iteration 2
* feat: npt: use different session keys for each socket pair
* ci: universal.sh tagged version build output
* feat: universal versioned installer
* test: fix flaking e2e test (DRAFT)
* feat: Updated bundle file to mention comma separated list of atsigns …
* @sachins-geekyants made their first contribution in https://github.com/atsign-
  foundation/noports/pull/698
* @jenmonroe made their first contribution in https://github.com/atsign-
  foundation/noports/pull/810

## v5.1.0-rc.6

* chore: added msix config
* chore: Release v5.0.2
* fix: profiles are refreshed when first sync after onboarding is completed
* fix: bool fields remains the value the user selected
* docs(automated): Update docs from Gitbook
* 776 onboarding widget too large for the minimum desktop size
* Sshnp gui with composition
* docs(automated): Update docs from Gitbook
* chore: improve installer config documentation
* fix: dependency hell
* feat: have the daemon support multiple manager atSigns
* chore: show the correct params in the config file
* docs(automated): Update docs from Gitbook
* feat: updated faq.md
* docs(automated): Update docs from Gitbook
* feat: create slim version of sshnpd docker container that connects to hosts
  sshd
* feat: npt (NoPorts Tunnel) - noports but without ssh
* build: update socket_connector dependency to published version 2.1.0
* docs(automated): Update docs from Gitbook
* docs(automated): Update docs from Gitbook
* docs(automated): Update docs from Gitbook
* docs: Update README.md logo
* docs: Update README.md logo
* fix: Correct handling of mixed-case device names
* fix: testing feedback fixes implemented
* fix: 786 no ports desktop enhancements
* ci: ensure that dependencies are being properly kept up to date
* docs(automated): Update docs from Gitbook
* fix: No port desktop 1.0.0+4
* docs(automated): Update docs from Gitbook
* test: e2e tests iteration 2
* feat: npt: use different session keys for each socket pair
* ci: universal.sh tagged version build output
* feat: universal versioned installer
* test: fix flaking e2e test (DRAFT)
* feat: Updated bundle file to mention comma separated list of atsigns …
* @sachins-geekyants made their first contribution in https://github.com/atsign-
  foundation/noports/pull/698
* @jenmonroe made their first contribution in https://github.com/atsign-
  foundation/noports/pull/810

## v5.1.0-rc.5

* chore: added msix config
* chore: Release v5.0.2
* fix: profiles are refreshed when first sync after onboarding is completed
* fix: bool fields remains the value the user selected
* docs(automated): Update docs from Gitbook
* 776 onboarding widget too large for the minimum desktop size
* Sshnp gui with composition
* docs(automated): Update docs from Gitbook
* chore: improve installer config documentation
* fix: dependency hell
* feat: have the daemon support multiple manager atSigns
* chore: show the correct params in the config file
* docs(automated): Update docs from Gitbook
* feat: updated faq.md
* docs(automated): Update docs from Gitbook
* feat: create slim version of sshnpd docker container that connects to hosts
  sshd
* feat: npt (NoPorts Tunnel) - noports but without ssh
* build: update socket_connector dependency to published version 2.1.0
* docs(automated): Update docs from Gitbook
* docs(automated): Update docs from Gitbook
* docs(automated): Update docs from Gitbook
* docs: Update README.md logo
* docs: Update README.md logo
* fix: Correct handling of mixed-case device names
* fix: testing feedback fixes implemented
* fix: 786 no ports desktop enhancements
* ci: ensure that dependencies are being properly kept up to date
* docs(automated): Update docs from Gitbook
* fix: No port desktop 1.0.0+4
* docs(automated): Update docs from Gitbook
* test: e2e tests iteration 2
* feat: npt: use different session keys for each socket pair
* ci: universal.sh tagged version build output
* @sachins-geekyants made their first contribution in https://github.com/atsign-
  foundation/noports/pull/698
* @jenmonroe made their first contribution in https://github.com/atsign-
  foundation/noports/pull/810

## v5.0.2

* docs(automated): Update docs from Gitbook
* fix: Handle problems caused by the tmux function in install.sh masking the
  tmux binary itself
* chore: Updated dependencies and fixed analyzer issues
* fix: remove sudoer assumption in install.sh; fix bugs in remove / rename part
  of install_single_binary
* 758 provide more useful messages in the UI when a session is being created
* docs(automated): Update docs from Gitbook
* ci: apple silicon builds + codesigning + notarization

## v5.0.1

* build: add srv.exe to windows tarball
* fix: ephemeral key management plus a few other fixes

## v5.0.0

* test: Added unit and widget test to SSHNP_GUI
* chore: socket-authenticator-option merge renames
* fix: artifact upload action
* feat: SSHNP Desktop App
* chore: qol install.sh
* fix: terminal session and private key issues
* fix: adjust src not dest for new root script
* chore: update app for release on test flight
* refactor(BREAKING CHANGE): Rename sshrv to srv
* feat(BREAKING CHANGE): add -x flag
* fix: x flag
* ci: allow local multi build
* feat: rv authentication and extra e2ee
* feat: add usageLineLength so terminal resizes usage correctly
* feat: v5 args tweaking
* fix: empty session and tunnel username are treated as null.
* fix: settings screen shows a grey box
* docs(automated): Update Gitbook docs
* docs(automated): Update docs from Gitbook
* feat: update pure dart variant for new features 1) rvd auth 2) encrypt rvd
  traffic
* ci: Restrict token permissions in gitbook workflow
* fix: profile form updated to two column layout
* feat: provide a way to listen to progress and logger messages
* fix: placeholder navigation destination and empty terminal nav destination
* fix: reset stdin linemode on exit
* fix: terminal can be closed if session is hung
* fix: windows initial ssh connection timeout code
* feat: make it possible to run multiple concurrent sshnp CLI processes
* chore: breaking arg changes to cli client
* fix: Allow windows bug (windows signal not monitored and delete of storage not
  possible)
* Corrected order of STDIO changes to keep WIndows 10 happy
* @atsignbot made their first contribution in https://github.com/atsign-
  foundation/noports/pull/729

## v4.0.5

* chore: Release v4.0.4
* ci: Initial version of build-publish workflow for python-sshnpd
* fix: Ensure dist files are placed for upload
* fix: Ensure dist files are placed for upload
* feat: sshnpd: add --storage-path option
* fix: sshnpd/rvd installer tweaks
* docs: Delete duplicated files by Gitbook
* chore: rename the repo to "noports"
* chore: organize packages
* fix: properly bind ephemeral port to localPort variable for unsigned …

## v4.0.4

* fix: check ssh public keys correctly
* fix: added correct checks to ssh public key checks

## v4.0.3

* fix: sometimes check if error is SshnpError before treating it like one
* fix: dart client authentication
* chore: Release v4.0.2
* fix: change list-devices back to flag type

## v4.0.2

* chore: remove latest from deprecation message in legacy install scripts
* feat: add new package-windows script
* chore: Release v4.0.0
* fix: don't dump stack trace when printing usage

## v4.0.1

* fix: sshnp no longer dumps it's stack trace when printing the usage
  information.

## v4.0.0

* `-U`, `--tunnel-user-name` - The user you are trying to connect as isn't
  always the same as the user running sshnpd, this option allows you to manually
  specify that username.
* `-P`, `--local-sshd-port` - The port that the local sshd is listening on
  (defaults to 22)
* `--remote-sshd-port` - The port that the remote sshd is listening on (defaults
  to 22)
* `--idle-timeout` - The timeout duration (in seconds) to wait before closing
  the initial tunnel session due to inactivity, this time can be adjusted to
  accomodate network latency (defaults to 15 seconds).
* `--legacy-daemon` - Connect to a v3 client using the legacy connection scheme.
* refactor: installers
* feat: implement direct ssh
* chore: Docker chores
* chore: Repo maintenance
* fix: sshnpd installer merge bug
* docs: move UnderTheHood.md to the root /docs
* fix: exit on any container != 0
* fix: add -s and -u to the e2e test installer sshnpd command
* fix: e2e tests
* feat: Add sshnp option for local sshd to run on alternative port than 22
* fix: small bug in params
* feat: Add support for GUI sshnp client
* chore: add new params to sshnp-config-template.env
* fix: remove old device info if a device is restarted with -u off
* feat: More Installer requirements checks
* chore: disable unreliable checks in sshnpd installer
* fix: sshnp -o flag should not prepend -o to the output option
* fix: sshnp result
* feat: SSHNPD Python
* deps: sshnoports sdk python configuration
* ci: E2e test improvements
* ci: Split e2e tests
* fix: allow ints as options in sshnp_params.dart
* fix: build_dart_binaries in install_sshnp
* chore: make empty string the default for the ssh public key instead of 'false'
* chore: various changes to get the gui app working
* fix: Fixed runtime error if running sshnp with invalid arguments (e.g. no
  arguments)
* ci: Verify tags before building
* docs: python sshnpd
* feat: Merge GUI MVP into trunk
* feat: SSHNP Params Controller
* refactor: fix volume paths
* docs: How installer works + Gitbook setup
* fix: integer parsing
* feat(gui): checkin 2023-09-07 changes
* ci: alternate local sshd port (-P) end-to-end test
* chore: Dependabot for sshnp_gui and Python SDK
* fix: send ssh public key
* fix: gui namespace
* feat: better thread management
* docs: ci docs
* Fix Overflow errors
* ci: allow dockerhub image name to be selected for promotion
* feat: sshnp pure dart for direct ssh
* fix: Dockerfile(s) location for Dependabot
* ci: dont run alternate port test on forks
* fix: Locations for pub and Docker were mixed up
* ci: improve sshnpd health check
* ci: alternate_port_test improvements and remove testing for v3.2.0
* fix: sshnpd: remove ephemeral public key from authorized_keys after 15 seconds
* ci: prod rvd tests
* ci: alternate_port_test, sshrvd healthcheck, prod_tests
* fix: manual tool volumes
* ci: prod tests fail-fast
* feat: sshnp gui core MVP
* fix: bug in thread cleanup for python sshnpd
* chore: tidying poetry and workflow stuff
* ci: retry prod test 3 times
* ci: fix false positives in end-to-end tests
* test: update sshnp_test unit tests with update expect values
* refactor: add noports_core package
* feat: Release v4.0.0 rc.6
* refactor: noports core
* refactor: Remove file system bindings
* feat: Release v4.0.0 rc.7
* fix: Make sshnpd.py executable
* ci: Restrict token permissions
* fix: Uptake notify ephemeral changes
* chore: upgrade dependencies for at_onboarding_cli 1.4.0
* refactor: SSHNPParams unit tests preparation
* feat: client side Windows support
* test: Mock tests for SshnpCore
* refactor: wrap all dart:io calls
* test: Unit tests for Sshrvd Channel
* chore(draft): Release v4.0.0 rc.8
* feat: Add OpenSSF best practices badge and osv-scanner
* test: Ssh Key managment
* feat: add tunnelUsername parameter
* test: SshnpdChannel
* feat: python sshnpd direct ssh
* ci: Make go modules for osv-scanner cacheable
* test: sshnpd_channel subclasses
* chore: move ssh-client & legacy-daemon from core to cli only
* docs: Update README.md logo
* feat: refactor so that sshnpdpy can be packed with poetry build
* ci: no snooping rvd build + windows build configuration
* feat: pure dart interactive ssh -> gkc
* feat: New bundles to replace templates in releases
* feat: Add support for pure dart interactive shell
* @Xlin123 made their first contribution in https://github.com/atsign-
  foundation/sshnoports/pull/259
* @sitaram-kalluri made their first contribution in https://github.com/atsign-
  foundation/sshnoports/pull/546

## v4.0.0-rc.8

* feat: Release v4.0.0 rc.7
* fix: Make sshnpd.py executable
* ci: Restrict token permissions
* fix: Uptake notify ephemeral changes
* chore: upgrade dependencies for at_onboarding_cli 1.4.0
* refactor: SSHNPParams unit tests preparation
* feat: client side Windows support
* test: Mock tests for SshnpCore
* refactor: wrap all dart:io calls
* @sitaram-kalluri made their first contribution in https://github.com/atsign-
  foundation/sshnoports/pull/546

## v4.0.0-rc.7

* feat: Release v4.0.0 rc.6
* refactor: noports core
* refactor: Remove file system bindings

## v4.0.0-rc.6

* Maintenance and dependency updates.

## v3.4.2

* Maintenance and dependency updates.

## v3.4.1

* Maintenance and dependency updates.

## v3.4.0

* Config files : `--config-file <file>` allows you to specify a file which can
  contain preconfigured information.
* The template for a config file is available [here](https://github.com/atsign-
  foundation/sshnoports/blob/trunk/packages/sshnoports/templates/config/sshnp-
  config-template.env).
* List devices : `--list-devices` allows you to list out devices and their
  versions, your sshnpd devices must be updated to v3.4.0 and have the -u flag
  set.
* The custom binary installed by the client installer now allows you to pass all
  arguments available on the main sshnp binary.
* The sshnpd installer now allows you to easily rename your devices
* feat: implemented #202
* refactor: make sshnp more modular
* fix: fixed typo which reintroduced a bug in SSHNP.getSshrvCommand
* fix: fix `Unable to find ssh public key file : false` if -s option is not
  provided
* feat: Updated docker file, removed errors and put in place error checking
* feat: use `USER` env var in `Dockerfile`
* fix: sshnp exit if atSign DNE, sshnpd wait for atSign to exist
* fix: Installer improvements and bug fixes
* fix: sshnpd updater patches
* docs: minor change in readme
* fix: remove sysctl
* fix: pass all options on sshnp@device to sshnp binary
* fix: grep bug
* refactor: make sshnpd more modular
* refactor: packages dir
* feat: Create autobug.yaml
* fix: sshnp exit 1 on error
* chore: use same utils for everything
* feat: config files
* fix: Add a better validator for device name to install_sshnpd
* ci: test/end2end_tests
* test: e2e test housekeeping
* test: more e2e test coverage - backwards compatibility
* test: local-local-local rvd test
* refactor: Refactoring Round 2
* chore: Better error messages
* fix: multibuild (+ reduced build duration)
* feat: allow the selection of a release version with installer
* ci: fix dockerhub_sshnpd
* ci: catch compilation errors
* fix: dependency upgrades + cleanup error messages in sshnp
* feat: notarization script
* ci: dockerhub
* ci: wait time without sync 2 -> 4
* ci: Matrix e2e tests
* fix: LateInitializationError sshrvdPort
* ci: fixed "without sync" tests
* docs: add noports.com to root README
* feat: make sshnpd execute ssh command via Process.start
* chore: Updated to Socket_Connector Package
* chore: handle errors for SSHNP Params when it reads config files
* fix: Correcting typo/bug in sshnp
* fix: do pub get instead of pub upgrade
* feat: use runZonedGuarded in program mains
* refactor: manual tool documentation & QOL
* feat: cease using internet_connection_checker
* refactor: sshnpd container - move test.txt as a volume
* feat: ping/heartbeat (list devices)
* feat: rootDomain option in ArgParser
* fix: install npd
* ci: extend wait duration for <=3.2.0 npd
* fix: Update launch.json
* feat: add config file reader for sshnp
* ci: copy license into releases
* docs: Added a 'how it all works' page
* docs: Update UnderTheHood.md
* feat: device renaming for sshnpd via installer
* chore: use comma for list delimiter in sshnp config
* docs:  Added detailed sequence diagram for the control plane interactions
* format: Update output formatting of sshnp --list-devices
* ci: limit max-parallel to 8
* docs: fix some typos in 'under the hood' doc
* feat: Add workflows to do SAST and dependency review
* ci: Increase wait times
* refactor: refactor sshnpd_impl.dart for future feature velocity
* fix: Fix behaviour for various flags
* feat: Update sshnpd-service-template and improve renaming / modification
* docs: updated UnderTheHood.md to accurately reflect 4.0.0.rc-2
* ci: e2e tests for the installer
* chore: set version to 3.4.0
* fix: use `-f` instead of `-o ForkAfterAuthentication=yes`
* fix: sshnpd headless template ARGS behaviour
* @purnimavenkatasubbu made their first contribution in
  https://github.com/atsign-foundation/sshnoports/pull/208
* @HamdaanAliQuatil made their first contribution in https://github.com/atsign-
  foundation/sshnoports/pull/233

## v4.0.0-rc.2

* Maintenance and dependency updates.

## v4.0.0-rc.1

* feat: implemented #202
* refactor: make sshnp more modular
* fix: fixed typo which reintroduced a bug in SSHNP.getSshrvCommand
* fix: fix `Unable to find ssh public key file : false` if -s option is not
  provided
* feat: Updated docker file, removed errors and put in place error checking
* feat: use `USER` env var in `Dockerfile`
* fix: sshnp exit if atSign DNE, sshnpd wait for atSign to exist
* fix: Installer improvements and bug fixes
* fix: sshnpd updater patches
* docs: minor change in readme
* fix: remove sysctl
* fix: pass all options on sshnp@device to sshnp binary
* fix: grep bug
* refactor: make sshnpd more modular
* refactor: packages dir
* feat: Create autobug.yaml
* fix: sshnp exit 1 on error
* chore: use same utils for everything
* feat: config files
* fix: Add a better validator for device name to install_sshnpd
* ci: test/end2end_tests
* test: e2e test housekeeping
* test: more e2e test coverage - backwards compatibility
* test: local-local-local rvd test
* refactor: Refactoring Round 2
* chore: Better error messages
* fix: multibuild (+ reduced build duration)
* feat: allow the selection of a release version with installer
* ci: fix dockerhub_sshnpd
* ci: catch compilation errors
* fix: dependency upgrades + cleanup error messages in sshnp
* feat: notarization script
* ci: dockerhub
* ci: wait time without sync 2 -> 4
* ci: Matrix e2e tests
* fix: LateInitializationError sshrvdPort
* ci: fixed "without sync" tests
* docs: add noports.com to root README
* feat: make sshnpd execute ssh command via Process.start
* chore: Updated to Socket_Connector Package
* chore: handle errors for SSHNP Params when it reads config files
* fix: Correcting typo/bug in sshnp
* fix: do pub get instead of pub upgrade
* feat: use runZonedGuarded in program mains
* refactor: manual tool documentation & QOL
* feat: cease using internet_connection_checker
* refactor: sshnpd container - move test.txt as a volume
* feat: ping/heartbeat (list devices)
* feat: rootDomain option in ArgParser
* fix: install npd
* ci: extend wait duration for <=3.2.0 npd
* fix: Update launch.json
* feat: add config file reader for sshnp
* ci: copy license into releases
* docs: Added a 'how it all works' page
* docs: Update UnderTheHood.md
* feat: device renaming for sshnpd via installer
* chore: use comma for list delimiter in sshnp config
* docs:  Added detailed sequence diagram for the control plane interactions
* format: Update output formatting of sshnp --list-devices
* ci: limit max-parallel to 8
* docs: fix some typos in 'under the hood' doc
* feat: Add workflows to do SAST and dependency review
* ci: Increase wait times
* refactor: refactor sshnpd_impl.dart for future feature velocity
* fix: Fix behaviour for various flags
* @purnimavenkatasubbu made their first contribution in
  https://github.com/atsign-foundation/sshnoports/pull/208
* @HamdaanAliQuatil made their first contribution in https://github.com/atsign-
  foundation/sshnoports/pull/233

## v3.3.0

* V3.3.0 Speeds up the sshnp client by removing the need for sync at startup,
  connection to hosts as a result are typically made in around 7 seconds.
* RiscV binaries should still be considered in beta as they depend on Dart for
  RiscV which is itself in beta
* fix: add armv7l for rpi to the ARCH list
* fix: download updater from trunk so we can do less releases
* feat: remove sync wait; fix: upgrade dependencies to take up some bug fixes
* build: update version to 3.3.0 in version.dart to match pubspec.yaml

## v3.2.0

* v3.2.0 Fixes issues related to the PATH allowing it to be run from any
  directory.
* v3.2.0 Reorganizes existing and adds new templates to the `templates/`
  directory in the release archives.
* v3.2.0 Includes an installer for Atsign's noports hosted sshrv, which you can
  purchase a license for at [noports.com](https://noports.com)
* Renamed MacOSX releases to follow [Atsign's standard naming
  conventions](https://github.com/atsign-
  foundation/operations/blob/trunk/decisions/2023-03-dart-naming-convention-for-
  releases.md)
* RiscV binaries should still be considered in beta as they depend on Dart for
  RiscV which is itself in beta

## v3.1.2

* v3.1.2 Synchronizes atSign data before starting daemons and command line
  tools. This prevents issues found in the v3.1.0 and v3.1.1 pre-release
  versions.
* v3.1.2 has small updates and corrections from v3.1.0/v3.1.1 to installation
  scripts and the README.md
* v3.1.2 includes the concept of rendezvous points using sshrv and sshrvd. Using
  sshrvd you can place rendezvous services in the right place in you network for
  the lowest latency and fastest experience. Just but specifying the atSign of
  the sshrvd both sshnpd (directly) and sshnp (via sshrv) meet at the rendezvous
  point. This negates the need for ngrok and complex TCP NAT/Firewall rules at
  the client/sshnp point. Making things crazy simple to use!
* v3.1.2 also now defaults to the use of ECC keys (ED25519) inline with Apple,
  but if you hosts still want RSA ssh keys that's fine you will have to use the
  --rsa option on sshnp.
* v3.1.2 can be used with v3.0.0 versions of sshnpd but all features will not be
  available until you upgrade fully.
* RiscV binaries should still be considered in beta as they depend on Dart for
  RiscV which is itself in beta
* MacOSX binaries. Signed then notarized by Apple (Apple only likes zip)

## v3.1.1

* feat: Updated a few errors with scripts files and updated instructions
* fix:make scripts executable
* fix:typo in script

## v3.1.0

* fix: Set provenance to false for Docker builds
* feat: Updated ReadMe so the atsign.com website is more obvious so fol…
* feat: automate binaries
* feat: Add notification to workflow
* feat: v3.1.0 Includes rendezvous point atSign service migration to ECC ssh
  keys and more

## v3.0.0

* Maintenance and dependency updates.

## v2.0.2

* fix: Updated version number to 2.0.2

## v2.0.1

* Maintenance and dependency updates.

## v2.0.0

* fix: typo in README.md in the directory location of atKeys
* feat: Migrated to release to initiate Docker image build
* feat: Ack notification of sshnpd daemon back to sshnp client

## v1.1.4

* Maintenance and dependency updates.

## v1.1.3

* Maintenance and dependency updates.

## v1.1.2

* Maintenance and dependency updates.

## v1.1.0

* Example command lines to use packaged filenames
* Decrypt notification
* @cconstab made their first contribution in https://github.com/atsign-
  foundation/sshnoports/pull/9

## v1.0.3

* Docs fixes
* @cpswan made their first contribution in https://github.com/atsign-
  foundation/sshnoports/pull/5

## v1.0.2

* Maintenance and dependency updates.

## v1.0.0

* Maintenance and dependency updates.

## v0.0.3

* Maintenance and dependency updates.

## v0.0.2

* Maintenance and dependency updates.

## v0.0.1

* Maintenance and dependency updates.
