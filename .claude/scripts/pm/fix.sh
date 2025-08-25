#!/bin/bash

# PM Fix Script
# Diagnose and fix common PM system issues

set -e

# Color codes
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Global variables
declare -A inconsistent_files
declare -a missing_github_files
declare -A broken_deps
declare -A epic_errors

# Usage function
usage() {
    echo "Usage: $0 [--auto] [--check-only] [--issue] [epic_name]"
    echo ""
    echo "Options:"
    echo "  --auto        Apply all fixes automatically without confirmation"
    echo "  --check-only  Only diagnose issues, don't apply fixes"
    echo "  --issue       Only fix file-GitHub number consistency (fastest, safest)"
    echo "  epic_name     Fix issues only in specified epic (default: all epics)"
    echo ""
    echo "Examples:"
    echo "  $0                    # Interactive mode for all epics"
    echo "  $0 --issue           # Fix only file naming issues automatically"
    echo "  $0 --check-only      # Diagnose all issues without fixes"
    echo "  $0 cross-testing     # Fix all issues in cross-testing epic"
}

# Debug/logging function
debug_log() {
    if [[ "${REPOCLI_DEBUG:-0}" == "1" ]]; then
        echo -e "${BLUE}[DEBUG]${NC} $*" >&2
    fi
}

# Check file-GitHub number consistency
check_file_github_consistency() {
    local issues_found=0
    echo -e "${BLUE}🔍 Checking file-GitHub number consistency...${NC}"
    
    local search_pattern=".claude/epics/"
    if [[ -n "$1" ]]; then
        search_pattern=".claude/epics/$1/"
    fi
    search_pattern+="[0-9]*.md"
    
    for file in $search_pattern; do
        [[ ! -f "$file" ]] && continue
        
        local local_number=$(basename "$file" .md)
        local github_url=$(grep "^github:" "$file" 2>/dev/null | head -1 | cut -d' ' -f2-)
        local github_number=$(echo "$github_url" | grep -o '[0-9]*$')
        
        debug_log "Checking $file: local=$local_number, github=$github_number"
        
        if [[ -n "$github_number" && "$local_number" != "$github_number" ]]; then
            echo -e "  ${RED}❌ INCONSISTENCY:${NC} $file (local: #$local_number, GitHub: #$github_number)"
            echo "     GitHub URL: $github_url"
            inconsistent_files["$file"]="$github_number"
            ((issues_found++))
        fi
    done
    
    if [[ $issues_found -eq 0 ]]; then
        echo -e "  ${GREEN}✅ All files match their GitHub issue numbers${NC}"
    fi
    
    return $issues_found
}

# Check missing GitHub URLs
check_missing_github_urls() {
    local issues_found=0
    echo -e "${BLUE}🔍 Checking for missing GitHub URLs...${NC}"
    
    local search_pattern=".claude/epics/"
    if [[ -n "$1" ]]; then
        search_pattern=".claude/epics/$1/"
    fi
    search_pattern+="[0-9]*.md"
    
    for file in $search_pattern; do
        [[ ! -f "$file" ]] && continue
        
        if ! grep -q "^github:" "$file"; then
            echo -e "  ${RED}❌ MISSING GITHUB URL:${NC} $file"
            missing_github_files+=("$file")
            ((issues_found++))
        elif grep -q "^github: *$" "$file"; then
            echo -e "  ${RED}❌ EMPTY GITHUB URL:${NC} $file"
            missing_github_files+=("$file")
            ((issues_found++))
        fi
    done
    
    if [[ $issues_found -eq 0 ]]; then
        echo -e "  ${GREEN}✅ All files have GitHub URLs${NC}"
    fi
    
    return $issues_found
}

# Fix file-GitHub number consistency
fix_file_github_consistency() {
    echo -e "${BLUE}🔧 Fixing file-GitHub number consistency...${NC}"
    
    # CRITICAL: Sort files by number in DESCENDING order to avoid conflicts
    # If we rename 15.md→17.md before 16.md→18.md, we might overwrite existing files
    local sorted_files=()
    for file in "${!inconsistent_files[@]}"; do
        local local_number=$(basename "$file" .md)
        sorted_files+=("$local_number:$file")
    done
    
    # Sort by number (highest first) to prevent conflicts
    IFS=$'\n' sorted_files=($(printf '%s\n' "${sorted_files[@]}" | sort -rn -t: -k1))
    
    for entry in "${sorted_files[@]}"; do
        local file="${entry#*:}"
        local github_number="${inconsistent_files[$file]}"
        local local_number=$(basename "$file" .md)
        local target_file="$(dirname "$file")/$github_number.md"
        
        echo -e "  ${YELLOW}📝 Renaming:${NC} $(basename "$file") → $github_number.md (descending order)"
        mv "$file" "$target_file"
        
        # Update epic task lists
        local epic_file="$(dirname "$file")/epic.md"
        if [[ -f "$epic_file" ]]; then
            echo -e "    ${YELLOW}📋 Updating epic task list:${NC} #$local_number → #$github_number"
            sed -i "s/#$local_number /#$github_number /g" "$epic_file"
            sed -i "s/(#$local_number)/(#$github_number)/g" "$epic_file"
        fi
        
        # Update dependencies in all files
        echo -e "    ${YELLOW}🔗 Updating dependencies:${NC} $local_number → $github_number"
        find .claude/epics/ -name "*.md" -exec sed -i "s/depends_on: \[\([^]]*\)$local_number\([^]]*\)\]/depends_on: [\1$github_number\2]/g" {} \;
        find .claude/epics/ -name "*.md" -exec sed -i "s/, *$local_number\([^]]*\)\]/, $github_number\1]/g" {} \;
        find .claude/epics/ -name "*.md" -exec sed -i "s/\[ *$local_number\([^]]*\)\]/[$github_number\1]/g" {} \;
        
        echo -e "    ${GREEN}✅ Fixed:${NC} $file → $target_file"
    done
    
    echo -e "${GREEN}✅ File-GitHub consistency fixed${NC}"
}

