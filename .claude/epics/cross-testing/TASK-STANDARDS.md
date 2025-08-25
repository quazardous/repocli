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
github: https://github.com/owner/repo/issues/N
depends_on: [2, 5]  # GitHub issue numbers
parallel: true|false
conflicts_with: []  # GitHub issue numbers that conflict
---
```

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

### GitHub Issue Status Priority

**PRIMARY**: Status is managed via GitHub issue status field, not labels.

**FUTURE FEATURE**: GitHub label integration for enhanced workflow automation.
- Planned: Automated label sync with status changes
- Planned: Additional context labels (priority, type, area)
- Planned: Workflow automation via GitHub Actions

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
- **FUTURE**: Automated label management and workflow triggers

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