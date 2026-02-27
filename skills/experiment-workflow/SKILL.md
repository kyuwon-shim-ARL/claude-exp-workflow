---
name: experiment-workflow
description: Experiment lifecycle management. This skill should be activated when the user mentions experiments (e001, e002...), MANIFEST, experiment log, 실험 시작, 실험 현황, 실험 확정, experiment finalization, 마일스톤 시작, 마일스톤 현황, 마일스톤 종료, milestone management, foundation, 파운데이션, stale, or pipeline version.
---

# Experiment Workflow Manager

실험 기반 분석 프로젝트의 전체 생애주기를 관리한다.
GitHub Project (칸반/마일스톤) + MANIFEST.yaml (결과 추적) + experiment-log.md (기록)을 통합.

실험 데이터의 상태(final/experimental/deprecated)를 추적하고, 보고서는 final + non-stale 결과만 사용하여 환각을 방지한다.

## Recognition Pattern

- "e{NUM} 실험 시작" → /exp-workflow:exp-start
- "실험 현황" / "진행 상황" → /exp-workflow:exp-status
- "final로 해줘" / "확정" → /exp-workflow:exp-finalize
- "프로젝트 초기화" → /exp-workflow:exp-init
- "마일스톤 시작" / "milestone start" → /exp-milestone start
- "마일스톤 현황" / "milestone status" → /exp-milestone status
- "마일스톤 종료" / "milestone end" → /exp-milestone end
- "foundation 시작" / "파운데이션" → /exp-foundation start
- "foundation 업그레이드" / "pipeline 변경" → /exp-foundation upgrade
- "foundation 현황" → /exp-foundation status
- "MANIFEST" / "결과 목록" → MANIFEST.yaml 확인

## Experiment Lifecycle

```
/exp-workflow:exp-init (1회)
    ↓
/exp-foundation start (선택, 파이프라인 기준선 선언)
    ↓
/exp-milestone start (선택, 마일스톤 생성)
    ↓
/exp-workflow:exp-start (각 실험마다, 활성 foundation + 마일스톤 자동 연결)
    ↓
/ralplan → /ralph (반복적 계획-실행)
    ↓
/research (결과 비평)
    ↓
/exp-workflow:exp-finalize (final/deprecated)
    ↓
/exp-foundation upgrade (파이프라인 변경 시, 하류 실험 stale 마킹)
    ↓
/exp-milestone end (마일스톤 종료)
    ↓
/detailed-report (final + non-stale만 사용)
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
6. **/detailed-report 시**: MANIFEST에서 `status: final` AND (`stale: false` OR stale 필드 없음)인 실험만 스캔
7. **/research 시**: experiment-log.md에 비평 기록
8. **마일스톤 시작 시**: omc-milestone-start 호출 + MANIFEST milestone 블록 설정 + experiment-log.md 기록
9. **마일스톤 종료 시**: omc-milestone-end 호출 + MANIFEST milestone 블록 초기화 + experiment-log.md 기록
10. **실험 시작 시 마일스톤 자동 연결**: MANIFEST milestone.title이 있으면 실험 항목에 milestone 필드 자동 추가
11. **실험 시작 시 foundation 자동 연결**: MANIFEST foundations에서 `status: current`인 항목이 있으면 실험 항목에 `foundation` 필드 자동 추가 + `stale: false` 설정

## MANIFEST.yaml Structure

```yaml
version: 3
updated: "2026-02-27T10:00:00Z"
scan_paths:
  - outputs/
foundations:
  v1:
    description: "Initial pipeline: Cleanlab + stratified 5-fold CV"
    components:
      labels: "cleanlab_full_dataset"
      cv: "stratified_5fold"
      models: "xgboost"
    status: stale
    created: "2026-02-01T10:00:00Z"
  v2:
    description: "Nested CV + Y-randomization baseline"
    components:
      labels: "nested_cleanlab_cv"
      cv: "nested_5fold"
      models: "xgboost, rf, logreg_l1"
      baselines: "y_randomization, random_flip"
    status: current
    created: "2026-02-27T10:00:00Z"
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
    foundation: v1
    stale: true
  e064:
    path: outputs/e064/
    script: ""
    params: {}
    outputs: []
    status: experimental
    description: "Y-randomization null distribution"
    issue: 60
    branch: feature-60
    foundation: v2
    stale: false
