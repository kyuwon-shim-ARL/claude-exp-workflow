---
name: experiment-workflow
description: Experiment lifecycle management. This skill should be activated when the user mentions experiments (e001, e002...), MANIFEST, experiment log, 실험 시작, 실험 현황, 실험 확정, experiment finalization, 마일스톤 시작, 마일스톤 현황, 마일스톤 종료, or milestone management.
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
- "마일스톤 시작" / "milestone start" → /exp-milestone start
- "마일스톤 현황" / "milestone status" → /exp-milestone status
- "마일스톤 종료" / "milestone end" → /exp-milestone end
- "MANIFEST" / "결과 목록" → MANIFEST.yaml 확인

## Experiment Lifecycle

```
/exp-workflow:exp-init (1회)
    ↓
/exp-milestone start (선택, 마일스톤 생성)
    ↓
/exp-workflow:exp-start (각 실험마다, 활성 마일스톤 자동 연결)
    ↓
/ralplan → /ralph (반복적 계획-실행)
    ↓
/research (결과 비평)
    ↓
/exp-workflow:exp-finalize (final/deprecated)
    ↓
/exp-milestone end (마일스톤 종료)
    ↓
/detailed-report (final만 사용)
```

## Auto-Integration Rules

**자동으로 수행:**

1. **실험 시작 시**: omc-feature-start 호출 + outputs/MANIFEST.yaml 업데이트 + experiment-log.md 기록
2. **ralplan 완료 시**: omc-task-check 호출 + experiment-log.md 기록
3. **ralph 실행 시**: 스크립트 실행 후 MANIFEST의 `script:` 및 `params:` 자동 갱신
   - `script:`: 실행된 메인 스크립트 경로 (예: `scripts/run_e001.py`)
   - `params:`: 실행에 사용된 주요 파라미터 딕셔너리
4. **ralph 완료 시**: omc-task-check 호출 + experiment-log.md 실행 기록
5. **실험 확정 시**: MANIFEST status 변경 + `outputs:` 자동 탐지 갱신 + experiment-log.md 확정 기록 + PR 제안
6. **/detailed-report 시**: MANIFEST final만 스캔
7. **/research 시**: experiment-log.md에 비평 기록
8. **마일스톤 시작 시**: omc-milestone-start 호출 + MANIFEST milestone 블록 설정 + experiment-log.md 기록
9. **마일스톤 종료 시**: omc-milestone-end 호출 + MANIFEST milestone 블록 초기화 + experiment-log.md 기록
10. **실험 시작 시 마일스톤 자동 연결**: MANIFEST milestone.title이 있으면 실험 항목에 milestone 필드 자동 추가

## MANIFEST.yaml Structure

```yaml
version: 2
updated: "2026-02-16T10:00:00Z"
scan_paths:
  - outputs/
milestone:
  title: "v1.0-foundation"
  created: "2026-02-16T10:00:00Z"
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
    milestone: "v1.0-foundation"
```

**Backwards Compatibility**: version 1 MANIFESTs (without `milestone` block) are fully supported. Missing milestone fields are treated as "no milestone".

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

- DON'T: manually edit MANIFEST status/experiments (use commands instead), use experimental results in /detailed-report, call omc-milestone-* CLI directly (use /exp-milestone instead)
- DO: always use /exp-start, keep MANIFEST and log in sync, mark final before reporting, use /exp-milestone for milestone management
- NOTE: `script:`, `params:`, `outputs:` fields are auto-populated by /ralph execution and /exp-finalize. These are the only MANIFEST fields that get updated outside of /exp-start and /exp-finalize.

## Dependencies

- omc-* scripts (~/bin/), .omc-config.sh, outputs/MANIFEST.yaml, experiment-log.md, gh CLI
