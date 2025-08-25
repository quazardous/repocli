---
allowed-tools: Bash, Read, Write, LS, Glob, Grep
---

# Fix

Diagnose and fix common PM system issues automatically or with user confirmation.

## Usage
```
/pm:fix [--auto] [--check-only] [--issue] [epic_name]
```

**Options:**
- `--auto`: Apply all fixes automatically without confirmation
- `--check-only`: Only diagnose issues, don't apply fixes
- `--issue`: Only fix file-GitHub number consistency (fastest, safest)
- `epic_name`: Fix issues only in specified epic (default: all epics)

## Diagnostic Categories

### 1. File-GitHub Number Consistency
**Issue**: Local task file names don't match GitHub issue numbers
**Examples**: 
- File `15.md` has `github: .../issues/17` 
- Epic lists `#15` but GitHub issue is `#17`

### 2. Missing GitHub URLs
**Issue**: Task files missing `github:` field in frontmatter
**Impact**: Tasks can't be synced with GitHub

### 3. Broken Dependencies  
**Issue**: Tasks depend on non-existent issue numbers
**Examples**:
- `depends_on: [15]` but no task #15 exists
- `depends_on: [15]` but should be `[17]` after renaming

### 4. Epic Task List Inconsistencies
**Issue**: Epic task lists reference wrong issue numbers
**Examples**:
- Epic lists `#15` but file is `17.md`
- Epic shows task as completed but GitHub issue is open

### 5. Stale Sync Timestamps
**Issue**: Files with outdated or missing `last_sync` timestamps
**Impact**: Sync operations may behave incorrectly

## Implementation

### Core Diagnostic Functions

```bash
# Check file-GitHub number consistency
check_file_github_consistency() {
    local issues_found=0
    echo "🔍 Checking file-GitHub number consistency..."
    
    for file in .claude/epics/*/[0-9]*.md; do
        [[ ! -f "$file" ]] && continue
        
        local local_number=$(basename "$file" .md)
        local github_url=$(grep "^github:" "$file" | head -1 | cut -d' ' -f2-)
        local github_number=$(echo "$github_url" | grep -o '[0-9]*$')
        
        if [[ -n "$github_number" && "$local_number" != "$github_number" ]]; then
            echo "❌ INCONSISTENCY: $file (local: #$local_number, GitHub: #$github_number)"
            echo "   GitHub URL: $github_url"
            inconsistent_files["$file"]="$github_number"
            ((issues_found++))
        fi
    done
    
    if [[ $issues_found -eq 0 ]]; then
        echo "✅ All files match their GitHub issue numbers"
    fi
    
    return $issues_found
}

# Check missing GitHub URLs
check_missing_github_urls() {
    local issues_found=0
    echo "🔍 Checking for missing GitHub URLs..."
    
    for file in .claude/epics/*/[0-9]*.md; do
        [[ ! -f "$file" ]] && continue
        
        if ! grep -q "^github:" "$file"; then
            echo "❌ MISSING GITHUB URL: $file"
            missing_github_files+=("$file")
            ((issues_found++))
        elif grep -q "^github: *$" "$file"; then
            echo "❌ EMPTY GITHUB URL: $file"
            missing_github_files+=("$file")
            ((issues_found++))
        fi
    done
    
    if [[ $issues_found -eq 0 ]]; then
        echo "✅ All files have GitHub URLs"
    fi
    
    return $issues_found
}

# Check broken dependencies
check_broken_dependencies() {
    local issues_found=0
    echo "🔍 Checking for broken dependencies..."
    
    # Get all existing task numbers
    local existing_numbers=()
    for file in .claude/epics/*/[0-9]*.md; do
        [[ ! -f "$file" ]] && continue
        local github_number=$(grep "^github:" "$file" | grep -o '[0-9]*$')
        [[ -n "$github_number" ]] && existing_numbers+=("$github_number")
    done
    
    for file in .claude/epics/*/[0-9]*.md; do
        [[ ! -f "$file" ]] && continue
        
        local deps=$(grep "^depends_on:" "$file" | sed 's/depends_on: \[\(.*\)\]/\1/' | tr ',' ' ')
        for dep in $deps; do
            dep=$(echo "$dep" | tr -d '[]" ')
            [[ -z "$dep" ]] && continue
            
            if [[ ! " ${existing_numbers[@]} " =~ " $dep " ]]; then
                echo "❌ BROKEN DEPENDENCY: $file depends on non-existent #$dep"
                broken_deps["$file"]+="$dep "
                ((issues_found++))
            fi
        done
    done
    
    if [[ $issues_found -eq 0 ]]; then
        echo "✅ All dependencies are valid"
    fi
    
    return $issues_found
}

# Check epic task list consistency
check_epic_task_lists() {
    local issues_found=0
    echo "🔍 Checking epic task list consistency..."
    
    for epic_file in .claude/epics/*/epic.md; do
        [[ ! -f "$epic_file" ]] && continue
        local epic_dir=$(dirname "$epic_file")
        
        # Extract task numbers from epic
        local epic_tasks=$(grep -E "^\s*- \[.\] #[0-9]+" "$epic_file" | grep -o '#[0-9]\+' | sed 's/#//')
        
        for task_num in $epic_tasks; do
            local task_file="$epic_dir/$task_num.md"
            if [[ ! -f "$task_file" ]]; then
                echo "❌ EPIC REFERENCE ERROR: $epic_file lists #$task_num but $task_file doesn't exist"
                epic_errors["$epic_file"]+="#$task_num "
                ((issues_found++))
            else
                # Check if file's GitHub number matches epic reference
                local github_number=$(grep "^github:" "$task_file" | grep -o '[0-9]*$')
                if [[ -n "$github_number" && "$task_num" != "$github_number" ]]; then
                    echo "❌ EPIC-FILE MISMATCH: $epic_file lists #$task_num but $task_file has GitHub #$github_number"
                    epic_errors["$epic_file"]+="#$task_num->$github_number "
                    ((issues_found++))
                fi
            fi
        done
    done
    
    if [[ $issues_found -eq 0 ]]; then
        echo "✅ All epic task lists are consistent"
    fi
    
    return $issues_found
}
```

