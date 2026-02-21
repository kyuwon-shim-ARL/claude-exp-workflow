---
description: "마일스톤 관리 - 생성/현황/종료 (global)"
allowed-tools: ["Bash", "Read", "Write", "Edit"]
---

# /exp-milestone - Milestone Management

Manage milestones within the experiment workflow: create, check status, and close milestones.

## Usage

```bash
/exp-milestone start "v1.0-foundation" "Initial milestone" "2026-06-30"
/exp-milestone status
/exp-milestone status "v1.0-foundation"
/exp-milestone end
/exp-milestone end --force
```

## Arguments
- `$ARGUMENTS`: `start <title> [description] [due-date]` | `status [title]` | `end [--force] [--reopen]`

## Subcommands

### start `<title>` `[description]` `[due-date]`

1. **Parse Arguments**: title (required), description (optional), due-date (optional)
2. **Validate Environment**: Check `.omc-config.sh` exists. If missing: "Run /exp-init first."
3. **Conflict Check**: Read `outputs/MANIFEST.yaml` → if `milestone.title` is non-empty, warn: "Active milestone '{title}' already exists. Replace?" and ask for confirmation.
4. **Create GitHub Milestone**: Execute:
   ```bash
   omc-milestone-start "$TITLE" "$DESC"
   ```
   If `due-date` provided, pass it as well. Capture CLI output.
5. **Update MANIFEST.yaml**:
   ```yaml
   updated: "YYYY-MM-DDTHH:MM:SSZ"
   milestone:
     title: "v1.0-foundation"
     created: "YYYY-MM-DDTHH:MM:SSZ"
   ```
   Update root `updated` timestamp.
6. **Update experiment-log.md**: Append:
   ```markdown
   ## YYYY-MM-DD: Milestone started - "v1.0-foundation"
   - **Title**: v1.0-foundation
   - **Description**: Initial milestone
   - **Status**: active
   ```
7. **Display Summary**:
   ```
   Milestone "v1.0-foundation" created.

   Next: /exp-start e001 to create experiments under this milestone.
   ```

### status `[title]`

1. **Resolve Title**: If argument provided, use it. Otherwise fallback: MANIFEST `milestone.title` → `OMC_CURRENT_MILESTONE` from `.omc-config.sh`. If none found: "No active milestone. Use /exp-milestone start."
2. **Fetch GitHub Progress**:
   ```bash
   omc-milestone-status "$TITLE"
   ```
3. **Aggregate Local Data**: Read `outputs/MANIFEST.yaml` experiments, filter by `milestone` field matching title. Count statuses (experimental/final/deprecated).
4. **Display Dashboard**:
   ```
   Milestone: v1.0-foundation
     GitHub Progress: [########....] 50% (2/4 issues)

   Experiments in this milestone:
     ID     | Description          | Status
     e001   | Baseline Scoring     | final
     e002   | Feature Selection    | experimental

   Summary: 1 final, 1 experimental, 0 deprecated
   ```

### end `[--force]` `[--reopen]`

1. **Parse Flags**: `--force` (close even with open issues), `--reopen` (reopen a closed milestone)
2. **Check Active Milestone**: Read MANIFEST `milestone.title`. If empty: "No active milestone to end."
3. **Close GitHub Milestone**:
   ```bash
   omc-milestone-end [--force] [--reopen]
   ```
   Capture CLI output.
4. **Update MANIFEST.yaml**: Clear milestone block:
   ```yaml
   updated: "YYYY-MM-DDTHH:MM:SSZ"
   milestone: {}
   ```
5. **Update experiment-log.md**: Append:
   ```markdown
   ## YYYY-MM-DD: Milestone ended - "v1.0-foundation"
   - **Title**: v1.0-foundation
   - **Status**: closed
   ```
6. **Display Summary**:
   ```
   Milestone "v1.0-foundation" closed.

   Next: /exp-milestone start "v2.0" to begin a new milestone.
   ```

## Error Handling

| Condition | Action |
|-----------|--------|
| No subcommand | Show usage: `/exp-milestone start|status|end` |
| `start` without title | Show usage: `/exp-milestone start <title> [description] [due-date]` |
| `.omc-config.sh` missing | "Run /exp-init first." |
| `omc-milestone-*` CLI fails | Display CLI error output, do NOT update MANIFEST |
| Active milestone conflict (start) | Warn and ask user confirmation before replacing |
| No active milestone (end) | "No active milestone. Use /exp-milestone start." |

## Related Commands

- `/exp-init` - Initialize experiment tracking
- `/exp-start` - Start new experiment (auto-links to active milestone)
- `/exp-status` - View experiment dashboard (includes milestone progress)
- `/exp-finalize` - Promote experiment to final
