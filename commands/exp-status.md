---
description: "실험 현황 통합 조회 - 마일스톤 + 칸반 + MANIFEST (global)"
allowed-tools: ["Bash", "Read"]
---

# /exp-status Command

Shows unified experiment status combining:
- Milestone progress (from GitHub Projects)
- Feature/Task completion (from GitHub Issues)
- Experiment catalog (from outputs/MANIFEST.yaml)

## Usage

```bash
/exp-status              # Show all experiments overview
/exp-status e003         # Show specific experiment details
```

## Execution Steps

### 1. Prerequisites Check
Check `.omc-config.sh` and `outputs/MANIFEST.yaml` exist. If missing, instruct user to run `/exp-init`.

### 2. Read MANIFEST Data
Read `outputs/MANIFEST.yaml` to get experiment IDs, titles, status, output files.
Also read `milestone` block for active milestone information.

### 3. Fetch GitHub Data
```bash
# Only call omc-milestone-status if MANIFEST milestone.title is non-empty
omc-milestone-status "$MILESTONE_TITLE"
omc-feature-progress --all
```

### 4. Combine Data
For each experiment in MANIFEST:
- Match with GitHub Issue (by experiment ID in title)
- Extract task completion ratio
- Determine current branch
- Group experiments by `milestone` field (if present)

### 5. Generate Output

#### Overview Mode (no arguments)
```
Experiment Status Dashboard

Foundation: v2 (current) - "Nested CV + Y-randomization"
  v1 (stale): 3 experiments (2 stale, 1 deprecated)

Milestone: v1.0-foundation (active)
  GitHub Progress: [########....] 50% (2/4 issues)

Experiments [v1.0-foundation]:
  ID     | Title               | Status       | Stale        | Depends On     | Start Date | Target Date | Tasks | Issue
  e001   | Baseline Scoring    | final        |              | labels, cv     | 2026-01-15 | 2026-02-01  | 4/4   | #1
  e002   | Feature Selection   | final        | stale (cv)   | labels, cv     | 2026-01-20 | 2026-02-10  | 3/3   | #5
  e003   | DEG Analysis        | experimental |              | labels         | 2026-02-15 |             | 2/4   | #8

Experiments [no milestone]:
  ID     | Title               | Status       | Stale        | Depends On     | Start Date | Target Date | Tasks | Issue
  e004   | Biomarker Discovery | experimental |              | (all)          | 2026-03-01 |             | 0/3   | #12
  e005   | Legacy Method       | deprecated   |              |                | 2026-01-10 | 2026-01-25  | 2/2   | #15

MANIFEST: 5 experiments (2 final, 2 experimental, 1 deprecated, 1 stale)

Next: /exp-start e004 or /ralplan for e003 or /exp-finalize for completed
```

**Foundation Info (v3 MANIFEST only):**
If `foundations` block exists, show current foundation and stale experiment count at the top of the dashboard. The "Stale" column only appears when at least one experiment has `stale: true`.

**Depends On column:**
- If experiment has `depends_on_components`: show comma-separated list (e.g., `labels, cv`)
- If experiment has no `depends_on_components` but has `foundation`: show `(all)` (depends on all components)
- If experiment has no `foundation`: leave blank

**Stale column:**
- If `stale: true` and `stale_reason` exists: show `stale` with reason in parentheses (e.g., `stale (cv)`)
- If `stale: true` without `stale_reason`: show `stale`
- Otherwise: blank

If no active milestone in MANIFEST, show all experiments without grouping (backwards compatible).

**Date Field columns (v1.4+ only):**
- **Start Date** and **Target Date** columns are shown when `OMC_DATE_START_FIELD_ID` or `OMC_DATE_END_FIELD_ID` are configured in `.omc-config.sh`.
- Dates are fetched from the GitHub Project item fields via `gh project item-list`.
- If date fields are not configured, these columns are omitted (backwards compatible).
- Start Date = experiment creation date; Target Date = finalization/deprecation date.
- Open experiments show blank Target Date.

#### Detail Mode (with experiment ID)
When an experiment ID is provided (e.g., `/exp-status e003`):

1. **Read MANIFEST**: Find experiment entry by ID. If not found, show available experiments and exit.
2. **Fetch GitHub Issue data**:
```bash
gh issue view {issue_number} --repo "$OMC_GH_REPO" --json title,state,body,labels,createdAt
```
3. **Extract task checklist**: Parse issue body for `- [ ]` and `- [x]` patterns, compute completion ratio.
4. **List output files**:
```bash
ls -la outputs/e{NUM}/ 2>/dev/null
```
5. **Recent commits on branch**:
```bash
git log --oneline -5 {branch_name} 2>/dev/null
```
6. **Fetch Date fields** (if configured):
   Same as overview mode — query `gh project item-list` for Start Date and Target Date.

7. **Display**:
```
Experiment e003: DEG Analysis
  Status:       experimental
  Foundation:   v2 (current)
  Depends On:   labels
  Stale:        no
  Issue:        #8 (open)
  Branch:       feature-8
  Start Date:   2026-02-15
  Target Date:  -
  Milestone:    v1.0-foundation

  Tasks: [####........] 2/4
    [x] Plan 작성
    [x] 실험 실행
    [ ] 결과 검증
    [ ] 결과 해석

  Outputs:
    (none yet)

  Recent Commits:
    a1b2c3d Add DEG analysis script
    e4f5g6h Initial experiment setup
```

### 6. Edge Cases
- No MANIFEST.yaml → "Run /exp-init"
- Empty MANIFEST → "Run /exp-start e001"
- Experiment not found → show available experiments

## Related Commands

- `/exp-init`: Initialize experiment tracking
- `/exp-milestone`: Manage milestones (start/status/end)
- `/exp-start <id>`: Start new experiment
- `/exp-finalize <id>`: Promote to final or deprecate
- `/ralph`: Execute next task in current experiment
- `/ralplan`: Plan next experiment phase
- `/research`: Analyze experiment results
