# Task Documentation Standards

## Template Usage

All task files MUST use the standardized template from `TASK-TEMPLATE.md`.

## Section Naming Standards

### ✅ REQUIRED SECTIONS (use these names exactly):

**Header:**
- `# Task: [Name]` (title)
- `## Description` (what and why)
- `## Acceptance Criteria` (measurable completion requirements)

**Technical:**
- `## Technical Details` (implementation approach)
- `## Implementation Requirements` (specific technical specs)
- `## Dependencies` (what must exist first)

**Meta:**
- `## Effort Estimate` (size, hours, parallelization)
- `## Usage Examples` (how to use the deliverable)

### ❌ DEPRECATED/AVOID:

- ~~`Definition of Done`~~ → Use `Acceptance Criteria` instead
- ~~`Acceptance Requirements`~~ → Use `Acceptance Criteria` instead
- ~~`Success Criteria`~~ → Use `Acceptance Criteria` instead
- ~~`Completion Requirements`~~ → Use `Acceptance Criteria` instead

## Acceptance Criteria Format

```markdown
## Acceptance Criteria
- [ ] **Criterion Name**: Clear description of what must be accomplished
- [ ] **Integration requirement**: Must work with existing X system
- [ ] **Documentation**: Usage instructions provided
- [ ] **Testing**: Verification method specified
```

**When completed:**
```markdown
- [x] ✅ **Criterion Name**: Clear description - Implementation details/location
```

## Frontmatter Standards

```yaml
---
name: Task Name (matches GitHub issue title)
status: open|in_progress|completed
created: YYYY-MM-DDTHH:MM:SSZ
updated: YYYY-MM-DDTHH:MM:SSZ (when modified)
github: https://github.com/owner/repo/issues/N  # ONLY after GitHub issue created
depends_on: [2, 5]  # GitHub issue numbers
parallel: true|false
conflicts_with: []  # GitHub issue numbers that conflict
---
```

**⚠️ CRITICAL WORKFLOW RULE**: The `github:` field should ONLY be added AFTER the GitHub issue has been actually created. Never put a GitHub URL in advance - this causes sync confusion and --fix flag issues.

## Status Values

### Core Workflow States
- `open` - Not started, ready to begin
- `in_progress` - Currently being worked on
- `completed` - All acceptance criteria met, ready for integration

### Extended Workflow States
- `blocked` - Cannot proceed due to dependencies or external factors
- `pending` - Waiting for review, approval, or external input  
- `on_hold` - Temporarily suspended, may resume later
- `needs_review` - Implementation complete, requires validation

### Terminal States
- `abandoned` - Work stopped, will not be completed
- `wont_fix` - Valid issue but intentionally not implemented
- `duplicate` - Same as another task, reference other task

### Deprecated
- ~~`closed`~~ - Use `completed` instead
- ~~`wip`~~ - Use `in_progress` instead

### GitHub Provider Status Reference

**GitHub Issues** (official states):
- `open` - Issue is active and needs attention
- `closed` - Issue has been resolved or will not be worked on

**GitHub Projects** (built-in status values):
- `Todo` - This item hasn't been started (green)
- `In Progress` - This is actively being worked on (yellow)  
- `Done` - Item has been completed

**Our Extended Status System**:
Our status values map to GitHub providers as follows:
- `open` → GitHub Issues: `open`, GitHub Projects: `Todo`
- `in_progress` → GitHub Projects: `In Progress`
- `completed` → GitHub Issues: `closed`, GitHub Projects: `Done`
- `blocked`, `pending`, `on_hold`, `needs_review` → Custom workflow states (project-specific)
- Terminal states (`abandoned`, `wont_fix`, `duplicate`) → GitHub Issues: `closed`

### Other Provider Status Reference

**GitLab Issues** (official states):
- `opened` - Issue is active and needs attention
- `closed` - Issue has been resolved

**GitLab Merge Requests**:
- `opened`, `closed`, `locked`, `merged`

**Azure DevOps Work Items**:
- `New`, `Active`, `Resolved`, `Closed`, `Removed`

**Jira Issues**:
- `Open`, `In Progress`, `Resolved`, `Closed` (customizable workflow)

**Linear Issues**:
- `Backlog`, `Todo`, `In Progress`, `In Review`, `Done`, `Canceled`

### Provider Mapping Strategy

When integrating with different providers, our extended status system provides a flexible mapping layer:
- Core states (`open`, `in_progress`, `completed`) map to most providers
- Extended states provide granular workflow control within our system
- Terminal states handle edge cases across all providers


## Status Workflow

### Normal Flow:
```
open → in_progress → needs_review → completed
```

### Alternative Flows:
```
open → blocked → in_progress → completed
open → pending → in_progress → completed  
in_progress → on_hold → in_progress → completed
any_status → abandoned (terminal)
any_status → wont_fix (terminal)
any_status → duplicate (terminal)
```

