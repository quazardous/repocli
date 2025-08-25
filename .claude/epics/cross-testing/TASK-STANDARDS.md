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

- `open` - Not started
- `in_progress` - Work begun but not complete
- `completed` - All acceptance criteria met
- ~~`closed`~~ - Deprecated, use `completed`

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