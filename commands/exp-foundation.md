---
description: "Foundation 버전 관리 - 선언/업그레이드/현황 (global)"
allowed-tools: ["Bash", "Read", "Write", "Edit"]
---

# /exp-foundation - Foundation Version Management

Manage foundation versions that track the experimental pipeline configuration. When a foundation is upgraded, downstream experiments can be marked as stale.

## Usage

```bash
/exp-foundation start v1 "Initial pipeline: Cleanlab + 5-fold CV"
/exp-foundation upgrade v2 "Nested CV + Y-randomization baseline"
/exp-foundation upgrade v2 "Nested CV" --changed-components cv
/exp-foundation status
```

## Arguments
- `$ARGUMENTS`: `start <version> <description>` | `upgrade <version> <description> [--changed-components comp1,comp2]` | `status`

## Subcommands

### start `<version>` `<description>`

Create the first foundation version for a project.

1. **Parse Arguments**: version (required, e.g. "v1"), description (required)
2. **Validate Environment**: Check `.omc-config.sh` and `outputs/MANIFEST.yaml` exist
3. **Check MANIFEST version**: If version < 3, auto-migrate to v3 (add `foundations: {}` block)
4. **Conflict Check**: If `foundations` already has entries, warn: "Foundations already exist. Use `upgrade` to add a new version."
5. **Update MANIFEST.yaml**:
   ```yaml
   version: 3
   updated: "YYYY-MM-DDTHH:MM:SSZ"
   foundations:
     v1:
       description: "Initial pipeline: Cleanlab + 5-fold CV"
       components: {}    # user fills in key-value pairs as needed
       status: current
       created: "YYYY-MM-DDTHH:MM:SSZ"
   ```
6. **Update experiment-log.md**: Append:
   ```markdown
   ## YYYY-MM-DD: Foundation v1 started
   - **Description**: Initial pipeline: Cleanlab + 5-fold CV
   - **Status**: current
   ```
7. **Display Summary**:
   ```
   Foundation v1 created (current).

   All new experiments will auto-link to foundation v1.
   Use /exp-foundation upgrade v2 "description" when pipeline changes.
   ```

### upgrade `<version>` `<description>` `[--changed-components comp1,comp2]`

Create a new foundation version and selectively mark downstream experiments as stale.

1. **Parse Arguments**: version (required), description (required), `--changed-components` (optional, comma-separated list of component keys that changed)
2. **Validate Environment**: Check `.omc-config.sh` and `outputs/MANIFEST.yaml` exist
3. **Version Conflict**: If version already exists in `foundations`, error: "Foundation {version} already exists."
4. **Identify Current Foundation**: Find the foundation with `status: current`
5. **List Affected Experiments** (selective stale propagation):

   **If `--changed-components` is provided** (e.g., `--changed-components cv,labels`):
   - Parse comma-separated component list
   - For each experiment on the current foundation with `status` = `final` or `experimental`:
     - If experiment has `depends_on_components`: check intersection with changed components
     - If experiment has NO `depends_on_components`: treat as "depends on all" → always affected
     - Intersection not empty → affected. Empty → NOT affected (skipped).

   **If `--changed-components` is NOT provided**:
   - ALL experiments on the current foundation are affected (v1.3.0 behavior)

   Display the list:
   ```
   Foundation upgrade: v1 → v2
   Changed components: cv

   The following experiments will be marked stale:
     e014 (final)  - E vs EP separability [depends: labels, cv, models]
     e015 (final)  - Feature selection [depends: all (unspecified)]

   Skipped (not affected):
     e024 (final)  - Descriptor 계산 [depends: labels]

   2 experiments affected, 1 skipped. Proceed? [Y/n]
   ```

6. **On User Confirmation**:
   - Set old foundation `status: stale`
   - Create new foundation with `status: current`
   - For each affected experiment: set `stale: true` and `stale_reason: "changed components: cv,labels"`
   - Skipped experiments: leave `stale: false` (unchanged)
   - Update root `updated` timestamp
7. **Update MANIFEST.yaml**:
   ```yaml
   version: 3
   updated: "YYYY-MM-DDTHH:MM:SSZ"
   foundations:
     v1:
       description: "Initial pipeline"
       components: {}
       status: stale
       created: "2026-02-01T..."
     v2:
       description: "Nested CV + Y-randomization baseline"
       components: {}
       status: current
       created: "YYYY-MM-DDTHH:MM:SSZ"
   experiments:
     e014:
       foundation: v1
       status: final
       stale: true
       # ... other fields unchanged
   ```
8. **Update experiment-log.md**: Append:
   ```markdown
   ## YYYY-MM-DD: Foundation upgraded v1 → v2
   - **Description**: Nested CV + Y-randomization baseline
   - **Changed components**: cv (or "all" if --changed-components not specified)
   - **Stale experiments**: e014, e015 (2 total)
   - **Skipped experiments**: e024 (1 total, not affected)
   - **Previous foundation**: v1 (now stale)
   ```
9. **Display Summary**:
   ```
   Foundation v2 created (current).
   Foundation v1 marked stale.
   2 experiments marked stale (changed: cv).
   1 experiment skipped (not affected).

   Next: Re-run key experiments with /exp-start on foundation v2.
   ```

### status

Show all foundation versions and experiment counts.

1. **Read MANIFEST.yaml**: Parse `foundations` block
2. **Count experiments per foundation**: Group experiments by `foundation` field
3. **Display Dashboard**:
   ```
   Foundation Status

   Version | Description                    | Status  | Experiments
   v1      | Initial pipeline               | stale   | 3 final, 2 stale
   v2      | Nested CV + Y-randomization    | current | 1 experimental

   (no foundation): 2 experiments (legacy, pre-foundation)
   ```

## MANIFEST v2 → v3 Auto-Migration

When any foundation command is run on a v2 MANIFEST:

1. Add `foundations: {}` block (after `milestone` block)
2. Change `version: 2` to `version: 3`
3. Existing experiments remain unchanged (no `foundation` field = legacy)

**Backwards Compatibility**: v2 MANIFESTs (without `foundations` block) remain fully supported by all other commands. Foundation features are purely additive.

## Error Handling

| Condition | Action |
|-----------|--------|
| No subcommand | Show usage: `/exp-foundation start\|upgrade\|status` |
| `start` without version/description | Show usage |
| `upgrade` without version/description | Show usage |
| Missing `.omc-config.sh` | "Run /exp-init first." |
| Foundation version already exists | Error with message |
| No current foundation for upgrade | "No current foundation. Use `start` first." |
| No experiments affected by upgrade | Proceed without stale marking, inform user |
| `--changed-components` lists unknown component | Warning: "Component '{name}' not found in foundation {version}. Proceeding anyway." |
| `--changed-components` with empty value | Error: "Provide component names: --changed-components cv,labels" |

## Related Commands

- `/exp-init` - Initialize experiment tracking
- `/exp-start` - Start new experiment (auto-links to current foundation)
- `/exp-finalize` - Promote experiment to final
- `/exp-status` - View experiment dashboard (includes foundation info)
- `/exp-milestone` - Manage milestones