### Status Change Triggers:
- `open` → `in_progress`: Work begins on task
- `in_progress` → `blocked`: Dependency or external factor prevents progress
- `blocked` → `in_progress`: Blocking factor resolved
- `in_progress` → `pending`: Waiting for review/approval/input
- `pending` → `in_progress`: Review/approval received, work resumes
- `in_progress` → `on_hold`: Temporarily suspended (resource constraints, priorities)
- `on_hold` → `in_progress`: Work resumes
- `in_progress` → `needs_review`: Implementation complete, needs validation
- `needs_review` → `completed`: Review passed, all criteria met
- `needs_review` → `in_progress`: Review feedback requires more work

### GitHub Issue Integration:
- **PRIMARY**: Update issue status field directly
- Add comments explaining status changes and blocking factors
- Use milestones for grouping related tasks
- Reference blocking/dependent issues in comments

## File Naming

- Task files: `N.md` where N matches GitHub issue number exactly
- Template: `TASK-TEMPLATE.md`
- Standards: `TASK-STANDARDS.md` (this file)

## Migration Checklist

When updating existing tasks to follow standards:

1. [ ] Replace `Definition of Done` with `Acceptance Criteria`
2. [ ] Use standard section names
3. [ ] Update frontmatter to use `completed` instead of `closed`
4. [ ] Ensure acceptance criteria use checkbox format
5. [ ] Add implementation details to completed criteria
6. [ ] Verify file name matches GitHub issue number

## Why Standardize?

- **Consistency**: All tasks follow same structure
- **Tooling**: Scripts can parse standard format reliably
- **Clarity**: Everyone knows where to find information
- **Maintenance**: Easier to update and manage tasks

Use `TASK-TEMPLATE.md` as the starting point for all new tasks.

## GitHub Integration Workflow

### Task Creation Lifecycle

**✅ CORRECT Workflow:**
1. Create local task file (27.md) with `github: # TO BE CREATED`
2. Run `/pm:sync` or `/pm:epic-sync` - creates GitHub issue #27
3. **SYSTEMATIC CHECK**: Extract GitHub issue number from URL
4. **AUTOMATIC VERIFICATION**: Does file name match GitHub number?
5. **IMMEDIATE RENAME**: If mismatch, rename file to match GitHub number
6. `/pm:sync` automatically updates frontmatter: `github: https://github.com/owner/repo/issues/27`
7. File name matches GitHub issue number ✅

**❌ INCORRECT Workflow (causes --fix issues):**
1. ❌ Create local task file (27.md) with `github: https://github.com/owner/repo/issues/27` 
2. `/pm:sync` gets confused - issue doesn't exist but URL is present
3. `--fix` flag cannot resolve phantom GitHub references
4. Manual cleanup required ❌

### Sync Flag Behavior

**--fix Flag Purpose:**
- ONLY for existing GitHub issues with file naming inconsistencies
- Example: File `15.md` but GitHub issue is actually #17
- NOT for issues that don't exist on GitHub yet

**When NOT to Use --fix:**
- New tasks with empty `github:` field
- Tasks marked `# TO BE CREATED`
- First-time epic sync operations

### Best Practices

**✅ DO:**
- Leave `github:` field empty for new tasks
- Use `# TO BE CREATED` comment for clarity
- Let `/pm:sync` manage GitHub URL assignment
- Use consistent file naming from start

**❌ DON'T:**
- Pre-fill GitHub URLs for non-existent issues
- Assume GitHub will assign expected issue numbers
- Mix anticipated and actual GitHub references

### Mandatory Verification Algorithm

**MUST be executed after every GitHub issue creation:**

```bash
# SYSTEMATIC check - NEVER skip this verification
github_number=$(grep "^github:" task.md | grep -o '[0-9]*$')
local_number=$(basename task.md .md)

if [[ "$local_number" != "$github_number" ]]; then
    echo "🚨 CRITICAL: File-GitHub number mismatch!"
    echo "   Local file: $local_number.md"
    echo "   GitHub issue: #$github_number"
    
    # IMMEDIATE correction required
    mv "$local_number.md" "$github_number.md"
    
    # Update epic task lists
    find .claude/epics/ -name "epic.md" -exec sed -i "s/#$local_number /#$github_number /g" {} \;
    
    # Update dependency references
    find .claude/epics/ -name "*.md" -exec sed -i "s/depends_on: \[\([^]]*\)$local_number\([^]]*\)\]/depends_on: [\1$github_number\2]/g" {} \;
    
    echo "✅ File renamed and all references updated"
fi
```

**This verification MUST happen:**
- Immediately after `gh issue create`
- During every `/pm:sync` operation  
- Before any epic task list updates
- As part of automated workflows

This prevents sync confusion and ensures --fix flag works correctly for genuine file naming issues.