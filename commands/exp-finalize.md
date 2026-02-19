---
description: "실험 확정 - MANIFEST final 전환 + PR 생성 + 기록 (global)"
allowed-tools: ["Bash", "Read", "Write", "Edit"]
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
updated: "2026-02-16T10:00:00Z"    # root updated: always refresh on any change
experiments:
  e005:
    status: final                    # experimental → final
    updated: "2026-02-16T10:00:00Z"  # ISO 8601 format
```

**Deprecation:**
```yaml
updated: "2026-02-16T10:00:00Z"    # root updated: always refresh
experiments:
  e003:
    status: deprecated
    updated: "2026-02-16T10:00:00Z"  # ISO 8601 format
    deprecation_reason: "v2로 대체"
```

### 6. Update experiment-log.md
Append finalization or deprecation entry.

**Output Auto-Detection Rules:**
Scan the experiment's `path` directory (from MANIFEST) and `scan_paths` entries:

| Pattern | Classification | Log Entry Format |
|---------|---------------|-----------------|
| `*.csv` | Data result | "result.csv (N rows)" |
| `*.tsv` | Data result | "result.tsv (N rows)" |
| `*.json` | Structured output | "config.json" |
| `*.png`, `*.jpg`, `*.svg` | Visualization | "figure1.png (visualization)" |
| `*.html` | Report | "report.html (interactive report)" |
| `*.pkl`, `*.joblib` | Model artifact | "model.pkl (model artifact)" |
| `*.log`, `*.txt` | Log output | "run.log (execution log)" |

**Detection Process:**
1. List all files in `outputs/e{NUM}/`
2. Match against patterns above
3. For CSV/TSV: count rows with `wc -l`
4. Update MANIFEST `outputs:` array with detected file paths
5. Write detected files summary to experiment-log.md entry

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

### Rollback on Failure
If any step in the finalization sequence fails, follow this recovery protocol:

| Failed Step | Recovery Action |
|-------------|-----------------|
| MANIFEST edit fails | No action needed (file unchanged) |
| git commit fails | Revert MANIFEST: `git checkout -- outputs/MANIFEST.yaml experiment-log.md` |
| git push fails | Reset commit: `git reset HEAD~1` then revert MANIFEST |
| PR creation fails | Push succeeded; create PR manually via `gh pr create` |

**Important:** Always verify MANIFEST.yaml state after recovery with `/exp-status`.

## Related Commands
- `/exp-init` - Initialize MANIFEST.yaml
- `/exp-start` - Create new experiment
- `/exp-status` - View all experiment statuses
- `/detailed-report` - Generate report (uses final experiments only)
