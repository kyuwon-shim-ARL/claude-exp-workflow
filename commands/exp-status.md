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

### 3. Fetch GitHub Data
```bash
omc-milestone-status
omc-feature-progress --all
```

### 4. Combine Data
For each experiment in MANIFEST:
- Match with GitHub Issue (by experiment ID in title)
- Extract task completion ratio
- Determine current branch

### 5. Generate Output

#### Overview Mode (no arguments)
```
Experiment Status Dashboard

Milestone: v1.0-foundation
  Progress: [########....] 50% (2/4)

Experiments:
  ID     | Title               | Status       | Tasks | Issue
  e001   | Baseline Scoring    | final        | 4/4   | #1
  e002   | Feature Selection   | final        | 3/3   | #5
  e003   | DEG Analysis        | experimental | 2/4   | #8
  e004   | Biomarker Discovery | experimental | 0/3   | #12
  e005   | Legacy Method       | deprecated   | 2/2   | #15

MANIFEST: 5 experiments (2 final, 2 experimental, 1 deprecated)

Next: /exp-start e004 or /ralplan for e003 or /exp-finalize for completed
```

#### Detail Mode (with experiment ID)
Shows: Issue info, branch, task checklist, output files, recent commits.

### 6. Edge Cases
- No MANIFEST.yaml → "Run /exp-init"
- Empty MANIFEST → "Run /exp-start e001"
- Experiment not found → show available experiments

## Related Commands

- `/exp-init`: Initialize experiment tracking
- `/exp-start <id>`: Start new experiment
- `/exp-finalize <id>`: Promote to final or deprecate
- `/ralph`: Execute next task in current experiment
- `/ralplan`: Plan next experiment phase
- `/research`: Analyze experiment results
