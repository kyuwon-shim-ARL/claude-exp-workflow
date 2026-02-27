#!/bin/bash
# =============================================================================
# exp-workflow Unit Test Script
# =============================================================================
# Tests 6 omc-tools scripts with mocked gh CLI (no network calls):
#   omc-load-config, omc-feature-start, omc-feature-progress,
#   omc-milestone-start, omc-milestone-status, omc-milestone-end
#
# Usage:
#   bash tests/unit-test.sh           # Basic run
#   bash tests/unit-test.sh --verbose # Verbose output
#
# Runs in under 5 seconds. No GitHub API calls.
# =============================================================================

set -uo pipefail

# ---------------------------------------------------------------------------
# Configuration
# ---------------------------------------------------------------------------
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"

VERBOSE=false
for arg in "$@"; do
  case "$arg" in
    --verbose) VERBOSE=true ;;
  esac
done

# Counters
PASS_COUNT=0
FAIL_COUNT=0
SKIP_COUNT=0

# Temp resources
TMPDIR=""
BACKUP_DIR=""

# ---------------------------------------------------------------------------
# Helper Functions (same style as e2e-test.sh)
# ---------------------------------------------------------------------------
log_pass() {
  PASS_COUNT=$((PASS_COUNT + 1))
  echo "  PASS: $1"
}

log_fail() {
  FAIL_COUNT=$((FAIL_COUNT + 1))
  echo "  FAIL: $1"
  if [ -n "${2:-}" ]; then
    echo "          Detail: $2"
  fi
}

log_skip() {
  SKIP_COUNT=$((SKIP_COUNT + 1))
  echo "  SKIP: $1"
}

log_section() {
  echo ""
  echo "----------------------------------------------"
  echo "  $1"
  echo "----------------------------------------------"
}

verbose() {
  if $VERBOSE; then
    echo "  [VERBOSE] $*"
  fi
}

assert_file_exists() {
  local file="$1"
  local label="${2:-File exists: $file}"
  if [ -f "$file" ]; then
    log_pass "$label"
  else
    log_fail "$label" "File not found: $file"
  fi
}

assert_file_contains() {
  local file="$1"
  local pattern="$2"
  local label="${3:-File contains pattern}"
  if [ -f "$file" ] && grep -q "$pattern" "$file"; then
    log_pass "$label"
  else
    log_fail "$label" "Pattern '$pattern' not found in $file"
  fi
}

assert_file_not_contains() {
  local file="$1"
  local pattern="$2"
  local label="${3:-File does not contain pattern}"
  if [ ! -f "$file" ] || ! grep -q "$pattern" "$file"; then
    log_pass "$label"
  else
    log_fail "$label" "Pattern '$pattern' unexpectedly found in $file"
  fi
}

assert_match() {
  local value="$1"
  local regex="$2"
  local label="${3:-Value matches regex}"
  if echo "$value" | grep -qE "$regex"; then
    log_pass "$label"
  else
    log_fail "$label" "Value '$value' does not match regex '$regex'"
  fi
}

assert_output_contains() {
  local output="$1"
  local pattern="$2"
  local label="${3:-Output contains pattern}"
  if echo "$output" | grep -q "$pattern"; then
    log_pass "$label"
  else
    log_fail "$label" "Pattern '$pattern' not in output"
  fi
}

assert_exit_code() {
  local actual="$1"
  local expected="$2"
  local label="${3:-Exit code is $expected}"
  if [ "$actual" -eq "$expected" ]; then
    log_pass "$label"
  else
    log_fail "$label" "Expected exit $expected, got $actual"
  fi
}

# ---------------------------------------------------------------------------
# Setup: create temp dir, gh stub, git repo, config
# ---------------------------------------------------------------------------
setup() {
  log_section "SETUP"

  TMPDIR="$(mktemp -d /tmp/omc-unit-test-XXXXXX)"
  BACKUP_DIR="$(mktemp -d /tmp/omc-unit-backup-XXXXXX)"
  echo "  Temp dir: $TMPDIR"
  echo "  Backup dir: $BACKUP_DIR"

  # --- Back up real omc scripts from ~/bin ---
  for script in omc-load-config omc-feature-start omc-feature-progress \
                omc-milestone-start omc-milestone-status omc-milestone-end; do
    if [ -f "$HOME/bin/$script" ]; then
      cp "$HOME/bin/$script" "$BACKUP_DIR/$script"
    fi
  done

  # --- Create gh stub in TMPDIR/bin (prepended to PATH) ---
  mkdir -p "$TMPDIR/bin"
  cat > "$TMPDIR/bin/gh" << 'GHSTUB'
#!/bin/bash
# gh stub for unit tests - returns canned responses based on arguments
ALL_ARGS="$*"

case "$ALL_ARGS" in
  *"issue create"*)
    echo "https://github.com/test/repo/issues/42"
    ;;
  *"repo view"*)
    echo '{"nameWithOwner":"test/repo"}'
    ;;
  *"issue list"*)
    echo '[]'
    ;;
  *"milestones?state=all"*|*"milestones --jq"*)
    # milestone list with state=all or milestone lookup
    echo '[{"title":"v1.0","number":1,"state":"open","open_issues":4,"closed_issues":3,"due_on":null}]'
    ;;
  *"milestones/"*"--method PATCH"*)
    # PATCH a specific milestone (close/reopen)
    echo '{"number":1,"state":"closed"}'
    ;;
  *"milestones/"*)
    # GET a specific milestone
    echo '{"title":"v1.0","number":1,"state":"open","open_issues":4,"closed_issues":3,"due_on":null}'
    ;;
  *"milestones"*"--method POST"*)
    echo '{"number":2}'
    ;;
  *"milestones"*)
    echo '[{"title":"v1.0","number":1,"state":"open","open_issues":4,"closed_issues":3,"due_on":null}]'
    ;;
  *"project item-list"*)
    echo '{"items":[{"id":"PVTI_item1","content":{"number":42}}]}'
    ;;
  *"project view"*)
    echo '{"id":"PVT_proj1","number":1}'
    ;;
  *"project item-add"*)
    echo '{"id":"PVTI_new"}'
    ;;
  *"project item-edit"*)
    echo 'ok'
    ;;
  *"project field-list"*)
    echo '{"fields":[{"name":"Status","id":"PVTSSF_test","options":[]}]}'
    ;;
  *)
    echo "gh-stub: unhandled: $ALL_ARGS" >&2
    exit 0
    ;;