```

### Foundation Fields

- `foundations`: Top-level block mapping version names to pipeline configurations
  - `description`: Human-readable description of the pipeline configuration
  - `components`: Free-form key-value pairs describing pipeline components (domain-agnostic)
  - `status`: `current` (active) or `stale` (superseded by a newer version)
  - `created`: ISO 8601 timestamp
- `experiment.foundation`: Links experiment to the foundation version it was run under
- `experiment.stale`: `true` if the experiment's foundation has been superseded. Stale experiments should be re-run or their results treated with caution.

### Status Semantics

| Status | Meaning | Report Inclusion |
|--------|---------|-----------------|
| `experimental` | Work in progress | Excluded |
| `final` | Validated and complete | Included (if not stale) |
| `final` + `stale: true` | Valid under old pipeline | Excluded from /detailed-report |
| `deprecated` | Permanently invalidated | Excluded |

**Backwards Compatibility**: version 1 MANIFESTs (without `milestone` block) and version 2 MANIFESTs (without `foundations` block) are fully supported. Missing foundation fields are treated as "no foundation". Missing stale field is treated as "not stale".

## Experiment Log Format

`experiment-log.md` (프로젝트 루트, 단일 파일, append-only):

```markdown
# Experiment Log

## 2026-02-16: e001 시작
- **목표**: Batch vs Streaming Analysis
- **Issue**: #50
- **Branch**: feature-50
- **Foundation**: v1
- **Status**: started

## 2026-02-18: e001 확정 (final)
- **결과**: outputs/e001/result.csv
- **Issue**: #50
- **PR**: #55

## 2026-02-27: Foundation upgraded v1 → v2
- **Description**: Nested CV + Y-randomization baseline
- **Stale experiments**: e001 (1 total)
- **Previous foundation**: v1 (now stale)
```

## Anti-Patterns

- DON'T: manually edit MANIFEST status/experiments (use commands instead), use experimental results in /detailed-report, use stale results in /detailed-report, call omc-milestone-* CLI directly (use /exp-milestone instead)
- DO: always use /exp-start, keep MANIFEST and log in sync, mark final before reporting, use /exp-milestone for milestone management, use /exp-foundation for pipeline versioning
- NOTE: `script:`, `params:`, `outputs:` fields are auto-populated by /ralph execution and /exp-finalize. These are the only MANIFEST fields that get updated outside of /exp-start and /exp-finalize.
- NOTE: `foundation` and `stale` fields are managed by /exp-start (auto-link) and /exp-foundation upgrade (stale marking). Do not manually edit these fields.

## Foundation Usage Scenarios

AI 에이전트(/sciomc, /ralph, /ralplan 등)가 foundation 기능을 활용할 때 따라야 하는 구체적 시나리오.

### Scenario 1: 프로젝트 초기 - Foundation 선언

**트리거**: `/exp-init` 직후, 첫 실험 시작 전
**행동**: 현재 파이프라인 구성을 foundation으로 선언

```
/exp-foundation start v1 "현재 파이프라인 설명"
```

**판단 기준**: MANIFEST에 `foundations` 블록이 비어있고 (`foundations: {}`), 실험을 시작하려는 시점

### Scenario 2: 실험 시작 - Foundation 자동 연결

**트리거**: `/exp-start e{NUM} {goal}`
**행동**: 현재 `status: current`인 foundation을 자동으로 `foundation` 필드에 연결 + `stale: false` 설정
**에이전트 규칙**: foundation이 없으면 연결하지 않음 (v2 호환). 있으면 반드시 연결.

### Scenario 3: 파이프라인 변경 감지 - Foundation Upgrade

**트리거**: 다음 중 하나 발생 시
- 라벨링 파이프라인 변경 (예: Cleanlab 방식 변경, nested CV 도입)
- CV 전략 변경 (예: stratified → nested)
- 모델 구성 변경 (예: 모델 추가/제거)
- 데이터 전처리 방식 변경
- **비평(/research, /sciomc)에서 기존 파이프라인의 근본적 결함 지적**

**행동**:
```
/exp-foundation upgrade v2 "변경 내용 설명"
```

**에이전트 판단 흐름**:
```
비평 결과 분석
    │
    ├─ "기존 결과는 유효하지만 개선 여지 있음" → upgrade 불필요, 새 실험으로 개선
    │
    ├─ "파이프라인 자체에 결함 발견" → upgrade 필요
    │   (예: data leakage, CV 누수, 라벨 오류)
    │
    └─ "새로운 방법론이 기존을 대체" → upgrade 필요
        (예: nested CV가 기존 stratified CV를 대체)
