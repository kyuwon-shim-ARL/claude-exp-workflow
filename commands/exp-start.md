---
description: "새 실험 시작 - GitHub 이슈 생성 + 브랜치 + MANIFEST 등록 (global)"
allowed-tools: ["Bash", "Read", "Write", "Edit"]
---

# /exp-start - Start New Experiment

Start a new experiment with GitHub issue tracking, branch creation, and MANIFEST registration.

## Usage
```
/exp-start e005 ISM 윈도우 사이즈 최적화
/exp-start e005 --milestone "v2.0" ISM 윈도우 사이즈 최적화
/exp-start e005 --depends-on labels,cv ISM 윈도우 사이즈 최적화
```

## Workflow

### 1. Parse Arguments
Extract experiment number, optional flags, and goal from $ARGUMENTS:
- Pattern: `e{NUM} [--milestone "title"] [--depends-on comp1,comp2] {goal description}`
- Example: "e005 ISM 윈도우 사이즈 최적화"
- Example: "e005 --milestone v2.0 ISM 윈도우 사이즈 최적화"
- Example: "e005 --depends-on labels,cv ISM 윈도우 사이즈 최적화"

If `--milestone` is provided, use that value. Otherwise, fall back to MANIFEST `milestone.title`.
If `--depends-on` is provided, parse comma-separated component names for `depends_on_components`. Otherwise, omit the field (= depends on all components).

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

### 4. Set Start Date on GitHub Project
If `OMC_DATE_START_FIELD_ID` is configured in `.omc-config.sh`, set the experiment's start date on the GitHub Project item for Roadmap view display.

This is handled automatically by `omc-feature-start` — no manual action needed. The start date is set to today's date (`YYYY-MM-DD`).

### 5. Update MANIFEST.yaml
Add new experiment entry and update root timestamp in `outputs/MANIFEST.yaml`.

**Milestone resolution order:**
1. `--milestone` 인자가 있으면 → 해당 값 사용
2. 없으면 → MANIFEST `milestone.title` 사용
3. 둘 다 없으면 → milestone 필드 생략

**Foundation auto-linking (v3 MANIFEST only):**
1. MANIFEST `foundations` 블록에서 `status: current`인 foundation 찾기
2. 있으면 → experiment에 `foundation` 필드 자동 추가 + `stale: false`
3. `--depends-on` 플래그가 있으면 → `depends_on_components` 필드 추가 (예: `[labels, cv]`)
4. `--depends-on` 플래그가 없으면 → `depends_on_components` 필드 생략 (= 전체 의존)
5. foundation이 없으면 → foundation/stale/depends_on_components 필드 모두 생략 (v2 호환)

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
    milestone: "{milestone_title}"  # resolved from --milestone flag or MANIFEST, omit if none
    foundation: "v1"               # auto-linked from current foundation (v3 only, omit if none)
    depends_on_components: [labels, cv]  # from --depends-on flag (v3 only, omit if not specified = all)
    stale: false                   # false for new experiments (v3 only, omit if no foundation)
```

Handle cases:
- `outputs/` directory doesn't exist → Create it
- `MANIFEST.yaml` doesn't exist → Create with template structure
- Experiment number already exists → Error with clear message

### 6. Update Experiment Log
Append to `experiment-log.md`:

```markdown
## YYYY-MM-DD: e{NUM} 시작
- **목표**: {goal}
- **Issue**: #{issue_number}
- **Branch**: {branch_name}
- **Milestone**: {milestone_title or "none"}
- **Status**: started
```

If `experiment-log.md` doesn't exist, create it with header.

### 7. Display Summary
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
