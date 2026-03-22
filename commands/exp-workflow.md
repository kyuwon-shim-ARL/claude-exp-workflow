---
description: "실험 워크플로우 마스터 명령어 - 서브커맨드 라우팅 + 기본 현황 조회 (global)"
allowed-tools: ["Bash", "Read"]
---

# /exp-workflow - Master Command

실험 워크플로우의 진입점. 서브커맨드가 있으면 해당 명령으로 라우팅하고, 없으면 현황 조회(`/exp-status`)를 실행한다.

User input: $ARGUMENTS

---

## Usage

```bash
/exp-workflow                          # 현황 조회 (= /exp-status)
/exp-workflow status                   # 현황 조회
/exp-workflow status e003              # 특정 실험 상세 (= /exp-status e003)
/exp-workflow start e005 "목표"        # 실험 시작 (= /exp-start e005 "목표")
/exp-workflow finalize e005            # 실험 확정 (= /exp-finalize e005)
/exp-workflow init                     # 프로젝트 초기화 (= /exp-init)
/exp-workflow milestone [start|status|end]  # 마일스톤 관리 (= /exp-milestone)
/exp-workflow foundation [start|upgrade|status]  # Foundation 관리 (= /exp-foundation)
/exp-workflow help                     # 사용 가능한 서브커맨드 안내
```

## Routing Logic

ARGUMENTS를 파싱하여 첫 번째 토큰(서브커맨드)을 기준으로 라우팅한다.

### Step 1: Parse Subcommand

ARGUMENTS에서 첫 번째 단어를 추출하여 서브커맨드로 판단한다.

| 서브커맨드 | 라우팅 대상 | 전달할 인자 |
|-----------|------------|------------|
| (없음) | `/exp-workflow:exp-status` | (없음) |
| `status` | `/exp-workflow:exp-status` | 나머지 인자 (e.g., `e003`) |
| `start` | `/exp-workflow:exp-start` | 나머지 인자 (e.g., `e005 "목표"`) |
| `finalize` | `/exp-workflow:exp-finalize` | 나머지 인자 (e.g., `e005`) |
| `init` | `/exp-workflow:exp-init` | 나머지 인자 |
| `milestone` | `/exp-workflow:exp-milestone` | 나머지 인자 (e.g., `start "v2.0"`) |
| `foundation` | `/exp-workflow:exp-foundation` | 나머지 인자 (e.g., `upgrade v3`) |
| `help` | 도움말 출력 | (없음) |

### Step 2: Korean Keyword Routing

서브커맨드가 위 테이블에 없으면, 한국어 키워드로 매칭을 시도한다.

| 키워드 패턴 | 라우팅 대상 |
|------------|------------|
| `현황`, `상태`, `진행` | `/exp-workflow:exp-status` |
| `시작`, `새 실험`, `새실험` | `/exp-workflow:exp-start` (나머지 인자 전달) |
| `확정`, `final`, `폐기`, `deprecated` | `/exp-workflow:exp-finalize` (나머지 인자 전달) |
| `초기화`, `init` | `/exp-workflow:exp-init` |
| `마일스톤` | `/exp-workflow:exp-milestone` (나머지 인자 전달) |
| `파운데이션`, `foundation` | `/exp-workflow:exp-foundation` (나머지 인자 전달) |

### Step 3: Fallback

서브커맨드도 키워드도 매칭되지 않으면:
- ARGUMENTS 전체를 컨텍스트로 간주하고 `/exp-workflow:exp-status`를 실행한다.
- 사용자에게 "인식되지 않는 서브커맨드입니다. 현황을 조회합니다." 메시지를 출력한다.

### Step 4: Execute Routed Skill

매칭된 skill을 Skill tool로 호출한다:

```
Skill(skill="exp-workflow:exp-status", args="{remaining_args}")
Skill(skill="exp-workflow:exp-start", args="{remaining_args}")
Skill(skill="exp-workflow:exp-finalize", args="{remaining_args}")
Skill(skill="exp-workflow:exp-init", args="{remaining_args}")
Skill(skill="exp-workflow:exp-milestone", args="{remaining_args}")
Skill(skill="exp-workflow:exp-foundation", args="{remaining_args}")
```

## Help Output

`/exp-workflow help` 또는 매칭 실패 시 표시:

```
Experiment Workflow - 실험 생애주기 관리

Usage: /exp-workflow [subcommand] [args...]

Subcommands:
  (none)       현황 조회 (= /exp-status)
  status       실험 현황 통합 조회
  start        새 실험 시작
  finalize     실험 확정/폐기
  init         프로젝트 초기화
  milestone    마일스톤 관리 (start/status/end)
  foundation   Foundation 관리 (start/upgrade/status)
  help         이 도움말 표시

Examples:
  /exp-workflow                    # 전체 현황
  /exp-workflow start e005 "목표"  # 실험 시작
  /exp-workflow finalize e005      # 실험 확정
  /exp-workflow milestone status   # 마일스톤 현황

Shortcuts:
  /exp-status, /exp-start, /exp-finalize 등 개별 명령도 사용 가능
```

## Related Commands

- `/exp-init`: 프로젝트 초기화
- `/exp-start`: 실험 시작
- `/exp-status`: 현황 조회
- `/exp-finalize`: 실험 확정/폐기
- `/exp-milestone`: 마일스톤 관리
- `/exp-foundation`: Foundation 관리