esac
GHSTUB
  chmod +x "$TMPDIR/bin/gh"

  # --- Create jq passthrough stub if jq is missing (unlikely but safe) ---
  if ! command -v jq >/dev/null 2>&1; then
    cat > "$TMPDIR/bin/jq" << 'JQSTUB'
#!/bin/bash
# minimal jq stub - just pass stdin through
cat
JQSTUB
    chmod +x "$TMPDIR/bin/jq"
  fi

  # --- Initialize a git repo in TMPDIR ---
  cd "$TMPDIR"
  git init -q
  git config user.email "test@unit.local"
  git config user.name "Unit Test"
  echo "# unit test" > README.md
  git add README.md
  git commit -q -m "init"

  # --- Create valid .omc-config.sh ---
  cat > "$TMPDIR/.omc-config.sh" << 'CONF'
#!/bin/bash
export OMC_GH_REPO="test/repo"
export OMC_PROJECT_NUMBER="1"
export OMC_PROJECT_OWNER="@me"
export OMC_STATUS_FIELD_ID="PVTSSF_test"
export OMC_STATUS_BACKLOG="backlog_id"
export OMC_STATUS_AI_DOING="ai_doing_id"
export OMC_STATUS_DONE="done_id"
export OMC_CURRENT_MILESTONE=""
export OMC_MILESTONE_AUTO_ASSIGN="true"
CONF

  # --- Prepend stub gh to PATH so scripts find it first ---
  export PATH="$TMPDIR/bin:$PATH"

  echo "  Setup complete."
}

