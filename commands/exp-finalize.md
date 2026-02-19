---
description: "실험 확정 - MANIFEST final 전환 + PR 생성 + 기록 (global)"
---

# /exp-finalize - Experiment Finalization

Promotes experiments from experimental to final status with automatic MANIFEST updates, PR creation, and logging.

## Usage

```bash
/exp-finalize e005
/exp-finalize e001 e002 e004              # Batch finalization
/exp-finalize --deprecate e003 "v2로 대체"  # Deprecate experiment
```

## Arguments
- `$ARGUMENTS`: One or more experiment numbers OR `--deprecate e003 "reason"`

## Execution Steps

### 1. Parse Arguments
- Single: `e005`
- Batch: `e001 e002 e004`
- Deprecate: `--deprecate e003 "reason text"`

### 2. Validate Environment
Check `.omc-config.sh` and `outputs/MANIFEST.yaml` exist. If missing: "Run /exp-init first."

### 3. Load Experiment Data
Read `outputs/MANIFEST.yaml` and find each experiment entry. Verify exists, check current status.

### 4. Confirm with User
Show experiment name, current status, target status, and ask for confirmation.

### 5. Update MANIFEST.yaml

**Finalization:**
```yaml
experiments:
  e005:
    status: final          # experimental → final
    updated: 2026-02-16    # today's date
```

**Deprecation:**
```yaml
experiments:
  e003:
    status: deprecated
    updated: 2026-02-16
    deprecation_reason: "v2로 대체"
```

### 6. Update experiment-log.md
Append finalization or deprecation entry. Auto-detect key output files (CSV row count, PNG as visualization, etc.).

### 7. Create Pull Request (Finalization Only)
```bash
git add outputs/MANIFEST.yaml experiment-log.md
git commit -m "finalize: promote e005 to final status

Co-Authored-By: Claude Opus 4.6 <noreply@anthropic.com>"
git push -u origin HEAD
gh pr create --title "e005: {title}" --body "..."
```

### 8. Display Summary
Show: changes made, PR URL, issues to be closed.

## Edge Cases
- Experiment not found → show available experiments
- Already final → warn and skip
- Already deprecated → warn and skip
- Missing .omc-config.sh → "Run /exp-init first"
- No issue number → create PR without "Closes #N"
- Unrelated uncommitted changes → only commit MANIFEST + log

## Batch Finalization
1. Validate all experiments first (fail fast)
2. Combined confirmation prompt
3. Single MANIFEST edit, single log entry, single PR

## Related Commands
- `/exp-init` - Initialize MANIFEST.yaml
- `/exp-start` - Create new experiment
- `/exp-status` - View all experiment statuses
- `/detailed-report` - Generate report (uses final experiments only)
