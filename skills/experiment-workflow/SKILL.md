---
name: experiment-workflow
description: Experiment lifecycle management. Use when the user mentions experiments (e001, e002...), MANIFEST, experiment log, 실험 시작, 실험 현황, 실험 확정, or experiment finalization.
---

# Experiment Workflow Manager

실험 기반 분석 프로젝트의 전체 생애주기를 관리한다.
GitHub Project (칸반/마일스톤) + MANIFEST.yaml (결과 추적) + experiment-log.md (기록)을 통합.

실험 데이터의 상태(final/experimental/deprecated)를 추적하고, 보고서는 final 결과만 사용하여 환각을 방지한다.

## Recognition Pattern

- "e{NUM} 실험 시작" → /exp-workflow:exp-start
- "실험 현황" / "진행 상황" → /exp-workflow:exp-status
- "final로 해줘" / "확정" → /exp-workflow:exp-finalize
- "프로젝트 초기화" → /exp-workflow:exp-init
- "MANIFEST" / "결과 목록" → MANIFEST.yaml 확인

## Experiment Lifecycle

```
/exp-workflow:exp-init (1회)
    ↓
/exp-workflow:exp-start (각 실험마다)
    ↓
/ralplan → /ralph (반복적 계획-실행)
    ↓
/research (결과 비평)
    ↓
/exp-workflow:exp-finalize (final/deprecated)
    ↓
/detailed-report (final만 사용)
```

## Auto-Integration Rules

**자동으로 수행:**

1. **실험 시작 시**: omc-feature-start 호출 + outputs/MANIFEST.yaml 업데이트 + experiment-log.md 기록
2. **ralplan 완료 시**: omc-task-check 호출 + experiment-log.md 기록
3. **ralph 완료 시**: omc-task-check 호출 + experiment-log.md 실행 기록
4. **실험 확정 시**: MANIFEST status 변경 + experiment-log.md 확정 기록 + PR 제안
5. **/detailed-report 시**: MANIFEST final만 스캔
6. **/research 시**: experiment-log.md에 비평 기록

## MANIFEST.yaml Structure

```yaml
version: 1
updated: "2026-02-16T10:00:00Z"
scan_paths:
  - outputs/
experiments:
  e001:
    path: outputs/e001/
    script: "scripts/run_e001.py"
    params: {}
    outputs:
      - outputs/e001/result.csv
    status: final
    description: "Batch vs Streaming Analysis"
    issue: 50
    branch: feature-50
```

## Experiment Log Format

`experiment-log.md` (프로젝트 루트, 단일 파일, append-only):

```markdown
# Experiment Log

## 2026-02-16: e001 시작
- **목표**: Batch vs Streaming Analysis
- **Issue**: #50
- **Branch**: feature-50
- **Status**: started

## 2026-02-18: e001 확정 (final)
- **결과**: outputs/e001/result.csv
- **Issue**: #50
- **PR**: #55
```

## Anti-Patterns

- DON'T: manually edit MANIFEST, use experimental results in /detailed-report
- DO: always use /exp-start, keep MANIFEST and log in sync, mark final before reporting

## Dependencies

- omc-* scripts (~/bin/), .omc-config.sh, outputs/MANIFEST.yaml, experiment-log.md, gh CLI
