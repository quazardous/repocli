---
allowed-tools: Bash, Read, Write, LS
---

# Sync

Full bidirectional sync between local and GitHub.

## Usage
```
/pm:sync [--fix] [epic_name]
```

**Options:**
- `--fix`: Run `/pm:fix --issue` before sync to ensure file-GitHub consistency (fast & safe)
- `epic_name`: Sync only that epic. Otherwise sync all.

If epic_name provided, sync only that epic. Otherwise sync all.

## Instructions

### 0. Pre-Sync Fix (if --fix flag used)

If `--fix` flag is provided, run `/pm:fix --issue` to ensure file-GitHub consistency before starting sync:

```bash
# Run focused issue fix before sync
echo "🔧 Running pre-sync fixes..."
echo "Executing: /pm:fix --issue"
echo ""

# Call the optimized issue-only fix function
run_issue_only_fix() {
    echo "🔧 PM Fix - Issue Number Consistency Only"
    echo "============================================"
    
    # Run only file-GitHub consistency check
    declare -A inconsistent_files
    local issues_found=0
    
    echo "🔍 Checking file-GitHub number consistency..."
    
    for file in .claude/epics/*/[0-9]*.md; do
        [[ ! -f "$file" ]] && continue
        
        local local_number=$(basename "$file" .md)
        local github_url=$(grep "^github:" "$file" | head -1 | cut -d' ' -f2-)
        local github_number=$(echo "$github_url" | grep -o '[0-9]*$')
        
        if [[ -n "$github_number" && "$local_number" != "$github_number" ]]; then
            echo "❌ INCONSISTENCY: $file (local: #$local_number, GitHub: #$github_number)"
            inconsistent_files["$file"]="$github_number"
            ((issues_found++))
        fi
    done
    
    if [[ $issues_found -eq 0 ]]; then
        echo "✅ All files match their GitHub issue numbers"
        echo ""
        return 0
    fi
    
    echo ""
    echo "📋 SUMMARY: Found $issues_found file naming inconsistencies"
    echo "🔧 Fixing file-GitHub number consistency..."
    
    for file in "${!inconsistent_files[@]}"; do
        local github_number="${inconsistent_files[$file]}"
        local local_number=$(basename "$file" .md)
        local target_file="$(dirname "$file")/$github_number.md"
        
        echo "  📝 Renaming: $(basename "$file") → $github_number.md"
        mv "$file" "$target_file"
        
        # Update epic task lists
        local epic_file="$(dirname "$file")/epic.md"
        if [[ -f "$epic_file" ]]; then
            sed -i "s/#$local_number /#$github_number /g" "$epic_file"
        fi
        
        # Update dependencies in all files
        find .claude/epics/ -name "*.md" -exec sed -i "s/depends_on: \[\([^]]*\)$local_number\([^]]*\)\]/depends_on: [\1$github_number\2]/g" {} \;
        find .claude/epics/ -name "*.md" -exec sed -i "s/, *$local_number\([^]]*\)\]/, $github_number\1]/g" {} \;
        find .claude/epics/ -name "*.md" -exec sed -i "s/\[ *$local_number\([^]]*\)\]/[$github_number\1]/g" {} \;
    done
    
    echo "✅ Pre-sync issue fix complete - $issues_found file naming issues resolved"
    echo ""
}

# Execute the fix
run_issue_only_fix

echo "🔄 Proceeding with sync..."
echo ""
```

### 1. Pull from GitHub

Get current state of all issues:
```bash
# Get all epic and task issues
gh issue list --label "epic" --limit 1000 --json number,title,state,body,labels,updatedAt
gh issue list --label "task" --limit 1000 --json number,title,state,body,labels,updatedAt
```

### 2. Update Local from GitHub

For each GitHub issue:
- Find corresponding local file by issue number
- Compare states:
  - If GitHub state newer (updatedAt > local updated), update local
  - If GitHub closed but local open, close local
  - If GitHub reopened but local closed, reopen local
- Update frontmatter to match GitHub state

### 3. Push Local to GitHub

For each local task/epic:
- If has GitHub URL but GitHub issue not found, it was deleted - mark local as archived
- If no GitHub URL, create new issue (like epic-sync)
- **CRITICAL**: When creating new GitHub issue, if GitHub assigns different number than expected:
  1. **IMMEDIATELY** rename local file to match GitHub issue number
  2. **IMMEDIATELY** update frontmatter `github:` field
  3. **IMMEDIATELY** update epic task list references
  4. **IMMEDIATELY** update dependency references in other files
- If local updated > GitHub updatedAt, push changes:
  ```bash
  gh issue edit {number} --body-file {local_file}
  ```

