<a href="https://atsign.com#gh-light-mode-only"><img width=250px src="https://atsign.com/wp-content/uploads/2022/05/atsign-logo-horizontal-color2022.svg#gh-light-mode-only" alt="The Atsign Foundation"></a><a href="https://atsign.com#gh-dark-mode-only"><img width=250px src="https://atsign.com/wp-content/uploads/2023/08/atsign-logo-horizontal-reverse2022-Color.svg#gh-dark-mode-only" alt="The Atsign Foundation"></a>

[![GitHub License](https://img.shields.io/badge/license-BSD3-blue.svg)](./LICENSE)
[![OpenSSF Scorecard](https://api.securityscorecards.dev/projects/github.com/atsign-foundation/noports/badge)](https://securityscorecards.dev/viewer/?uri=github.com/atsign-foundation/noports&sort_by=check-score&sort_direction=desc)
[![OpenSSF Best Practices](https://www.bestpractices.dev/projects/8102/badge)](https://www.bestpractices.dev/projects/8102)
[![SLSA 3](https://slsa.dev/images/gh-badge-level3.svg)](https://slsa.dev)

# noports

This repo contains the open source code of the Atsign's NoPorts product. Check
out our product site at [noports.com](https://noports.com).

## Get Started

Installation, use-cases and usage guides can all be found on our
[docs site](https://docs.noports.com).

## Source Code Availability

If you are interested in auditing the source code for NoPorts, this is where you
can find various bits of interest.

- [packages/](./packages/) - contains the bulk of the source code
  - [dart/](./packages/dart/) - contains the Dart implementation of NoPorts
    - [noports_core/](./packages/dart/noports_core/) - contains the core logic
      for NoPorts as shared library
    - [sshnoports/](./packages/dart/sshnoports) - contains the Dart CLI binaries
      for NoPorts (sshnp, npt, sshnpd, srvd)
    - [sshnp_flutter/](./packages/dart/sshnp_flutter/) - contains the Flutter
      Desktop app for SSHNP
  - [c/](./packages/c/) - contains the C implementation of NoPorts
  - [python/](./packages/python/) - contains the Python implementation of
    NoPorts (this is deprecated, we recommend that you use the C version
    instead)
