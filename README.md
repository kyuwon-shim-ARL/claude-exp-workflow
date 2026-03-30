# exp-workflow

Research experiment lifecycle management plugin for [Claude Code](https://docs.anthropic.com/en/docs/claude-code).

Manage experiments end-to-end: GitHub Project integration, MANIFEST.yaml tracking, milestone/foundation versioning, and automated logging.

## Features

- **Experiment Tracking** - MANIFEST.yaml as single source of truth for all experiments
- **GitHub Project Integration** - Auto-create issues, manage kanban status, set date fields for Roadmap view
- **Milestone Management** - Group experiments into milestones with progress tracking
- **Foundation Versioning** - Track pipeline versions, detect stale experiments on upgrades
- **Automated Logging** - Append-only experiment log with full audit trail
- **CI/CD** - 67 unit tests + 61 E2E tests with GitHub Actions

## Installation

### Prerequisites

- [Claude Code](https://docs.anthropic.com/en/docs/claude-code) CLI installed
- [GitHub CLI](https://cli.github.com/) (`gh`) authenticated
- Git repository with a GitHub remote

### Install via Claude Code

```bash
claude install-plugin kyuwon-shim-ARL/claude-exp-workflow
```

After installation, the following slash commands become available in Claude Code:

| Command | Description |
|---------|-------------|
| `/exp-init` | Initialize project (GitHub Project + config + MANIFEST) |
| `/exp-start` | Start a new experiment |
| `/exp-status` | View experiment dashboard |
| `/exp-finalize` | Finalize, deprecate, or reopen experiments |
| `/exp-milestone` | Manage milestones (start/status/end) |
| `/exp-foundation` | Manage foundation versions (start/upgrade/status) |

## Quick Start

### 1. Initialize your project

```
/exp-init
```

This will:
- Detect or create a GitHub Project
- Discover status field IDs (Backlog, AI Doing, Done, etc.)
- Set up date fields for Roadmap view (optional)
- Generate `.omc-config.sh` (auto-gitignored)
- Create `outputs/MANIFEST.yaml` with v3 schema

### 2. (Optional) Declare a foundation

```
/exp-foundation start v1 "Initial pipeline: preprocessing + model training"
```

Foundation tracks your pipeline version. Experiments auto-link to the current foundation.

### 3. (Optional) Start a milestone

```
/exp-milestone start "v1.0-baseline" "Establish baseline metrics" 2026-04-01
```

### 4. Start an experiment

```
/exp-start e001 Baseline logistic regression on full dataset
```

With optional flags:

```
/exp-start e002 --milestone "v1.0-baseline" --depends-on cv,labels Feature-engineered model
```

This will:
- Create a GitHub issue with task checklist (Plan / Execute / Verify / Interpret)
- Create a `feature-{N}` branch
- Add the issue to your GitHub Project with "AI Doing" status
- Set Start Date on the project
- Register the experiment in MANIFEST.yaml
- Append to experiment-log.md

### 5. Check status

```
/exp-status          # Overview dashboard
/exp-status e001     # Detail view for specific experiment
```

Overview shows: Foundation info, milestone progress bar, and a table of all experiments with status, stale flags, dates, and task completion.

### 6. Finalize experiments

```
/exp-finalize e001              # Single finalization
/exp-finalize e001 e002 e004    # Batch finalization
/exp-finalize --deprecate e003 "Superseded by e004"
/exp-finalize --reopen e001 "Need additional validation"
```

Finalization will:
- Update MANIFEST status (`experimental` -> `final`)
- Auto-detect output files (csv, png, pkl, html, json, log)
- Set Target Date on GitHub Project
- Commit MANIFEST + log and create a PR

## MANIFEST.yaml Schema (v4)

```yaml
version: 4
updated: "2026-03-31T12:00:00+09:00"
scan_paths:
  - outputs/

foundations:
  v1:
    description: "Initial pipeline"
    components:
      labels: "Multi-label classification"
      cv: "5-fold stratified"
    status: current
    created: "2026-03-01T10:00:00+09:00"

milestone:
  title: "v1.0-baseline"
  created: "2026-03-01T10:00:00+09:00"

experiments:
  e001:
    path: outputs/e001/
    script: "scripts/run_e001.py"
    params:
      model: logistic_regression
      cv_folds: 5
    outputs:                           # v4: structured objects (v3: bare strings)
      - path: outputs/e001/result.csv
        hash: "a1b2c3d4e5f6..."        # SHA-256 hex lowercase 64 chars
        size: 12345                     # bytes
        mtime: 1711900800              # Unix epoch seconds
        type: data                     # data | structured | visualization | report | model | log
      - path: outputs/e001/roc_curve.png
        hash: "f6e5d4c3b2a1..."
        size: 45678
        mtime: 1711900800
        type: visualization
    status: final              # experimental | final | deprecated
    description: "Baseline logistic regression"
    issue: 42
    branch: feature-42
    milestone: "v1.0-baseline"
    foundation: v1
    depends_on_components:     # optional; omit = depends on all
      - labels
      - cv
    stale: false
    updated: "2026-03-31T12:00:00+09:00"
```

### v4 outputs schema

| Field | Type | Required | Description |
|-------|------|----------|-------------|
| `path` | string | yes | File path relative to project root |
| `hash` | string | yes | SHA-256 hex lowercase, 64 characters |
| `size` | integer | yes | File size in bytes |
| `mtime` | integer | yes | Last modified time, Unix epoch seconds |
| `type` | string | yes | Classification: `data`, `structured`, `visualization`, `report`, `model`, `log` |

**Backwards compatibility**: v1 (no milestone block), v2 (no foundations), v3 (bare string outputs), and v4 MANIFESTs are all supported. When reading v3 outputs (bare strings), treat as `{path: string}` with other fields null.

## Foundation & Stale Tracking

When your pipeline changes, upgrade the foundation:

```
/exp-foundation upgrade v2 "Updated CV strategy" --changed-components cv
```

This will:
- Mark `v1` as `stale`
- Create `v2` as `current`
- Selectively mark experiments stale: only those whose `depends_on_components` intersects with `--changed-components`
- Experiments with no `depends_on_components` are treated as depending on everything (conservative default)

Stale experiments are:
- Shown with a stale flag in `/exp-status`
- Warned about during `/exp-finalize`
- Excluded from `/detailed-report` generation

## Auto-Trigger (Natural Language)

The plugin includes an auto-trigger skill that activates on natural language patterns:

| What you say | What runs |
|-------------|-----------|
| "e001 실험 시작해줘" | `/exp-start e001 ...` |
| "실험 현황 보여줘" | `/exp-status` |
| "e003 final로 확정해줘" | `/exp-finalize e003` |
| "마일스톤 시작" | `/exp-milestone start ...` |
| "foundation 업그레이드" | `/exp-foundation upgrade ...` |
| "stale 실험 확인" | `/exp-status` (with stale filter) |

## Typical Workflow

```
/exp-init
  -> /exp-foundation start v1 "Initial pipeline"
  -> /exp-milestone start "v1.0-baseline"
    -> /exp-start e001 "Baseline model"
    -> /exp-start e002 "Feature engineering"
    -> (run experiments, iterate)
    -> /exp-finalize e001 e002
  -> /exp-milestone end
  -> /exp-foundation upgrade v2 "New preprocessing" --changed-components preprocessing
    -> /exp-start e003 "Re-run with v2 pipeline"
    -> /exp-finalize e003
  -> /detailed-report  (uses only final + non-stale experiments)
```

## CI/CD

The project includes a 3-stage GitHub Actions pipeline:

| Stage | Tests | Duration | Requirements |
|-------|-------|----------|-------------|
| `validate` | File existence, JSON syntax, cross-references | ~5s | None |
| `unit-test` | 67 tests (gh CLI stubbed, no network) | ~5s | None |
| `e2e-test` | 61 tests (real GitHub API) | ~30s | `GH_TOKEN` secret |

Run tests locally:

```bash
# Unit tests (no network required)
bash tests/unit-test.sh --verbose

# E2E tests (requires gh auth)
bash tests/e2e-test.sh --verbose
```

## CI Tools

Bundled scripts in `ci/omc-tools/` (also installed to `~/bin/` for local use):

| Tool | Purpose |
|------|---------|
| `omc-load-config` | Source `.omc-config.sh`, provides helper functions |
| `omc-feature-start` | Create issue + branch + project card |
| `omc-feature-progress` | Show feature issue completion rates |
| `omc-milestone-start` | Create/activate GitHub milestone |
| `omc-milestone-status` | Show milestone progress bar |
| `omc-milestone-end` | Close milestone |
| `omc-backfill-dates` | Retroactively set dates on existing experiment issues |

## Project Structure

```
.claude-plugin/
  plugin.json              # Plugin metadata
  marketplace.json         # Marketplace listing
commands/
  exp-init.md              # Project initialization
  exp-start.md             # Start experiment
  exp-status.md            # Status dashboard
  exp-finalize.md          # Finalize/deprecate/reopen
  exp-milestone.md         # Milestone management
  exp-foundation.md        # Foundation versioning
skills/
  experiment-workflow/
    SKILL.md               # Auto-trigger skill definition
ci/
  omc-tools/               # Bundled CLI scripts
tests/
  unit-test.sh             # 67 unit tests
  e2e-test.sh              # 61 E2E tests
.github/workflows/
  ci.yml                   # CI pipeline
```

## Configuration

`/exp-init` generates `.omc-config.sh` (auto-gitignored) with:

```bash
export OMC_GH_REPO="owner/repo"
export OMC_PROJECT_NUMBER="1"
export OMC_PROJECT_OWNER="@me"
export OMC_STATUS_FIELD_ID="PVTSSF_..."
export OMC_STATUS_BACKLOG="..."
export OMC_STATUS_AI_DOING="..."
export OMC_STATUS_DONE="..."
export OMC_CURRENT_MILESTONE=""
export OMC_DATE_START_FIELD_ID=""    # Optional: for Roadmap view
export OMC_DATE_END_FIELD_ID=""      # Optional: for Roadmap view
```

## License

MIT
