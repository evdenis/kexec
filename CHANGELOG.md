# Changelog


## v3.0


- Bump version to v3.0
- Update README for multi-arch and Docker builds
- Add automated upstream kexec-tools update workflow
- Add multi-arch kexec-tools build (arm64, arm, x86_64, x86)
- Add Dockerfile and build script for kexec-tools cross-compilation


## v2.0


- Bump version to v2.0
- Refresh update-binary from upstream Magisk
- Consolidate shellcheck into make lint, fix CI efficiency and consistency
- Improve README with prerequisites, architecture, and install details
- Add release workflow with version check, changelog, and auto-update
- Add CI workflow with ShellCheck and zip verification
- Add CHANGELOG.md with initial v1 release entry
- Add cliff.toml for git-cliff changelog generation
- Add pre-commit hook for ShellCheck linting
- Update Makefile with setup target, atomic update, and expanded zip exclusions
- Expand .gitattributes with export-ignore for all dev files
- Expand .gitignore with build artifacts and local-only files
- Add shebang to customize.sh for shellcheck compatibility
- Add updateJson to module.prop for Magisk auto-update

## v1

- Initial release
- Kexec tools for Android (aarch64)
