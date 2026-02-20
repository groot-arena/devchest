# Contributing to DevChest

Thank you for your interest in contributing to DevChest. This document explains how to propose changes, add new scripts, and open issues or pull requests.

## How to Contribute

### Reporting issues

- Use the [issue templates](https://github.com/groot-arena/devchest/issues/new/choose) when opening an issue (bug report, feature request, update/improvement, or question).
- Search existing issues first to avoid duplicates.
- Include your OS and version, and steps to reproduce when reporting bugs.

### Proposing changes (pull requests)

1. **Fork the repository** and clone your fork locally.

2. **Create a branch** from `main` using the naming convention:
   ```bash
   git checkout -b feat/flavour/package-name
   ```
   Examples:
   - `feat/ubuntu/docker` — new Docker install script for Ubuntu
   - `fix/install-curl-fallback` — fix in main install script
   - `docs/readme-quickstart` — documentation only

3. **Make your changes** and keep commits focused and clear.

4. **Push to your fork**:
   ```bash
   git push origin feat/flavour/package-name
   ```

5. **Open a pull request** against `main`. Use the [PR template](.github/PULL_REQUEST_TEMPLATE.md) and describe what you changed and why.

### What we look for

- **New scripts**: Automation for installing or configuring tools on supported Linux distros.
- **Improvements**: Fixes, better error handling, idempotency, or clearer output in existing scripts.
- **Documentation**: Clear README updates, comments in scripts, or CONTRIBUTING improvements.

### Branch naming

- `feat/<scope>/<short-description>` — new feature or script
- `fix/<scope>/<short-description>` — bug fix
- `docs/<short-description>` — documentation only
- `chore/<short-description>` — maintenance (deps, CI, etc.)

## Questions?

Open a [question/support issue](https://github.com/groot-arena/devchest/issues/new/choose) or start a discussion. We’re happy to help.

Thanks for contributing!
