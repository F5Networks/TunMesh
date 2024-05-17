Tun Mesh Changelog
==================

This log contains only significant and breaking changes.
Minor changes are documented in the git commit log.

v0
--

Version 0 is the early release version.
Minor versions contain breaking changes.

### v0.2

- Initial Release in incubating directory

### v0.3

- Reuse the packet md5 for token signatures instead of calculating a new the SHA256.
  - This is a breaking change to the auth signature.
- Use session tokens wherever possible
- Various bugfixes and improvements

### v0.4

- Enable per-node detailed metric support
  - Non-breaking change

### 0.5

- Enable bootstrapping through a load balancer
  - This change includes a breaking change to the control API and bootstrap flow.
- Various bugfixes and improvements

### 0.6

- Refactor session auth flow to reduce mitm risk
  - This change refactors the auth flow and endpoints, and is a breaking change.
- Various bugfixes and improvements

### 0.7

- Refactor bootstrap config to allow grouping of bootstrap URLs with separate settings.
  - Bumps config version to 1.0
  - Incompatible with previous config format, compatible with 0.6 remote nodes.
