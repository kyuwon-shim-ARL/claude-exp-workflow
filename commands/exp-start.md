---
description: "새 실험 시작 - GitHub 이슈 생성 + 브랜치 + MANIFEST 등록 (global)"
allowed-tools: ["Bash", "Read", "Write", "Edit"]
---

# /exp-start - Start New Experiment

Start a new experiment with GitHub issue tracking, branch creation, and MANIFEST registration.

## Usage
```
/exp-start e005 ISM 윈도우 사이즈 최적화
```

## Workflow

### 1. Parse Arguments
Extract experiment number and goal from $ARGUMENTS:
- Pattern: `e{NUM} {goal description}`
- Example: "e005 ISM 윈도우 사이즈 최적화"

### 2. Validate Environment
Check `.omc-config.sh` exists:
- If missing: Instruct user to run `/exp-init` first
- If exists: Proceed to next step

### 3. Create GitHub Feature Issue
Execute:
```bash
omc-feature-start --type feature "e{NUM}: {goal}" \
  "Plan 작성" \
  "실험 실행" \
  "결과 검증" \
  "결과 해석"
```

Capture: Issue number, Branch name, GitHub URL

### 4. Update MANIFEST.yaml
Add new experiment entry and update root timestamp in `outputs/MANIFEST.yaml`:

```yaml
updated: "YYYY-MM-DDTHH:MM:SSZ"  # root updated: refresh on every change
experiments:
  e{NUM}:
    path: outputs/e{NUM}/
    script: ""  # to be filled during execution
    params: {}
    outputs: []
    status: experimental
    description: "{goal}"
    issue: {issue_number}
    branch: {branch_name}
```

Handle cases:
- `outputs/` directory doesn't exist → Create it
- `MANIFEST.yaml` doesn't exist → Create with template structure
- Experiment number already exists → Error with clear message

### 5. Update Experiment Log
Append to `experiment-log.md`:

```markdown
## YYYY-MM-DD: e{NUM} 시작
- **목표**: {goal}
- **Issue**: #{issue_number}
- **Branch**: {branch_name}
- **Status**: started
```

If `experiment-log.md` doesn't exist, create it with header.

### 6. Display Summary
```
Experiment e{NUM} started successfully.

Issue: #{issue_number}
Branch: {branch_name}
GitHub: {github_url}

Next steps:
1. Run /ralplan to create detailed experiment plan
2. Execute experiment script
3. Use /exp-finalize to finalize results
```

## Error Handling

| Condition | Action |
|-----------|--------|
| No arguments provided | Show error: "Usage: /exp-start e{NUM} {goal description}" |
| Missing `.omc-config.sh` | Show error: "Run /exp-init first" |
| Experiment number exists in MANIFEST | Show error: "e{NUM} already exists. Use a different number." |
| `omc-feature-start` fails | Show error with CLI output, don't proceed |
| MANIFEST.yaml parse error | Show error with file location and syntax issue |

## Dependencies
- `.omc-config.sh` must exist
- `omc-feature-start` CLI available in PATH