# Issue-only fix mode (fast and safe)
run_issue_only_fix() {
    local epic_name="$1"
    
    echo -e "${BLUE}🔧 PM Fix - Issue Number Consistency Only${NC}"
    echo "============================================"
    
    # Reset global arrays
    inconsistent_files=()
    local issues_found=0
    
    check_file_github_consistency "$epic_name"
    issues_found=$?
    
    if [[ $issues_found -eq 0 ]]; then
        echo ""
        echo -e "${GREEN}🎉 No file naming issues found!${NC}"
        return 0
    fi
    
    echo ""
    echo -e "${YELLOW}📋 SUMMARY: Found $issues_found file naming inconsistencies${NC}"
    echo "============================================"
    
    # Apply fixes automatically for --issue mode
    fix_file_github_consistency
    
    echo ""
    echo -e "${GREEN}🎉 Issue Fix Complete - $issues_found file naming issues resolved${NC}"
    echo -e "${BLUE}💡 All task files now match their GitHub issue numbers${NC}"
}

# Check-only mode
run_check_only() {
    local epic_name="$1"
    
    echo -e "${BLUE}🔍 PM Fix - Check Only Mode${NC}"
    echo "============================================"
    
    local total_issues=0
    
    check_file_github_consistency "$epic_name"
    total_issues=$(($total_issues + $?))
    
    check_missing_github_urls "$epic_name"
    total_issues=$(($total_issues + $?))
    
    echo ""
    if [[ $total_issues -eq 0 ]]; then
        echo -e "${GREEN}🎉 No issues found! PM system is healthy.${NC}"
    else
        echo -e "${YELLOW}📋 SUMMARY: Found $total_issues issues${NC}"
        echo "============================================"
        echo ""
        echo -e "${BLUE}💡 Run without --check-only to apply fixes${NC}"
    fi
    
    return $total_issues
}

# Interactive mode
run_interactive_fixes() {
    local epic_name="$1"
    
    echo -e "${BLUE}🔧 PM Fix - Interactive Mode${NC}"
    echo "============================================"
    
    local total_issues=0
    
    check_file_github_consistency "$epic_name"
    total_issues=$(($total_issues + $?))
    
    check_missing_github_urls "$epic_name"
    total_issues=$(($total_issues + $?))
    
    if [[ $total_issues -eq 0 ]]; then
        echo ""
        echo -e "${GREEN}🎉 No issues found! PM system is healthy.${NC}"
        return 0
    fi
    
    echo ""
    echo -e "${YELLOW}📋 SUMMARY: Found $total_issues issues${NC}"
    echo "============================================"
    
    # Offer fixes
    if [[ ${#inconsistent_files[@]} -gt 0 ]]; then
        echo ""
        echo -e "${YELLOW}Fix file-GitHub number inconsistencies? (y/n)${NC}"
        read -r response
        if [[ "$response" =~ ^[Yy] ]]; then
            fix_file_github_consistency
        fi
    fi
    
    if [[ ${#missing_github_files[@]} -gt 0 ]]; then
        echo ""
        echo -e "${YELLOW}Create GitHub issues for files missing URLs? (y/n)${NC}"
        echo "  This would create ${#missing_github_files[@]} new GitHub issues"
        read -r response
        if [[ "$response" =~ ^[Yy] ]]; then
            echo -e "${RED}❌ GitHub issue creation not implemented yet${NC}"
            echo "   Please create GitHub issues manually for these files:"
            for file in "${missing_github_files[@]}"; do
                echo "     - $file"
            done
        fi
    fi
    
    echo ""
    echo -e "${GREEN}🎉 PM Fix Complete${NC}"
}

# Main function
main() {
    local auto_mode=false
    local check_only=false
    local issue_only=false
    local epic_name=""
    
    # Parse arguments
    while [[ $# -gt 0 ]]; do
        case $1 in
            --auto)
                auto_mode=true
                shift
                ;;
            --check-only)
                check_only=true
                shift
                ;;
            --issue)
                issue_only=true
                shift
                ;;
            --help|-h)
                usage
                exit 0
                ;;
            -*)
                echo "Unknown option: $1" >&2
                usage >&2
                exit 1
                ;;
            *)
                epic_name="$1"
                shift
                ;;
        esac
    done
    
    # Change to repository root if needed
    if [[ ! -d ".claude" ]]; then
        echo -e "${RED}❌ Not in a repository with .claude directory${NC}" >&2
        exit 1
    fi
    
    # Validate epic name if provided
    if [[ -n "$epic_name" && ! -d ".claude/epics/$epic_name" ]]; then
        echo -e "${RED}❌ Epic '$epic_name' not found${NC}" >&2
        exit 1
    fi
    
    # Run appropriate mode
    if [[ "$issue_only" == true ]]; then
        run_issue_only_fix "$epic_name"
    elif [[ "$check_only" == true ]]; then
        run_check_only "$epic_name"
    elif [[ "$auto_mode" == true ]]; then
        echo -e "${RED}❌ Auto mode not fully implemented yet${NC}" >&2
        echo "   Use --issue for safe automatic fixes or interactive mode"
        exit 1
    else
        run_interactive_fixes "$epic_name"
    fi
}

# Run main function if script is executed directly
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main "$@"
fi