### Fix Functions

```bash
# Fix file-GitHub number consistency
fix_file_github_consistency() {
    echo "🔧 Fixing file-GitHub number consistency..."
    
    # CRITICAL: Sort files by number in DESCENDING order to avoid conflicts
    # If we rename 15.md→17.md before 16.md→18.md, we might overwrite existing files
    local sorted_files=()
    for file in "${!inconsistent_files[@]}"; do
        local local_number=$(basename "$file" .md)
        sorted_files+=("$local_number:$file")
    done
    
    # Sort by number (highest first) to prevent conflicts
    IFS=$'\n' sorted_files=($(sort -rn -t: -k1 <<<"${sorted_files[*]}"))
    
    for entry in "${sorted_files[@]}"; do
        local file="${entry#*:}"
        local github_number="${inconsistent_files[$file]}"
        local local_number=$(basename "$file" .md)
        local target_file="$(dirname "$file")/$github_number.md"
        
        echo "  Renaming $file → $target_file (descending order to avoid conflicts)"
        mv "$file" "$target_file"
        
        # Update epic task lists
        local epic_file="$(dirname "$file")/epic.md"
        if [[ -f "$epic_file" ]]; then
            echo "  Updating epic task list: #$local_number → #$github_number"
            sed -i "s/#$local_number /#$github_number /g" "$epic_file"
        fi
        
        # Update dependencies in all files
        echo "  Updating dependencies across all files: $local_number → $github_number"
        find .claude/epics/ -name "*.md" -exec sed -i "s/depends_on: \[\([^]]*\)$local_number\([^]]*\)\]/depends_on: [\1$github_number\2]/g" {} \;
        find .claude/epics/ -name "*.md" -exec sed -i "s/depends_on: \[\([^]]*\), *$local_number\([^]]*\)\]/depends_on: [\1, $github_number\2]/g" {} \;
    done
    
    echo "✅ File-GitHub consistency fixed"
}

# Create missing GitHub issues
fix_missing_github_urls() {
    echo "🔧 Creating GitHub issues for files without URLs..."
    
    for file in "${missing_github_files[@]}"; do
        local title=$(grep "^name:" "$file" | cut -d':' -f2- | xargs)
        if [[ -z "$title" ]]; then
            echo "❌ Cannot create GitHub issue for $file: no title found"
            continue
        fi
        
        echo "  Creating GitHub issue for: $title"
        local github_url=$(gh issue create --title "$title" --body-file "$file" --label enhancement 2>/dev/null)
        
        if [[ $? -eq 0 ]]; then
            echo "  Created: $github_url"
            # Update frontmatter
            if grep -q "^github:" "$file"; then
                sed -i "s|^github:.*|github: $github_url|" "$file"
            else
                # Insert after 'updated:' line
                sed -i "/^updated:/a github: $github_url" "$file"
            fi
        else
            echo "❌ Failed to create GitHub issue for $file"
        fi
    done
    
    echo "✅ Missing GitHub URLs fixed"
}
```

### Issue-Only Fix Mode