```

### Scenario 4: Stale 실험 처리

**트리거**: `/exp-status`에서 stale 실험이 보일 때
**에이전트 판단 흐름**:
```
stale 실험 발견
    │
    ├─ 핵심 결과인가? ──────→ YES: /exp-start로 새 실험 (v2 foundation 위에서 재실행)
    │                              또는 /exp-finalize --reopen으로 기존 실험 재실행
    │
    ├─ 탐색적/예비 실험인가? ──→ 무시 (stale 상태 유지, 보고서에서 자동 제외됨)
    │
    └─ 완전히 무효인가? ────→ /exp-finalize --deprecate (deprecated 처리)
```

### Scenario 5: 보고서 작성 - Stale 필터링

**트리거**: `/detailed-report` 또는 `/learnlm-report` 실행 시
**행동**: MANIFEST에서 다음 조건을 만족하는 실험만 포함
```
status: final AND (stale: false OR stale 필드 없음)
```
**에이전트 규칙**: stale: true인 실험의 결과를 보고서에 절대 포함하지 않음. 단, "이전 파이프라인(v1)에서는 X였으나, v2에서 Y로 확인됨" 같은 비교 서술은 허용.

**하류 보고서 전파**: `/learnlm-report`는 `/detailed-report` 출력물만 소스로 사용하므로, `/detailed-report`에서 stale이 필터링되면 `/learnlm-report`에도 자동으로 반영됨. 별도 stale 필터링 불필요.

### Scenario 6: /sciomc 비평 후 Foundation Upgrade 판단

**트리거**: `/sciomc` 비평 결과에서 파이프라인 수준의 문제 발견
**에이전트 판단 흐름**:
```
/sciomc 비평 완료
    │
    ├─ 개별 실험의 개선점 → 해당 실험만 수정/재실행
    │
    └─ 파이프라인 수준 문제 발견 → 사용자에게 제안:
        "파이프라인 변경이 필요합니다. /exp-foundation upgrade를 권장합니다."
        사용자 승인 후 → /exp-foundation upgrade 실행
```

**중요**: 에이전트는 자체적으로 foundation upgrade를 실행하지 않음. 항상 사용자에게 먼저 제안하고 승인을 받은 후 실행.

### Scenario 7: 논문 제출 전 최종 검증

**트리거**: 사용자가 논문 준비 또는 최종 보고서 요청 시
**행동**:
1. `/exp-foundation status`로 현재 foundation 확인
2. `/exp-status`로 stale 실험 확인
3. stale인 핵심 실험이 있으면 → 재실행 권장
4. 모든 핵심 결과가 현재 foundation 위에 있으면 → 보고서 생성 진행

## Dependencies

- omc-* scripts (~/bin/), .omc-config.sh, outputs/MANIFEST.yaml, experiment-log.md, gh CLI
