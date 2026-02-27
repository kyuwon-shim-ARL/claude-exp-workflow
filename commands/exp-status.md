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
  ID     | Title               | Status       | Stale        | Depends On     | Tasks | Issue
  e001   | Baseline Scoring    | final        |              | labels, cv     | 4/4   | #1
  e002   | Feature Selection   | final        | stale (cv)   | labels, cv     | 3/3   | #5
  e003   | DEG Analysis        | experimental |              | labels         | 2/4   | #8

Experiments [no milestone]:
  ID     | Title               | Status       | Stale        | Depends On     | Tasks | Issue
  e004   | Biomarker Discovery | experimental |              | (all)          | 0/3   | #12
  e005   | Legacy Method       | deprecated   |              |                | 2/2   | #15

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

#### Detail Mode (with experiment ID)
Shows: Issue info, branch, task checklist, output files, recent commits.

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
