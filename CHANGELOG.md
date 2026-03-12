# Changelog

All notable changes to this project will be documented in this file.

## [1.5.1] - 2026-03-10

### Added
- Experiment label (`experiment`) auto-applied to issues created by `/exp-start`
- SKILL.md trigger patterns expanded (stale, pipeline version, foundation keywords)
- `/exp-status e{NUM}` detail mode: single experiment view with task checklist, output files, recent commits, and date fields

### Changed
- E2E tests validate experiment label presence on created issues

## [1.5.0] - 2026-03-07

### Added
- Date columns (Start Date, Target Date) in `/exp-status` overview table
- CI validation for `omc-load-config` sourcing

### Changed
- `omc_clear_date` warning messages symmetrized for consistency
- Test hardening: added I10, I11, J12 test cases
- **Tests**: 61 E2E + 67 unit tests

## [1.4.1] - 2026-03-05

### Fixed
- `omc_clear_date` now uses `--clear` flag instead of setting empty string
- Test and documentation alignment for date clearing behavior

## [1.4.0] - 2026-03-04

### Added
- Date Field support for GitHub Project Roadmap view
- `/exp-init` auto-discovers or creates Start Date and Target Date fields
- `/exp-start` sets Start Date on project card
- `/exp-finalize` sets Target Date on finalize/deprecate; clears on reopen
- `omc-backfill-dates` tool: retroactively set dates on existing experiment issues (`--dry-run` supported)
- **Tests**: 61 E2E + 64 unit tests

## [1.3.1] - 2026-03-03

### Added
- Selective stale propagation via `--changed-components` flag on `/exp-foundation upgrade`
- `depends_on_components` field on experiments for fine-grained stale control
- Experiments without `depends_on_components` default to depending on all components (conservative)
- **Tests**: 58 E2E + 44 unit tests

## [1.3.0] - 2026-03-02

### Added
- Foundation Layer: `/exp-foundation` command (start/upgrade/status)
- MANIFEST v3 schema with `foundations` block
- Stale propagation: foundation upgrade marks dependent experiments as stale
- `foundation`, `depends_on_components`, `stale`, `stale_reason` fields on experiments
- Auto-linking: `/exp-start` links to current foundation automatically
- `/detailed-report` filters out `stale: true` experiments
- **Tests**: 50 E2E + 38 unit tests

## [1.2.0] - 2026-02-28

### Added
- `/exp-milestone` command (start/status/end)
- MANIFEST v2 schema with `milestone` block
- `--milestone` flag on `/exp-start`
- `--reopen` mode on `/exp-finalize`
- Milestone progress bar in status display

## [1.1.0] - 2026-02-26

### Fixed
- 11 issues resolved (2 HIGH, 6 MEDIUM, 3 LOW)
- Improved plugin robustness and error handling
- E2E test suite passing

## [1.0.0] - 2026-02-25

### Added
- Initial release
- `/exp-init`: Project initialization with GitHub Project integration
- `/exp-start`: Start experiments with GitHub issue + branch + MANIFEST registration
- `/exp-status`: Read-only experiment dashboard
- `/exp-finalize`: Finalize, deprecate experiments with PR creation
- MANIFEST.yaml v1 schema
- Automated experiment logging (`experiment-log.md`)
