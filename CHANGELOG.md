# Changelog

All notable changes to this project are documented here.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

### Added

- Initial repository structure: MkDocs Material site, documentation outlines for all
  planned sections, code sample package, CI workflows, and contribution guidelines.

[Unreleased]: https://github.com/ma-mamun/flutter-engineering-handbook/commits/main

### Changed

- Restructured the handbook into six numbered parts plus an appendix and
  cheatsheets, replacing the flat topic sections.
- Consolidated the docs and code workflows into a single `deploy.yml` where the
  code checks gate the site build.
- Moved diagrams and images under `docs/`, split `assets/` into logo, banner,
  and social.
- Replaced the two issue forms with four Markdown templates (bug, feature,
  documentation, interview question).

### Added

- `docs/style-guide.md`, `docs/getting-started.md`, `docs/roadmap.md`
- `scripts/` with serve, build, check, and new-page helpers
- `.github/CODEOWNERS`, `.github/dependabot.yml`, `.editorconfig`