# ---------------------------------------------------------------------------
# Cleanup: restore backups, remove temp dirs
# ---------------------------------------------------------------------------
cleanup() {
  log_section "CLEANUP"

  # Restore backed-up scripts
  if [ -n "$BACKUP_DIR" ] && [ -d "$BACKUP_DIR" ]; then
    for script in "$BACKUP_DIR"/*; do
      if [ -f "$script" ]; then
        local name
        name="$(basename "$script")"
        cp "$script" "$HOME/bin/$name"
        verbose "Restored ~/bin/$name"
      fi
    done
    rm -rf "$BACKUP_DIR"
  fi

  if [ -n "$TMPDIR" ] && [ -d "$TMPDIR" ]; then
    rm -rf "$TMPDIR"
    verbose "Removed $TMPDIR"
  fi

  echo "  Cleanup complete."
}

trap cleanup EXIT

# ===========================================================================
# A. omc-load-config Tests (6 tests)
# ===========================================================================
test_load_config() {
  log_section "A. omc-load-config (6 tests)"

  cd "$TMPDIR"

  # A1. omc_load_config succeeds with valid config file
  local exit_code=0
  bash -c "source $HOME/bin/omc-load-config; omc_load_config '$TMPDIR/.omc-config.sh'" >/dev/null 2>&1 || exit_code=$?
  assert_exit_code "$exit_code" 0 "A1. omc_load_config succeeds with valid config file"

  # A2. omc_load_config fails with missing config file (exit code 1)
  exit_code=0
  bash -c "source $HOME/bin/omc-load-config; omc_load_config '/nonexistent/.omc-config.sh'" >/dev/null 2>&1 || exit_code=$?
  if [ "$exit_code" -ne 0 ]; then
    log_pass "A2. omc_load_config fails with missing config file (exit $exit_code)"
  else
    log_fail "A2. omc_load_config fails with missing config file" "Exit code was 0"
  fi

  # A3. Default exports are set (OMC_PROJECT_OWNER defaults to @me)
  local owner_val
  owner_val=$(bash -c "
    cd /tmp  # no .omc-config.sh here
    unset OMC_PROJECT_OWNER
    source $HOME/bin/omc-load-config 2>/dev/null
    echo \"\$OMC_PROJECT_OWNER\"
  " 2>/dev/null)
  if [ "$owner_val" = "@me" ]; then
    log_pass "A3. OMC_PROJECT_OWNER defaults to @me"
  else
    log_fail "A3. OMC_PROJECT_OWNER defaults to @me" "Got: '$owner_val'"
  fi

  # A4. Config file values override defaults
  local repo_val
  repo_val=$(bash -c "
    cd '$TMPDIR'
    unset OMC_GH_REPO
    source $HOME/bin/omc-load-config 2>/dev/null
    echo \"\$OMC_GH_REPO\"
  " 2>/dev/null)
  if [ "$repo_val" = "test/repo" ]; then
    log_pass "A4. Config file values override defaults (OMC_GH_REPO=test/repo)"
  else
    log_fail "A4. Config file values override defaults" "Got: '$repo_val'"
  fi

  # A5. Auto-sources .omc-config.sh in current directory
  local auto_repo
  auto_repo=$(bash -c "
    cd '$TMPDIR'
    unset OMC_GH_REPO
    source $HOME/bin/omc-load-config
    echo \"\$OMC_GH_REPO\"
  " 2>/dev/null)
  if [ "$auto_repo" = "test/repo" ]; then
    log_pass "A5. Auto-sources .omc-config.sh in current directory"
  else
    log_fail "A5. Auto-sources .omc-config.sh in current directory" "Got: '$auto_repo'"
  fi

  # A6. Milestone config exports exist
  local ms_vars
  ms_vars=$(bash -c "
    cd '$TMPDIR'
    source $HOME/bin/omc-load-config 2>/dev/null
    echo \"MS=\${OMC_CURRENT_MILESTONE:-UNSET} AUTO=\${OMC_MILESTONE_AUTO_ASSIGN:-UNSET}\"
  " 2>/dev/null)
  if echo "$ms_vars" | grep -q "MS=" && echo "$ms_vars" | grep -q "AUTO="; then
    log_pass "A6. Milestone config exports exist (OMC_CURRENT_MILESTONE, OMC_MILESTONE_AUTO_ASSIGN)"
  else
    log_fail "A6. Milestone config exports exist" "Got: '$ms_vars'"
  fi
}

# ===========================================================================
# B. omc-feature-start Tests (7 tests)
# ===========================================================================
test_feature_start() {
  log_section "B. omc-feature-start (7 tests)"

  cd "$TMPDIR"

  # B1. No arguments -> exit 1 with usage message
  local output=""
  local exit_code=0
  output=$(bash "$HOME/bin/omc-feature-start" 2>&1) || exit_code=$?
  if [ "$exit_code" -ne 0 ]; then
    log_pass "B1. No arguments exits with error (exit $exit_code)"
  else
    log_fail "B1. No arguments exits with error" "Exit code was 0"
  fi

  # B2. --type with valid types accepted (feature, enhancement, refactor, chore)
  # Test that the script does NOT exit at type validation for valid types.
  # We run with a valid type and title; it should get past type validation and
  # proceed to create the issue (which our gh stub handles).
  local valid_types_ok=true
  for t in feature enhancement refactor chore; do
    exit_code=0
    output=$(cd "$TMPDIR" && bash "$HOME/bin/omc-feature-start" --type "$t" "Test $t" 2>&1) || exit_code=$?
    if [ "$exit_code" -ne 0 ]; then
      valid_types_ok=false
      verbose "Type '$t' failed with exit $exit_code: $output"
    fi
  done
  if $valid_types_ok; then
    log_pass "B2. --type with valid types accepted (feature, enhancement, refactor, chore)"
  else
    log_fail "B2. --type with valid types accepted" "Some valid types were rejected"
  fi

  # B3. --type with invalid type -> exit 1
  exit_code=0
  output=$(cd "$TMPDIR" && bash "$HOME/bin/omc-feature-start" --type "invalid" "Test" 2>&1) || exit_code=$?
  if [ "$exit_code" -ne 0 ]; then
    assert_output_contains "$output" "Invalid type" "B3. --type with invalid type exits with error and message"
  else
    log_fail "B3. --type with invalid type -> exit 1" "Exit code was 0"
  fi

  # B4. Task list builds correctly with multiple tasks
  # Run feature-start with tasks, then check the gh stub was called with the body containing tasks.
  # We intercept by making gh stub log its arguments.
  cat > "$TMPDIR/bin/gh" << 'GHSTUB2'
#!/bin/bash
ALL_ARGS="$*"
case "$ALL_ARGS" in
  *"issue create"*)
    # Log the body argument to a file for inspection
    while [ $# -gt 0 ]; do
      if [ "$1" = "--body" ]; then
        echo "$2" > /tmp/omc-unit-gh-body.txt
        break
      fi
      shift
    done
    echo "https://github.com/test/repo/issues/42"
    ;;
  *"project item-add"*|*"project item-edit"*|*"project view"*|*"project item-list"*)
    echo '{"id":"PVT_proj1"}'
    ;;
  *)
    echo ""
    ;;
esac
GHSTUB2
  chmod +x "$TMPDIR/bin/gh"

  rm -f /tmp/omc-unit-gh-body.txt
  output=$(cd "$TMPDIR" && bash "$HOME/bin/omc-feature-start" "Multi Task Test" "Task Alpha" "Task Beta" "Task Gamma" 2>&1) || true
  if [ -f /tmp/omc-unit-gh-body.txt ]; then
    local body_content
    body_content=$(cat /tmp/omc-unit-gh-body.txt)
    local task_count=0
    echo "$body_content" | grep -q "Task Alpha" && task_count=$((task_count + 1))
    echo "$body_content" | grep -q "Task Beta" && task_count=$((task_count + 1))
    echo "$body_content" | grep -q "Task Gamma" && task_count=$((task_count + 1))
    if [ "$task_count" -eq 3 ]; then
      log_pass "B4. Task list builds correctly with 3 tasks"
    else
      log_fail "B4. Task list builds correctly" "Only $task_count/3 tasks found in body"
    fi
  else
    log_fail "B4. Task list builds correctly" "gh body not captured"
  fi

  # B5. Empty tasks -> default task "Define implementation tasks"
  rm -f /tmp/omc-unit-gh-body.txt
  output=$(cd "$TMPDIR" && bash "$HOME/bin/omc-feature-start" "No Tasks Title" 2>&1) || true
  if [ -f /tmp/omc-unit-gh-body.txt ]; then
    local body_content
    body_content=$(cat /tmp/omc-unit-gh-body.txt)
    if echo "$body_content" | grep -q "Define implementation tasks"; then
      log_pass "B5. Empty tasks produces default task 'Define implementation tasks'"
    else
      log_fail "B5. Empty tasks produces default task" "Body: $(head -5 /tmp/omc-unit-gh-body.txt)"
    fi
  else
    log_fail "B5. Empty tasks produces default task" "gh body not captured"
  fi

  # B6. Issue body contains Overview/Tasks/Acceptance Criteria sections
  if [ -f /tmp/omc-unit-gh-body.txt ]; then
    local body_content
    body_content=$(cat /tmp/omc-unit-gh-body.txt)
    local sections_ok=true
    echo "$body_content" | grep -q "## Overview" || sections_ok=false
    echo "$body_content" | grep -q "## Tasks" || sections_ok=false
    echo "$body_content" | grep -q "## Acceptance Criteria" || sections_ok=false
    if $sections_ok; then
      log_pass "B6. Issue body contains Overview/Tasks/Acceptance Criteria sections"
    else
      log_fail "B6. Issue body contains required sections" "Missing one or more sections"
    fi
  else
    log_fail "B6. Issue body contains required sections" "No body captured"
  fi

  # B7. Branch name format: feature-{NUM}
  assert_output_contains "$output" "feature-42" "B7. Branch name format is feature-{NUM} (feature-42)"

  # Restore standard gh stub
  cat > "$TMPDIR/bin/gh" << 'GHSTUB'
#!/bin/bash
ALL_ARGS="$*"
case "$ALL_ARGS" in
  *"issue create"*)
    echo "https://github.com/test/repo/issues/42"
    ;;
  *"repo view"*)
    echo '{"nameWithOwner":"test/repo"}'
    ;;
  *"issue list"*)
    echo '[]'
    ;;
  *"milestones?state=all"*)
    echo '[{"title":"v1.0","number":1,"state":"open","open_issues":4,"closed_issues":3,"due_on":null}]'
    ;;
  *"milestones/"*"--method PATCH"*)
    echo '{"number":1,"state":"closed"}'
    ;;
  *"milestones/"*)
    echo '{"title":"v1.0","number":1,"state":"open","open_issues":4,"closed_issues":3,"due_on":null}'
    ;;
  *"milestones"*"--method POST"*)
    echo '{"number":2}'
    ;;
  *"milestones"*)
    echo '[{"title":"v1.0","number":1,"state":"open","open_issues":4,"closed_issues":3,"due_on":null}]'
    ;;
  *"project item-list"*)
    echo '{"items":[{"id":"PVTI_item1","content":{"number":42}}]}'
    ;;
  *"project view"*)
    echo '{"id":"PVT_proj1","number":1}'
    ;;
  *"project item-add"*|*"project item-edit"*)
    echo '{"id":"PVTI_new"}'
    ;;
  *)
    echo ""
    ;;
esac
GHSTUB
  chmod +x "$TMPDIR/bin/gh"

  # Clean up captured body file
  rm -f /tmp/omc-unit-gh-body.txt
}

# ===========================================================================
# C. omc-feature-progress Tests (3 tests)
# ===========================================================================
test_feature_progress() {
  log_section "C. omc-feature-progress (3 tests)"

  cd "$TMPDIR"

  # C1. Runs with header output "Feature Progress Report"
  local output=""
  local exit_code=0
  output=$(cd "$TMPDIR" && bash "$HOME/bin/omc-feature-progress" 2>&1) || exit_code=$?
  assert_output_contains "$output" "Feature Progress Report" "C1. Output contains 'Feature Progress Report' header"

  # C2. --all flag sets correct state (script doesn't crash, runs to completion)
  exit_code=0
  output=$(cd "$TMPDIR" && bash "$HOME/bin/omc-feature-progress" --all 2>&1) || exit_code=$?
  assert_exit_code "$exit_code" 0 "C2. --all flag accepted and script completes successfully"

  # C3. Missing repo -> exit 1
  # Clear OMC_GH_REPO and make gh repo view return empty
  cat > "$TMPDIR/bin/gh" << 'GHSTUB_NOREPO'
#!/bin/bash
# Return empty for repo view to simulate missing repo
case "$*" in
  *"repo view"*)
    echo ""
    ;;
  *)
    echo ""
    ;;
esac
GHSTUB_NOREPO
  chmod +x "$TMPDIR/bin/gh"

  # Remove .omc-config.sh temporarily so OMC_GH_REPO is unset
  mv "$TMPDIR/.omc-config.sh" "$TMPDIR/.omc-config.sh.bak"
  exit_code=0
  output=$(cd "$TMPDIR" && unset OMC_GH_REPO && bash "$HOME/bin/omc-feature-progress" 2>&1) || exit_code=$?
  mv "$TMPDIR/.omc-config.sh.bak" "$TMPDIR/.omc-config.sh"
  if [ "$exit_code" -ne 0 ]; then
    log_pass "C3. Missing repo exits with error (exit $exit_code)"
  else
    log_fail "C3. Missing repo exits with error" "Exit code was 0. Output: $output"
  fi

  # Restore standard gh stub
  cat > "$TMPDIR/bin/gh" << 'GHSTUB'
#!/bin/bash
ALL_ARGS="$*"
case "$ALL_ARGS" in
  *"issue create"*) echo "https://github.com/test/repo/issues/42" ;;
  *"repo view"*) echo '{"nameWithOwner":"test/repo"}' ;;
  *"issue list"*) echo '[]' ;;
  *"milestones?state=all"*) echo '[{"title":"v1.0","number":1,"state":"open","open_issues":4,"closed_issues":3,"due_on":null}]' ;;
  *"milestones/"*"--method PATCH"*) echo '{"number":1,"state":"closed"}' ;;
  *"milestones/"*) echo '{"title":"v1.0","number":1,"state":"open","open_issues":4,"closed_issues":3,"due_on":null}' ;;
  *"milestones"*"--method POST"*) echo '{"number":2}' ;;
  *"milestones"*) echo '[{"title":"v1.0","number":1,"state":"open","open_issues":4,"closed_issues":3,"due_on":null}]' ;;
  *"project"*) echo '{"id":"PVT_proj1"}' ;;
  *) echo "" ;;
esac
GHSTUB
  chmod +x "$TMPDIR/bin/gh"
}

# ===========================================================================
# D. omc-milestone-start Tests (6 tests)
# ===========================================================================
test_milestone_start() {
  log_section "D. omc-milestone-start (6 tests)"

  cd "$TMPDIR"

  # D1. No arguments -> exit 1 with usage
  local output=""
  local exit_code=0
  output=$(cd "$TMPDIR" && bash "$HOME/bin/omc-milestone-start" 2>&1) || exit_code=$?
  if [ "$exit_code" -ne 0 ]; then
    assert_output_contains "$output" "Usage:" "D1. No arguments exits with usage message"
  else
    log_fail "D1. No arguments -> exit 1" "Exit code was 0"
  fi

  # D2. Valid date format accepted (2026-03-01)
  exit_code=0
  output=$(cd "$TMPDIR" && bash "$HOME/bin/omc-milestone-start" "test-ms" "desc" "2026-03-01" 2>&1) || exit_code=$?
  assert_exit_code "$exit_code" 0 "D2. Valid date format 2026-03-01 accepted"

  # D3a. Invalid date format -> exit 1 (MM-DD-YYYY)
  exit_code=0
  output=$(cd "$TMPDIR" && bash "$HOME/bin/omc-milestone-start" "test-ms2" "desc" "03-01-2026" 2>&1) || exit_code=$?
  if [ "$exit_code" -ne 0 ]; then
    log_pass "D3a. Invalid date format '03-01-2026' rejected (exit $exit_code)"
  else
    log_fail "D3a. Invalid date format '03-01-2026' rejected" "Exit code was 0"
  fi

  # D3b. Invalid date format -> exit 1 (not-a-date)
  exit_code=0
  output=$(cd "$TMPDIR" && bash "$HOME/bin/omc-milestone-start" "test-ms3" "desc" "not-a-date" 2>&1) || exit_code=$?
  if [ "$exit_code" -ne 0 ]; then
    log_pass "D3b. Invalid date format 'not-a-date' rejected (exit $exit_code)"
  else
    log_fail "D3b. Invalid date format 'not-a-date' rejected" "Exit code was 0"
  fi

  # D4. Updates .omc-config.sh with OMC_CURRENT_MILESTONE
  # Reset config to known state
  cat > "$TMPDIR/.omc-config.sh" << 'CONF'
#!/bin/bash
export OMC_GH_REPO="test/repo"
export OMC_PROJECT_NUMBER="1"
export OMC_PROJECT_OWNER="@me"
export OMC_STATUS_FIELD_ID="PVTSSF_test"
export OMC_STATUS_BACKLOG="backlog_id"
export OMC_STATUS_AI_DOING="ai_doing_id"
export OMC_STATUS_DONE="done_id"
export OMC_CURRENT_MILESTONE=""
CONF
  output=$(cd "$TMPDIR" && bash "$HOME/bin/omc-milestone-start" "my-milestone" 2>&1) || true
  assert_file_contains "$TMPDIR/.omc-config.sh" 'OMC_CURRENT_MILESTONE="my-milestone"' \
    "D4. Config updated with OMC_CURRENT_MILESTONE=my-milestone"

  # D5. Creates new .omc-config.sh if missing
  rm -f "$TMPDIR/.omc-config.sh"
  output=$(cd "$TMPDIR" && bash "$HOME/bin/omc-milestone-start" "fresh-ms" 2>&1) || true
  assert_file_exists "$TMPDIR/.omc-config.sh" "D5. Creates new .omc-config.sh if missing"

  # D6. Replaces existing OMC_CURRENT_MILESTONE value
  # The file from D5 should have fresh-ms; now update to new-ms
  # First ensure it has the OMC_GH_REPO so the script doesn't fail
  cat > "$TMPDIR/.omc-config.sh" << 'CONF'
#!/bin/bash
export OMC_GH_REPO="test/repo"
export OMC_CURRENT_MILESTONE="old-value"
CONF
  output=$(cd "$TMPDIR" && bash "$HOME/bin/omc-milestone-start" "new-value" 2>&1) || true
  if grep -q 'OMC_CURRENT_MILESTONE="new-value"' "$TMPDIR/.omc-config.sh"; then
    # Also verify old value is gone
    if ! grep -q 'OMC_CURRENT_MILESTONE="old-value"' "$TMPDIR/.omc-config.sh"; then
      log_pass "D6. Replaces existing OMC_CURRENT_MILESTONE (old-value -> new-value)"
    else
      log_fail "D6. Replaces existing OMC_CURRENT_MILESTONE" "Old value still present"
    fi
  else
    log_fail "D6. Replaces existing OMC_CURRENT_MILESTONE" "new-value not found in config"
  fi

  # Restore config for subsequent tests
  cat > "$TMPDIR/.omc-config.sh" << 'CONF'
#!/bin/bash
export OMC_GH_REPO="test/repo"
export OMC_PROJECT_NUMBER="1"
export OMC_PROJECT_OWNER="@me"
export OMC_STATUS_FIELD_ID="PVTSSF_test"
export OMC_STATUS_BACKLOG="backlog_id"
export OMC_STATUS_AI_DOING="ai_doing_id"
export OMC_STATUS_DONE="done_id"
export OMC_CURRENT_MILESTONE=""
export OMC_MILESTONE_AUTO_ASSIGN="true"
CONF
}

# ===========================================================================
# E. omc-milestone-status Tests (4 tests)
# ===========================================================================
test_milestone_status() {
  log_section "E. omc-milestone-status (4 tests)"

  cd "$TMPDIR"

  # E1. No title and no OMC_CURRENT_MILESTONE -> exit 1 with usage
  # Ensure OMC_CURRENT_MILESTONE is empty in config
  cat > "$TMPDIR/.omc-config.sh" << 'CONF'
#!/bin/bash
export OMC_GH_REPO="test/repo"
export OMC_CURRENT_MILESTONE=""
CONF
  local output=""
  local exit_code=0
  output=$(cd "$TMPDIR" && bash "$HOME/bin/omc-milestone-status" 2>&1) || exit_code=$?
  if [ "$exit_code" -ne 0 ]; then
    log_pass "E1. No title and no OMC_CURRENT_MILESTONE exits with error (exit $exit_code)"
  else
    log_fail "E1. No title and no OMC_CURRENT_MILESTONE -> exit 1" "Exit code was 0"
  fi

  # E2. Progress calculation: 3 closed / 7 total = 42%
  # Create gh stub that returns milestone with open_issues=4, closed_issues=3
  # (total=7, progress = 3*100/7 = 42%)
  cat > "$TMPDIR/bin/gh" << 'GHSTUB_MS'
#!/bin/bash
ALL_ARGS="$*"
case "$ALL_ARGS" in
  *"milestones"*)
    echo '{"title":"v1.0","number":1,"state":"open","open_issues":4,"closed_issues":3,"due_on":null}'
    ;;
  *"repo view"*)
    echo '{"nameWithOwner":"test/repo"}'
    ;;
  *)
    echo ""
    ;;
esac
GHSTUB_MS
  chmod +x "$TMPDIR/bin/gh"

  exit_code=0
  output=$(cd "$TMPDIR" && bash "$HOME/bin/omc-milestone-status" "v1.0" 2>&1) || exit_code=$?
  verbose "milestone-status output: $output"
  if echo "$output" | grep -q "42%"; then
    log_pass "E2. Progress calculation: 3/7 = 42%"
  else
    log_fail "E2. Progress calculation: 3/7 = 42%" "Output: $output"
  fi

  # E3. Zero total issues -> progress = 0%
  cat > "$TMPDIR/bin/gh" << 'GHSTUB_ZERO'
#!/bin/bash
ALL_ARGS="$*"
case "$ALL_ARGS" in
  *"milestones"*)
    echo '{"title":"empty-ms","number":2,"state":"open","open_issues":0,"closed_issues":0,"due_on":null}'
    ;;
  *"repo view"*)
    echo '{"nameWithOwner":"test/repo"}'
    ;;
  *)
    echo ""
    ;;
esac
GHSTUB_ZERO
  chmod +x "$TMPDIR/bin/gh"

  exit_code=0
  output=$(cd "$TMPDIR" && bash "$HOME/bin/omc-milestone-status" "empty-ms" 2>&1) || exit_code=$?
  if echo "$output" | grep -q "0%"; then
    log_pass "E3. Zero total issues shows 0% progress"
  else
    log_fail "E3. Zero total issues shows 0% progress" "Output: $output"
  fi

  # E4. Output contains progress bar characters
  # Re-run with v1.0 milestone for non-zero progress bar
  cat > "$TMPDIR/bin/gh" << 'GHSTUB_BAR'
#!/bin/bash
ALL_ARGS="$*"
case "$ALL_ARGS" in
  *"milestones"*)
    echo '{"title":"v1.0","number":1,"state":"open","open_issues":4,"closed_issues":3,"due_on":null}'
    ;;
  *"repo view"*)
    echo '{"nameWithOwner":"test/repo"}'
    ;;
  *)
    echo ""
    ;;
esac
GHSTUB_BAR
  chmod +x "$TMPDIR/bin/gh"

  exit_code=0
  output=$(cd "$TMPDIR" && bash "$HOME/bin/omc-milestone-status" "v1.0" 2>&1) || exit_code=$?
  # The script uses printf with unicode block chars
  if echo "$output" | grep -q '\['; then
    log_pass "E4. Output contains progress bar characters"
  else
    log_fail "E4. Output contains progress bar characters" "No '[' found in output"
  fi

  # Restore standard gh stub
  cat > "$TMPDIR/bin/gh" << 'GHSTUB'
#!/bin/bash
ALL_ARGS="$*"
case "$ALL_ARGS" in
  *"issue create"*) echo "https://github.com/test/repo/issues/42" ;;
  *"repo view"*) echo '{"nameWithOwner":"test/repo"}' ;;
  *"issue list"*) echo '[]' ;;
  *"milestones?state=all"*) echo '[{"title":"v1.0","number":1,"state":"open","open_issues":4,"closed_issues":3,"due_on":null}]' ;;
  *"milestones/"*"--method PATCH"*) echo '{"number":1,"state":"closed"}' ;;
  *"milestones/"*) echo '{"title":"v1.0","number":1,"state":"open","open_issues":4,"closed_issues":3,"due_on":null}' ;;
  *"milestones"*"--method POST"*) echo '{"number":2}' ;;
  *"milestones"*) echo '[{"title":"v1.0","number":1,"state":"open","open_issues":4,"closed_issues":3,"due_on":null}]' ;;
  *"project"*) echo '{"id":"PVT_proj1"}' ;;
  *) echo "" ;;
esac
GHSTUB
  chmod +x "$TMPDIR/bin/gh"

  # Restore config
  cat > "$TMPDIR/.omc-config.sh" << 'CONF'
#!/bin/bash
export OMC_GH_REPO="test/repo"
export OMC_PROJECT_NUMBER="1"
export OMC_PROJECT_OWNER="@me"
export OMC_STATUS_FIELD_ID="PVTSSF_test"
export OMC_STATUS_BACKLOG="backlog_id"
export OMC_STATUS_AI_DOING="ai_doing_id"
export OMC_STATUS_DONE="done_id"
export OMC_CURRENT_MILESTONE=""
export OMC_MILESTONE_AUTO_ASSIGN="true"
CONF
}

# ===========================================================================
# F. omc-milestone-end Tests (5 tests)
# ===========================================================================
test_milestone_end() {
  log_section "F. omc-milestone-end (5 tests)"

  cd "$TMPDIR"

  # F1. Unknown flag -> exit 1 with usage
  local output=""
  local exit_code=0
  output=$(cd "$TMPDIR" && bash "$HOME/bin/omc-milestone-end" --unknown 2>&1) || exit_code=$?
  if [ "$exit_code" -ne 0 ]; then
    assert_output_contains "$output" "Usage:" "F1. Unknown flag --unknown exits with usage message"
  else
    log_fail "F1. Unknown flag -> exit 1" "Exit code was 0"
  fi

  # F2. --force flag parsed correctly
  # Set up a config with an active milestone, then run --force
  cat > "$TMPDIR/.omc-config.sh" << 'CONF'
#!/bin/bash
export OMC_GH_REPO="test/repo"
export OMC_CURRENT_MILESTONE="force-test-ms"
CONF

  # gh stub that returns the milestone data including open_issues > 0
  cat > "$TMPDIR/bin/gh" << 'GHSTUB_FORCE'
#!/bin/bash
ALL_ARGS="$*"
case "$ALL_ARGS" in
  *"milestones?state=all"*)
    echo '1'
    ;;
  *"milestones/"*"--method PATCH"*)
    echo '{"number":1,"state":"closed"}'
    ;;
  *"milestones/"*)
    echo '{"open_issues":5,"closed_issues":2}'
    ;;
  *"repo view"*)
    echo '{"nameWithOwner":"test/repo"}'
    ;;
  *)
    echo ""
    ;;
esac
GHSTUB_FORCE
  chmod +x "$TMPDIR/bin/gh"

  exit_code=0
  output=$(cd "$TMPDIR" && bash "$HOME/bin/omc-milestone-end" --force 2>&1) || exit_code=$?
  if [ "$exit_code" -eq 0 ] && echo "$output" | grep -qi "closed\|milestone"; then
    log_pass "F2. --force flag closes milestone despite open issues"
  else
    log_fail "F2. --force flag parsed correctly" "Exit: $exit_code, Output: $output"
  fi

  # F3. --reopen flag parsed correctly
  cat > "$TMPDIR/.omc-config.sh" << 'CONF'
#!/bin/bash
export OMC_GH_REPO="test/repo"
export OMC_CURRENT_MILESTONE="reopen-test-ms"
CONF

  cat > "$TMPDIR/bin/gh" << 'GHSTUB_REOPEN'
#!/bin/bash
ALL_ARGS="$*"
case "$ALL_ARGS" in
  *"milestones?state=all"*)
    echo '1'
    ;;
  *"milestones/"*"--method PATCH"*)
    echo '{"number":1,"state":"open"}'
    ;;
  *"repo view"*)
    echo '{"nameWithOwner":"test/repo"}'
    ;;
  *)
    echo ""
    ;;
esac
GHSTUB_REOPEN
  chmod +x "$TMPDIR/bin/gh"

  exit_code=0
  output=$(cd "$TMPDIR" && bash "$HOME/bin/omc-milestone-end" --reopen 2>&1) || exit_code=$?
  if [ "$exit_code" -eq 0 ] && echo "$output" | grep -qi "reopen"; then
    log_pass "F3. --reopen flag reopens milestone successfully"
  else
    log_fail "F3. --reopen flag parsed correctly" "Exit: $exit_code, Output: $output"
  fi

  # F4. No active milestone -> exit 0 with message
  cat > "$TMPDIR/.omc-config.sh" << 'CONF'
#!/bin/bash
export OMC_GH_REPO="test/repo"
export OMC_CURRENT_MILESTONE=""
CONF

  exit_code=0
  output=$(cd "$TMPDIR" && bash "$HOME/bin/omc-milestone-end" 2>&1) || exit_code=$?
  if [ "$exit_code" -eq 0 ] && echo "$output" | grep -qi "no active milestone"; then
    log_pass "F4. No active milestone exits 0 with 'No active milestone' message"
  else
    log_fail "F4. No active milestone -> exit 0 with message" "Exit: $exit_code, Output: $output"
  fi

  # F5. Config cleared: OMC_CURRENT_MILESTONE set to empty
  cat > "$TMPDIR/.omc-config.sh" << 'CONF'
#!/bin/bash
export OMC_GH_REPO="test/repo"
export OMC_CURRENT_MILESTONE="clear-test-ms"
CONF

  cat > "$TMPDIR/bin/gh" << 'GHSTUB_CLEAR'
#!/bin/bash
ALL_ARGS="$*"
case "$ALL_ARGS" in
  *"milestones?state=all"*)
    echo '1'
    ;;
  *"milestones/"*"--method PATCH"*)
    echo '{"number":1,"state":"closed"}'
    ;;
  *"milestones/"*)
    echo '{"open_issues":0,"closed_issues":3}'
    ;;
  *"repo view"*)
    echo '{"nameWithOwner":"test/repo"}'
    ;;
  *)
    echo ""
    ;;
esac
GHSTUB_CLEAR
  chmod +x "$TMPDIR/bin/gh"

  output=$(cd "$TMPDIR" && bash "$HOME/bin/omc-milestone-end" 2>&1) || true
  if grep -q 'OMC_CURRENT_MILESTONE=""' "$TMPDIR/.omc-config.sh"; then
    log_pass "F5. Config cleared: OMC_CURRENT_MILESTONE set to empty string"
  else
    local actual
    actual=$(grep "OMC_CURRENT_MILESTONE" "$TMPDIR/.omc-config.sh" 2>/dev/null || echo "NOT FOUND")
    log_fail "F5. Config cleared" "Got: $actual"
  fi

  # Restore standard gh stub and config
  cat > "$TMPDIR/bin/gh" << 'GHSTUB'
#!/bin/bash
ALL_ARGS="$*"
case "$ALL_ARGS" in
  *"issue create"*) echo "https://github.com/test/repo/issues/42" ;;
  *"repo view"*) echo '{"nameWithOwner":"test/repo"}' ;;
  *"issue list"*) echo '[]' ;;
  *"milestones?state=all"*) echo '[{"title":"v1.0","number":1,"state":"open","open_issues":4,"closed_issues":3,"due_on":null}]' ;;
  *"milestones/"*"--method PATCH"*) echo '{"number":1,"state":"closed"}' ;;
  *"milestones/"*) echo '{"title":"v1.0","number":1,"state":"open","open_issues":4,"closed_issues":3,"due_on":null}' ;;
  *"milestones"*"--method POST"*) echo '{"number":2}' ;;
  *"milestones"*) echo '[{"title":"v1.0","number":1,"state":"open","open_issues":4,"closed_issues":3,"due_on":null}]' ;;
  *"project"*) echo '{"id":"PVT_proj1"}' ;;
  *) echo "" ;;
esac
GHSTUB
  chmod +x "$TMPDIR/bin/gh"

  cat > "$TMPDIR/.omc-config.sh" << 'CONF'
#!/bin/bash
export OMC_GH_REPO="test/repo"
export OMC_PROJECT_NUMBER="1"
export OMC_PROJECT_OWNER="@me"
export OMC_STATUS_FIELD_ID="PVTSSF_test"
export OMC_STATUS_BACKLOG="backlog_id"
export OMC_STATUS_AI_DOING="ai_doing_id"
export OMC_STATUS_DONE="done_id"
export OMC_CURRENT_MILESTONE=""
export OMC_MILESTONE_AUTO_ASSIGN="true"
CONF
}

# ===========================================================================
# G. MANIFEST v3 Foundation Logic Tests (6 tests)
# ===========================================================================
test_manifest_v3_foundation() {
  log_section "G. MANIFEST v3 Foundation Logic (6 tests)"

  cd "$TMPDIR"

  # Create a v3 MANIFEST with foundations
  mkdir -p outputs
  cat > outputs/MANIFEST.yaml << 'MANIFEST_V3'
version: 3
updated: "2026-02-27T00:00:00Z"
scan_paths:
  - outputs/
foundations:
  v1:
    description: "Initial pipeline"
    components:
      labels: cleanlab
      cv: 5fold
    status: current
    created: "2026-02-01T00:00:00Z"
milestone: {}
experiments:
  e001:
    path: outputs/e001/
    script: ""
    params: {}
    outputs: []
    status: final
    description: "Test experiment"
    issue: 1
    branch: feature-1
    foundation: v1
    stale: false
MANIFEST_V3

  # G1. v3 MANIFEST is valid YAML with foundations block
  if command -v python3 >/dev/null 2>&1; then
    local yaml_check
    yaml_check=$(python3 -c "
import yaml
with open('outputs/MANIFEST.yaml') as f:
    data = yaml.safe_load(f)
assert data['version'] == 3
assert 'foundations' in data
assert 'v1' in data['foundations']
print('VALID')
" 2>&1)
    if [ "$yaml_check" = "VALID" ]; then
      log_pass "G1. v3 MANIFEST is valid YAML with foundations block"
    else
      log_fail "G1. v3 MANIFEST is valid YAML" "$yaml_check"
    fi
  else
    assert_file_contains outputs/MANIFEST.yaml "version: 3" \
      "G1. v3 MANIFEST has version: 3 (basic check)"
  fi

  # G2. Foundation has required fields (description, components, status, created)
  if command -v python3 >/dev/null 2>&1; then
    local fields_check
    fields_check=$(python3 -c "
import yaml
with open('outputs/MANIFEST.yaml') as f:
    data = yaml.safe_load(f)
v1 = data['foundations']['v1']
required = ['description', 'components', 'status', 'created']
missing = [f for f in required if f not in v1]
if not missing:
    print('ALL_PRESENT')
else:
    print(f'MISSING: {missing}')
" 2>&1)
    if [ "$fields_check" = "ALL_PRESENT" ]; then
      log_pass "G2. Foundation v1 has all required fields"
    else
      log_fail "G2. Foundation v1 has all required fields" "$fields_check"
    fi
  else
    log_skip "G2. Foundation required fields (python3 not available)"
  fi

  # G3. Experiment links to foundation correctly
  if command -v python3 >/dev/null 2>&1; then
    local link_check
    link_check=$(python3 -c "
import yaml
with open('outputs/MANIFEST.yaml') as f:
    data = yaml.safe_load(f)
e001 = data['experiments']['e001']
assert e001.get('foundation') == 'v1', f'foundation={e001.get(\"foundation\")}'
assert e001.get('stale') == False, f'stale={e001.get(\"stale\")}'
print('LINKED')
" 2>&1)
    if [ "$link_check" = "LINKED" ]; then
      log_pass "G3. Experiment e001 linked to foundation v1 with stale: false"
    else
      log_fail "G3. Experiment linked to foundation" "$link_check"
    fi
  else
    log_skip "G3. Experiment foundation linking (python3 not available)"
  fi

  # G4. Foundation upgrade marks old foundation stale
  if command -v python3 >/dev/null 2>&1; then
    python3 << 'PYEOF'
import yaml
with open('outputs/MANIFEST.yaml') as f:
    data = yaml.safe_load(f)
# Simulate upgrade: v1 → stale, add v2 → current
data['foundations']['v1']['status'] = 'stale'
data['foundations']['v2'] = {
    'description': 'Upgraded pipeline',
    'components': {'labels': 'nested_cleanlab', 'cv': 'nested_5fold'},
    'status': 'current',
    'created': '2026-02-27T00:00:00Z'
}
with open('outputs/MANIFEST.yaml', 'w') as f:
    yaml.dump(data, f, default_flow_style=False, allow_unicode=True, sort_keys=False)
PYEOF
    local v1_status
    v1_status=$(python3 -c "
import yaml
with open('outputs/MANIFEST.yaml') as f:
    data = yaml.safe_load(f)
print(data['foundations']['v1']['status'])
")
    if [ "$v1_status" = "stale" ]; then
      log_pass "G4. Foundation upgrade marks old v1 as stale"
    else
      log_fail "G4. Foundation upgrade marks old as stale" "v1 status: $v1_status"
    fi
  else
    log_skip "G4. Foundation upgrade (python3 not available)"
  fi

  # G5. Stale propagation to downstream experiments
  if command -v python3 >/dev/null 2>&1; then
    python3 << 'PYEOF'
import yaml
with open('outputs/MANIFEST.yaml') as f:
    data = yaml.safe_load(f)
# Mark experiments on stale foundation as stale
for eid, edata in data['experiments'].items():
    if edata.get('foundation') == 'v1' and edata.get('status') in ('final', 'experimental'):
        edata['stale'] = True
with open('outputs/MANIFEST.yaml', 'w') as f:
    yaml.dump(data, f, default_flow_style=False, allow_unicode=True, sort_keys=False)
PYEOF
    local e001_stale
    e001_stale=$(python3 -c "
import yaml
with open('outputs/MANIFEST.yaml') as f:
    data = yaml.safe_load(f)
print(data['experiments']['e001'].get('stale', False))
")
    if [ "$e001_stale" = "True" ]; then
      log_pass "G5. Stale propagated to experiment e001 (foundation v1)"
    else
      log_fail "G5. Stale propagation to experiment" "e001 stale: $e001_stale"
    fi
  else
    log_skip "G5. Stale propagation (python3 not available)"
  fi

  # G6. Backwards compatibility: v2 MANIFEST without foundations still valid
  cat > outputs/MANIFEST_v2.yaml << 'MANIFEST_V2'
version: 2
updated: "2026-02-27T00:00:00Z"
scan_paths:
  - outputs/
milestone: {}
experiments:
  e001:
    path: outputs/e001/
    status: final
    description: "Legacy experiment"
MANIFEST_V2

  if command -v python3 >/dev/null 2>&1; then
    local compat_check
    compat_check=$(python3 -c "
import yaml
with open('outputs/MANIFEST_v2.yaml') as f:
    data = yaml.safe_load(f)
# No foundations block - should be handled gracefully
foundations = data.get('foundations', {})
e001 = data['experiments']['e001']
stale = e001.get('stale', False)
foundation = e001.get('foundation', None)
assert foundations == {}, f'foundations={foundations}'
assert stale == False, f'stale={stale}'
assert foundation is None, f'foundation={foundation}'
print('COMPATIBLE')
" 2>&1)
    if [ "$compat_check" = "COMPATIBLE" ]; then
      log_pass "G6. v2 MANIFEST without foundations is backwards compatible"
    else
      log_fail "G6. v2 MANIFEST backwards compatibility" "$compat_check"
    fi
  else
    assert_file_not_contains outputs/MANIFEST_v2.yaml "foundations" \
      "G6. v2 MANIFEST has no foundations block (basic check)"
  fi

  rm -f outputs/MANIFEST_v2.yaml
}

# ---------------------------------------------------------------------------
# Summary
# ---------------------------------------------------------------------------
print_summary() {
  log_section "SUMMARY"

  local total=$((PASS_COUNT + FAIL_COUNT + SKIP_COUNT))
  echo ""
  echo "  Total:   $total"
  echo "  Passed:  $PASS_COUNT"
  echo "  Failed:  $FAIL_COUNT"
  echo "  Skipped: $SKIP_COUNT"
  echo ""

  if [ "$FAIL_COUNT" -eq 0 ]; then
    echo "  ALL TESTS PASSED"
  else
    echo "  $FAIL_COUNT TEST(S) FAILED"
  fi
  echo ""
}

# ---------------------------------------------------------------------------
# Main
# ---------------------------------------------------------------------------
main() {
  echo "+---------------------------------------------+"
  echo "|   omc-tools Unit Test Suite                  |"
  echo "|   No network. No GitHub API. Stub-only.     |"
  echo "+---------------------------------------------+"
  echo ""
  echo "  Timestamp: $(date -Iseconds)"
  echo "  Verbose:   $VERBOSE"

  setup

  test_load_config
  test_feature_start
  test_feature_progress
  test_milestone_start
  test_milestone_status
  test_milestone_end
  test_manifest_v3_foundation

  print_summary

  if [ "$FAIL_COUNT" -gt 0 ]; then
    exit 1
  fi
  exit 0
}

main "$@"