### 4. Enforce File-GitHub Number Consistency

**MANDATORY**: Before completing sync, verify ALL files match their GitHub issue numbers:

```bash
# Check consistency algorithm
for file in .claude/epics/*/[0-9]*.md; do
  local_number=$(basename "$file" .md)
  github_url=$(grep "^github:" "$file" | cut -d'/' -f7)
  
  if [[ "$local_number" != "$github_url" ]]; then
    echo "🚨 INCONSISTENCY: $file (local: #$local_number, GitHub: #$github_url)"
    
    # IMMEDIATE CORRECTION REQUIRED
    mv "$file" "$(dirname "$file")/$github_url.md"
    
    # Update epic task list references
    epic_file=$(dirname "$file")/epic.md
    sed -i "s/#$local_number /#$github_url /g" "$epic_file"
    
    # Update dependency references in ALL files
    find .claude/epics/ -name "*.md" -exec sed -i "s/depends_on: \[.*$local_number.*\]/depends_on: [$(echo {} | sed "s/$local_number/$github_url/g")]/g" {} \;
    
    echo "✅ CORRECTED: Renamed to $github_url.md and updated all references"
  fi
done
```

### 5. Handle Conflicts

If both changed (local and GitHub updated since last sync):
- Show both versions
- Ask user: "Local and GitHub both changed. Keep: (local/github/merge)?"
- Apply user's choice

### 6. Update Sync Timestamps

Update all synced files with last_sync timestamp.

### 7. Output

```
🔄 Sync Complete

Pre-Sync Fixes (if --fix used):
  File naming consistency: {count} files renamed to match GitHub issues
  Epic task lists updated: {count} reference updates
  Dependencies updated: {count} dependency reference fixes

Pulled from GitHub:
  Updated: {count} files
  Closed: {count} issues
  
Pushed to GitHub:
  Updated: {count} issues
  Created: {count} new issues
  
File-GitHub Number Consistency:
  Checked: {count} task files
  Renamed: {count} files to match GitHub numbers
  Updated references: {count} dependency updates
  
Conflicts resolved: {count}

Status:
  ✅ All files synced
  ✅ File-GitHub number consistency enforced
  {or list any sync failures}
```

## Important Notes

### Critical Requirements
- **FILE-GITHUB CONSISTENCY IS MANDATORY**: File names MUST match GitHub issue numbers exactly
- **IMMEDIATE CORRECTION**: Any inconsistencies detected MUST be fixed immediately during sync
- **CASCADE UPDATES**: When renaming files, ALL references (epic lists, dependencies) MUST be updated

### Safety Measures  
- Follow `/rules/github-operations.md` for GitHub commands
- Follow `/rules/frontmatter-operations.md` for local updates
- Always backup before sync in case of issues
- Verify consistency check runs successfully before completing sync

### Usage Examples

**Standard Sync:**
```bash
/pm:sync                    # Sync all epics
/pm:sync cross-testing      # Sync specific epic
```

**Auto-Fix Sync (Recommended):**
```bash
/pm:sync --fix              # Run /pm:fix --issue then sync all
/pm:sync --fix cross-testing # Run /pm:fix --issue then sync specific epic
```

### Examples of Critical Consistency Issues
```bash
❌ BAD: File `15.md` with `github: .../issues/17`
✅ GOOD: File `17.md` with `github: .../issues/17`

❌ BAD: Epic lists "- [ ] #15 - Task Name" but GitHub issue is #17
✅ GOOD: Epic lists "- [ ] #17 - Task Name" matching GitHub issue #17

❌ BAD: Task depends_on: [15] but dependency is actually GitHub issue #17  
✅ GOOD: Task depends_on: [17] matching actual GitHub issue numbers
```

### When to Use --fix Flag

**Always use `--fix` when:**
- You've manually created task files
- You suspect file naming inconsistencies  
- After running `/pm:epic-sync` which may create files with sequential numbers
- Before important sync operations to ensure clean state
- As part of daily workflow maintenance

**Sample --fix output:**
```
🔧 Running pre-sync fixes...
Executing: /pm:fix --issue

🔧 PM Fix - Issue Number Consistency Only
============================================

🔍 Checking file-GitHub number consistency...
❌ INCONSISTENCY: .claude/epics/cross-testing/15.md (local: #15, GitHub: #17)

📋 SUMMARY: Found 2 file naming inconsistencies
🔧 Fixing file-GitHub number consistency...
  📝 Renaming: 15.md → 17.md

✅ Pre-sync issue fix complete - 2 file naming issues resolved

🔄 Proceeding with sync...
```

This prevents the confusion we experienced where local file numbers didn't match GitHub issue numbers, making project management impossible to track correctly.