```bash
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
            echo "   GitHub URL: $github_url"
            inconsistent_files["$file"]="$github_number"
            ((issues_found++))
        fi
    done
    
    if [[ $issues_found -eq 0 ]]; then
        echo "✅ All files match their GitHub issue numbers"
        echo "🎉 No file naming issues found!"
        return 0
    fi
    
    echo ""
    echo "📋 SUMMARY: Found $issues_found file naming inconsistencies"
    echo "============================================"
    
    # Apply fixes automatically for --issue mode
    echo "🔧 Fixing file-GitHub number consistency..."
    
    # CRITICAL: Sort files by number in DESCENDING order to avoid conflicts
    # If we rename 15.md→17.md before 16.md→18.md, we might overwrite existing files
    local sorted_files=()
    for file in "${!inconsistent_files[@]}"; do
        local local_number=$(basename "$file" .md)
        sorted_files+=("$local_number:$file")
    done
    
    # Sort by number (highest first) to prevent conflicts
    IFS=$'\n' sorted_files=($(sort -rn -t: -k1 <<<"${sorted_files[*]}"))
    
    for entry in "${sorted_files[@]}"; do
        local file="${entry#*:}"
        local github_number="${inconsistent_files[$file]}"
        local local_number=$(basename "$file" .md)
        local target_file="$(dirname "$file")/$github_number.md"
        
        echo "  📝 Renaming: $(basename "$file") → $github_number.md (descending order)"
        mv "$file" "$target_file"
        
        # Update epic task lists
        local epic_file="$(dirname "$file")/epic.md"
        if [[ -f "$epic_file" ]]; then
            echo "    📋 Updating epic task list: #$local_number → #$github_number"
            sed -i "s/#$local_number /#$github_number /g" "$epic_file"
        fi
        
        # Update dependencies in all files
        echo "    🔗 Updating dependencies: $local_number → $github_number"
        find .claude/epics/ -name "*.md" -exec sed -i "s/depends_on: \[\([^]]*\)$local_number\([^]]*\)\]/depends_on: [\1$github_number\2]/g" {} \;
        find .claude/epics/ -name "*.md" -exec sed -i "s/, *$local_number\([^]]*\)\]/, $github_number\1]/g" {} \;
        find .claude/epics/ -name "*.md" -exec sed -i "s/\[ *$local_number\([^]]*\)\]/[$github_number\1]/g" {} \;
        
        echo "    ✅ Fixed: $file → $target_file"
    done
    
    echo ""
    echo "🎉 Issue Fix Complete - $issues_found file naming issues resolved"
    echo "💡 All task files now match their GitHub issue numbers"
}

### Interactive Mode

```bash
run_interactive_fixes() {
    echo "🔧 PM Fix - Interactive Mode"
    echo "============================================"
    
    # Run diagnostics
    declare -A inconsistent_files
    declare -a missing_github_files
    declare -A broken_deps  
    declare -A epic_errors
    
    local total_issues=0
    
    check_file_github_consistency && ((total_issues += $?))
    check_missing_github_urls && ((total_issues += $?))
    check_broken_dependencies && ((total_issues += $?))
    check_epic_task_lists && ((total_issues += $?))
    
    if [[ $total_issues -eq 0 ]]; then
        echo "🎉 No issues found! PM system is healthy."
        return 0
    fi
    
    echo ""
    echo "📋 SUMMARY: Found $total_issues issues"
    echo "============================================"
    
    # Offer fixes
    if [[ ${#inconsistent_files[@]} -gt 0 ]]; then
        echo ""
        echo "Fix file-GitHub number inconsistencies? (y/n)"
        read -r response
        [[ "$response" =~ ^[Yy] ]] && fix_file_github_consistency
    fi
    
    if [[ ${#missing_github_files[@]} -gt 0 ]]; then
        echo ""
        echo "Create GitHub issues for files missing URLs? (y/n)"
        echo "  This will create ${#missing_github_files[@]} new GitHub issues"
        read -r response  
        [[ "$response" =~ ^[Yy] ]] && fix_missing_github_urls
    fi
    
    if [[ ${#broken_deps[@]} -gt 0 ]]; then
        echo ""
        echo "Broken dependencies found. Manual review required:"
        for file in "${!broken_deps[@]}"; do
            echo "  $file: broken deps ${broken_deps[$file]}"
        done
        echo "Run '/pm:sync' after fixing file naming to auto-correct dependencies."
    fi
    
    if [[ ${#epic_errors[@]} -gt 0 ]]; then
        echo ""
        echo "Epic task list errors found. Run file consistency fixes first, then:"
        echo "  /pm:sync to synchronize epic task lists"
    fi
}
```

## Usage Examples

### Interactive Mode (Recommended)
```bash
/pm:fix
# Shows all issues and asks for confirmation before fixes
```

### Issue-Only Mode (Fast & Safe)
```bash
/pm:fix --issue
# Only fixes file-GitHub number consistency, applies automatically
```

### Auto-Fix Mode  
```bash
/pm:fix --auto
# Applies all safe fixes automatically
```

### Check Only Mode
```bash  
/pm:fix --check-only
# Diagnoses issues without applying fixes
```

### Epic-Specific Fix
```bash
/pm:fix cross-testing          # All fixes for specific epic
/pm:fix --issue cross-testing  # Only file naming for specific epic
```

## Sample Output

### Issue-Only Mode (`--issue`)
```
🔧 PM Fix - Issue Number Consistency Only
============================================

🔍 Checking file-GitHub number consistency...
❌ INCONSISTENCY: .claude/epics/cross-testing/15.md (local: #15, GitHub: #17)
   GitHub URL: https://github.com/quazardous/repocli/issues/17
❌ INCONSISTENCY: .claude/epics/cross-testing/16.md (local: #16, GitHub: #18)  
   GitHub URL: https://github.com/quazardous/repocli/issues/18

📋 SUMMARY: Found 2 file naming inconsistencies
============================================

🔧 Fixing file-GitHub number consistency...
  📝 Renaming: 15.md → 17.md
    📋 Updating epic task list: #15 → #17
    🔗 Updating dependencies: 15 → 17
    ✅ Fixed: .claude/epics/cross-testing/15.md → 17.md
  📝 Renaming: 16.md → 18.md
    📋 Updating epic task list: #16 → #18
    🔗 Updating dependencies: 16 → 18
    ✅ Fixed: .claude/epics/cross-testing/16.md → 18.md

🎉 Issue Fix Complete - 2 file naming issues resolved
💡 All task files now match their GitHub issue numbers
```

### Interactive Mode (Full)
```
🔧 PM Fix - Interactive Mode
============================================

🔍 Checking file-GitHub number consistency...
❌ INCONSISTENCY: .claude/epics/cross-testing/15.md (local: #15, GitHub: #17)

🔍 Checking for missing GitHub URLs...
❌ MISSING GITHUB URL: .claude/epics/cross-testing/20d.md

🔍 Checking for broken dependencies...
❌ BROKEN DEPENDENCY: .claude/epics/cross-testing/14.md depends on non-existent #15

📋 SUMMARY: Found 5 issues
============================================

Fix file-GitHub number inconsistencies? (y/n) y
🔧 Fixing file-GitHub number consistency...
✅ File-GitHub consistency fixed

Create GitHub issues for files missing URLs? (y/n) y  
🔧 Creating GitHub issues for files without URLs...
✅ Missing GitHub URLs fixed

🎉 PM Fix Complete - 5 issues resolved
```

## Why Use --issue Mode?

### 🚀 **Speed & Safety**
- **Fastest**: Only checks/fixes one thing (file naming)
- **Safest**: No GitHub API calls, no new issue creation
- **Automatic**: No prompts, applies fixes immediately
- **Focused**: Solves the most common PM issue

### 🎯 **Perfect For**
- **After `/pm:epic-sync`** - Fixes sequential file numbering
- **Quick maintenance** - Fast cleanup before important operations  
- **CI/CD pipelines** - Automated file consistency checking
- **Daily workflow** - Ensure files match GitHub issue numbers

### 💡 **When NOT to Use**
- If you need to create missing GitHub issues (use full `/pm:fix`)
- If you want to see all issues first (use `/pm:fix --check-only`)

## Safety Features

- **Non-destructive**: Only renames files and updates references
- **Atomic operations**: Each file fix is complete or not done
- **Validation**: Verifies GitHub URLs exist before processing
- **Clear logging**: Shows exactly what was changed
- **Reversible**: Changes can be undone with `/pm:sync`

## Integration  

- **Works with `/pm:sync`**: Use before sync for clean state
- **Complements `/pm:sync --fix`**: Same logic but standalone
- **Compatible with all PM commands**: Follows same rules
- **CI/CD friendly**: `--issue` mode perfect for automation

## Command Comparison

| Command | Speed | Safety | Scope | Automation |
|---------|-------|--------|--------|------------|
| `/pm:fix` | Slow | Interactive | All issues | Manual |
| `/pm:fix --auto` | Medium | Automatic | All issues | Full |
| `/pm:fix --issue` | **Fast** | **Automatic** | **File naming only** | **Perfect** |
| `/pm:fix --check-only` | Fast | Read-only | All issues | Diagnostic |