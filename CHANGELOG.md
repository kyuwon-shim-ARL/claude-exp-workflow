# Changelog

All notable changes to this project will be documented in this file.

## [1.7.0] - 2026-03-31

### Added
- **MANIFEST v4 schema**: `outputs` now uses structured objects `{path, hash, size, mtime, type}` instead of bare strings
- **SHA-256 hash computation**: `/exp-finalize` auto-computes SHA-256 hash, file size, mtime, and type classification for each output file
- Type classification: `data`, `structured`, `visualization`, `report`, `model`, `log` based on file extension
- **DVC opt-in integration**: `/exp-finalize` Step 7.5 auto-runs `dvc add` + `dvc push` when DVC is installed (graceful skip when absent)
- DVC setup guide in exp-finalize.md
- Downstream integrity gates (omc-research-skills G1-G4) can now verify output file integrity via MANIFEST hash

### Changed
- `/exp-finalize` Detection Process: steps 4-5 now compute file metadata before MANIFEST update
- README.md, SKILL.md updated with v4 schema documentation

### Compatibility
- v1, v2, v3 MANIFESTs fully supported (bare string outputs treated as `{path: string}` with null metadata)
- DVC is fully optional — zero impact when not installed

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
