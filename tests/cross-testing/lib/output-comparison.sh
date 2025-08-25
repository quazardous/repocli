#!/bin/bash
# JSON Output Comparison Engine for REPOCLI Cross-Testing
# Provides semantic equivalence validation between GitHub and GitLab JSON outputs
# Focus on meaningful data comparison rather than exact format matching

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

# Debug logging
debug_log() {
    if [[ "${REPOCLI_DEBUG:-}" == "1" ]]; then
        echo -e "${BLUE}[DEBUG]${NC} $1" >&2
    fi
}

# Comparison result constants
readonly COMPARISON_IDENTICAL=0
readonly COMPARISON_EQUIVALENT=1
readonly COMPARISON_DIFFERENT=2
readonly COMPARISON_ERROR=3

# ==============================================================================
# JSON Normalization Functions
# ==============================================================================

# Normalize JSON structure for consistent comparison
normalize_json() {
    local input="$1"
    local output_file="${2:-}"
    
    debug_log "Normalizing JSON input"
    
    local normalized_json=""
    
    # Handle different input types
    if [[ -f "$input" ]]; then
        # Input is a file
        normalized_json=$(jq -S -c . "$input" 2>/dev/null)
    elif [[ "$input" =~ ^\{.*\}$ ]] || [[ "$input" =~ ^\[.*\]$ ]]; then
        # Input is JSON string
        normalized_json=$(echo "$input" | jq -S -c . 2>/dev/null)
    else
        echo "Error: Invalid JSON input" >&2
        return $COMPARISON_ERROR
    fi
    
    # Validate JSON was successfully parsed
    if [[ -z "$normalized_json" ]] || [[ "$normalized_json" == "null" ]]; then
        echo "Error: Failed to normalize JSON" >&2
        return $COMPARISON_ERROR
    fi
    
    # Output to file or stdout
    if [[ -n "$output_file" ]]; then
        echo "$normalized_json" > "$output_file"
    else
        echo "$normalized_json"
    fi
    
    return 0
}

# Normalize specific data types within JSON
normalize_json_types() {
    local json="$1"
    
    echo "$json" | jq '
    # Normalize timestamps to consistent format
    def normalize_timestamp:
        if type == "string" and test("^[0-9]{4}-[0-9]{2}-[0-9]{2}T[0-9]{2}:[0-9]{2}:[0-9]{2}") then
            # Convert to ISO format without milliseconds
            gsub("\\.[0-9]+Z?$"; "") + "Z"
        else
            .
        end;
    
    # Normalize boolean representations
    def normalize_boolean:
        if type == "string" and (. == "true" or . == "false") then
            . == "true"
        else
            .
        end;
    
    # Apply normalizations recursively
    walk(
        if type == "object" then
            with_entries(.value |= normalize_timestamp | normalize_boolean)
        elif type == "array" then
            map(normalize_timestamp | normalize_boolean)
        else
            normalize_timestamp | normalize_boolean
        end
    )
    ' 2>/dev/null || echo "$json"
}

# ==============================================================================
# Field Mapping Functions
# ==============================================================================

# Define field mappings between GitHub and GitLab JSON structures
declare -A GITHUB_TO_GITLAB_FIELD_MAP=(
    ["body"]="description"
    ["html_url"]="web_url"
    ["created_at"]="created_at"
    ["updated_at"]="updated_at"
    ["state"]="state"
    ["number"]="iid"
    ["title"]="title"
    ["user.login"]="author.username"
    ["assignees[].login"]="assignees[].username"
    ["labels[].name"]="labels[].name"
)

# Map GitHub JSON fields to GitLab equivalents
map_github_to_gitlab_fields() {
    local github_json="$1"
    
    debug_log "Mapping GitHub fields to GitLab format"
    
    echo "$github_json" | jq '
    # Field mappings
    if .body then .description = .body | del(.body) else . end |
    if .html_url then .web_url = .html_url | del(.html_url) else . end |
    if .number then .iid = .number | del(.number) else . end |
    if .user then 
        .author = {username: .user.login} | del(.user) 
    else . end |
    if .assignees then 
        .assignees = [.assignees[] | {username: .login}] 
    else . end
    ' 2>/dev/null || echo "$github_json"
}

# Map GitLab JSON fields to GitHub equivalents  
map_gitlab_to_github_fields() {
    local gitlab_json="$1"
    
    debug_log "Mapping GitLab fields to GitHub format"
    
    echo "$gitlab_json" | jq '
    # Field mappings
    if .description then .body = .description | del(.description) else . end |
    if .web_url then .html_url = .web_url | del(.web_url) else . end |
    if .iid then .number = .iid | del(.iid) else . end |
    if .author then 
        .user = {login: .author.username} | del(.author) 
    else . end |
    if .assignees then 
        .assignees = [.assignees[] | {login: .username}] 
    else . end
    ' 2>/dev/null || echo "$gitlab_json"
}

# ==============================================================================
# Semantic Comparison Functions
# ==============================================================================

# Compare two JSON structures for semantic equivalence
compare_json_semantic() {
    local json1="$1"
    local json2="$2"
    local comparison_type="${3:-auto}"
    
    debug_log "Performing semantic JSON comparison"
    
    # Normalize both JSON inputs
    local normalized1 normalized2
    normalized1=$(normalize_json "$json1")
    local norm1_result=$?
    normalized2=$(normalize_json "$json2")  
    local norm2_result=$?
    
    # Check normalization success
    if [[ $norm1_result -ne 0 ]] || [[ $norm2_result -ne 0 ]]; then
        echo "Error: Failed to normalize JSON for comparison"
        return $COMPARISON_ERROR
    fi
    
    # Apply type normalization
    normalized1=$(normalize_json_types "$normalized1")
    normalized2=$(normalize_json_types "$normalized2")
    
    # Exact comparison first
    if [[ "$normalized1" == "$normalized2" ]]; then
        debug_log "JSON structures are identical"
        return $COMPARISON_IDENTICAL
    fi
    
    # Apply field mapping based on comparison type
    case "$comparison_type" in
        "github-to-gitlab")
            normalized1=$(map_github_to_gitlab_fields "$normalized1")
            ;;
        "gitlab-to-github") 
            normalized2=$(map_gitlab_to_github_fields "$normalized2")
            ;;
        "auto")
            # Try both directions and see which gives better match
            local mapped1_to_2 mapped2_to_1
            mapped1_to_2=$(map_github_to_gitlab_fields "$normalized1")
            mapped2_to_1=$(map_gitlab_to_github_fields "$normalized2")
            
            if [[ "$mapped1_to_2" == "$normalized2" ]]; then
                normalized1="$mapped1_to_2"
            elif [[ "$normalized1" == "$mapped2_to_1" ]]; then
                normalized2="$mapped2_to_1"
            fi
            ;;
    esac
    
    # Re-normalize after field mapping
    normalized1=$(normalize_json_types "$normalized1")
    normalized2=$(normalize_json_types "$normalized2")
    
    # Final comparison
    if [[ "$normalized1" == "$normalized2" ]]; then
        debug_log "JSON structures are semantically equivalent"
        return $COMPARISON_EQUIVALENT
    else
        debug_log "JSON structures are different"
        return $COMPARISON_DIFFERENT
    fi
}

# Compare specific fields between JSON structures
compare_json_fields() {
    local json1="$1"
    local json2="$2" 
    local fields="$3"  # Comma-separated list of field paths
    
    debug_log "Comparing specific JSON fields: $fields"
    
    local field_array=()
    IFS=',' read -ra field_array <<< "$fields"
    
    local all_match=true
    local results=()
    
    for field in "${field_array[@]}"; do
        # Extract field values
        local value1 value2
        value1=$(echo "$json1" | jq -r ".$field // empty" 2>/dev/null)
        value2=$(echo "$json2" | jq -r ".$field // empty" 2>/dev/null)
        
        debug_log "Comparing field '$field': '$value1' vs '$value2'"
        
        if [[ "$value1" == "$value2" ]]; then
            results+=("$field:MATCH")
        else
            results+=("$field:DIFFERENT")
            all_match=false
        fi
    done
    
    # Output results
    printf '%s\n' "${results[@]}"
    
    if [[ "$all_match" == "true" ]]; then
        return $COMPARISON_IDENTICAL
    else
        return $COMPARISON_DIFFERENT
    fi
}

# ==============================================================================
# Comparison Reporting Functions
# ==============================================================================

# Generate detailed comparison report
generate_comparison_report() {
    local json1="$1"
    local json2="$2"
    local comparison_result="$3"
    local output_file="${4:-}"
    local report_title="${5:-JSON Comparison Report}"
    
    debug_log "Generating comparison report"
    
    local report=""
    report+="# $report_title\n"
    report+="**Timestamp**: $(date -u '+%Y-%m-%d %H:%M:%S UTC')\n\n"
    
    # Comparison result summary
    case "$comparison_result" in
        "$COMPARISON_IDENTICAL")
            report+="## Result: ✅ IDENTICAL\n"
            report+="The JSON structures are byte-for-byte identical.\n\n"
            ;;
        "$COMPARISON_EQUIVALENT")
            report+="## Result: 🟰 EQUIVALENT\n" 
            report+="The JSON structures are semantically equivalent after field mapping.\n\n"
            ;;
        "$COMPARISON_DIFFERENT")
            report+="## Result: ❌ DIFFERENT\n"
            report+="The JSON structures contain meaningful differences.\n\n"
            ;;
        "$COMPARISON_ERROR")
            report+="## Result: ⚠️ ERROR\n"
            report+="An error occurred during comparison.\n\n"
            ;;
    esac
    
    # Add detailed diff if different
    if [[ "$comparison_result" == "$COMPARISON_DIFFERENT" ]]; then
        report+="## Detailed Differences\n\n"
        
        # Normalize both for better diff display
        local temp1 temp2
        temp1=$(mktemp)
        temp2=$(mktemp)
        
        normalize_json "$json1" "$temp1"
        normalize_json "$json2" "$temp2"
        
        # Format JSON for better readability in diff
        jq . "$temp1" > "${temp1}.pretty" 2>/dev/null || cp "$temp1" "${temp1}.pretty"
        jq . "$temp2" > "${temp2}.pretty" 2>/dev/null || cp "$temp2" "${temp2}.pretty"
        
        report+='```diff\n'
        report+="$(diff -u "${temp1}.pretty" "${temp2}.pretty" 2>/dev/null || echo "Unable to generate diff")\n"
        report+='```\n\n'
        
        # Cleanup temp files
        rm -f "$temp1" "$temp2" "${temp1}.pretty" "${temp2}.pretty"
    fi
    
    # Statistical information
    report+="## Statistics\n\n"
    
    local size1 size2
    size1=$(echo "$json1" | wc -c)
    size2=$(echo "$json2" | wc -c)
    
    report+="- **First JSON size**: $size1 bytes\n"
    report+="- **Second JSON size**: $size2 bytes\n"
    
    # Field count comparison
    local fields1 fields2
    fields1=$(echo "$json1" | jq -r 'paths(scalars) as $p | $p | join(".")' 2>/dev/null | wc -l)
    fields2=$(echo "$json2" | jq -r 'paths(scalars) as $p | $p | join(".")' 2>/dev/null | wc -l)
    
    report+="- **First JSON fields**: $fields1\n"
    report+="- **Second JSON fields**: $fields2\n\n"
    
    # Output report
    if [[ -n "$output_file" ]]; then
        echo -e "$report" > "$output_file"
        echo "Comparison report generated: $output_file"
    else
        echo -e "$report"
    fi
}

# Generate simple comparison summary
generate_comparison_summary() {
    local result="$1"
    local details="$2"
    
    case "$result" in
        "$COMPARISON_IDENTICAL")
            echo -e "${GREEN}✅ IDENTICAL${NC} - JSON structures are byte-for-byte identical"
            ;;
        "$COMPARISON_EQUIVALENT")
            echo -e "${GREEN}🟰 EQUIVALENT${NC} - JSON structures are semantically equivalent"
            if [[ -n "$details" ]]; then
                echo -e "   ${BLUE}Details:${NC} $details"
            fi
            ;;
        "$COMPARISON_DIFFERENT")
            echo -e "${RED}❌ DIFFERENT${NC} - JSON structures contain meaningful differences"
            if [[ -n "$details" ]]; then
                echo -e "   ${YELLOW}Differences:${NC} $details"
            fi
            ;;
        "$COMPARISON_ERROR")
            echo -e "${RED}⚠️ ERROR${NC} - An error occurred during comparison"
            if [[ -n "$details" ]]; then
                echo -e "   ${RED}Error:${NC} $details"
            fi
            ;;
    esac
}

# ==============================================================================
# Edge Case Handling
# ==============================================================================

# Validate JSON input before processing
validate_json_input() {
    local input="$1"
    local input_name="${2:-JSON}"
    
    debug_log "Validating $input_name input"
    
    # Handle empty input
    if [[ -z "$input" ]]; then
        echo "Error: $input_name input is empty" >&2
        return 1
    fi
    
    # Handle file input
    if [[ -f "$input" ]]; then
        if [[ ! -r "$input" ]]; then
            echo "Error: Cannot read $input_name file: $input" >&2
            return 1
        fi
        
        if [[ ! -s "$input" ]]; then
            echo "Warning: $input_name file is empty: $input" >&2
            return 2
        fi
        
        # Validate JSON syntax
        if ! jq -e . "$input" >/dev/null 2>&1; then
            echo "Error: $input_name file contains invalid JSON: $input" >&2
            return 1
        fi
    else
        # Handle string input - validate JSON syntax
        if ! echo "$input" | jq -e . >/dev/null 2>&1; then
            echo "Error: $input_name string contains invalid JSON" >&2
            return 1
        fi
    fi
    
    debug_log "$input_name input validation passed"
    return 0
}

# Handle missing fields gracefully
handle_missing_fields() {
    local json="$1"
    local required_fields="$2"  # Comma-separated list
    
    debug_log "Checking for missing fields: $required_fields"
    
    local field_array=()
    IFS=',' read -ra field_array <<< "$required_fields"
    
    local missing_fields=()
    
    for field in "${field_array[@]}"; do
        if ! echo "$json" | jq -e ".$field" >/dev/null 2>&1; then
            missing_fields+=("$field")
        fi
    done
    
    if [[ ${#missing_fields[@]} -gt 0 ]]; then
        echo "Warning: Missing fields: ${missing_fields[*]}" >&2
        return 1
    fi
    
    return 0
}

# ==============================================================================
# High-Level Comparison Interface
# ==============================================================================

# Main comparison function - handles all comparison types
compare_json_outputs() {
    local json1="$1"
    local json2="$2"
    local options=("${@:3}")  # Remaining arguments as options
    
    # Parse options
    local comparison_type="auto"
    local output_format="summary"
    local output_file=""
    local required_fields=""
    local report_title="JSON Comparison Report"
    
    for ((i=0; i<${#options[@]}; i++)); do
        case "${options[i]}" in
            "--type")
                comparison_type="${options[i+1]}"
                ((i++))
                ;;
            "--format")
                output_format="${options[i+1]}"
                ((i++))
                ;;
            "--output")
                output_file="${options[i+1]}"
                ((i++))
                ;;
            "--required-fields")
                required_fields="${options[i+1]}"
                ((i++))
                ;;
            "--title")
                report_title="${options[i+1]}"
                ((i++))
                ;;
        esac
    done
    
    debug_log "Starting JSON comparison with type: $comparison_type"
    
    # Validate inputs
    if ! validate_json_input "$json1" "First JSON"; then
        return $COMPARISON_ERROR
    fi
    
    if ! validate_json_input "$json2" "Second JSON"; then
        return $COMPARISON_ERROR
    fi
    
    # Check required fields if specified
    if [[ -n "$required_fields" ]]; then
        handle_missing_fields "$json1" "$required_fields" || true
        handle_missing_fields "$json2" "$required_fields" || true
    fi
    
    # Perform comparison
    local result
    compare_json_semantic "$json1" "$json2" "$comparison_type"
    result=$?
    
    # Generate output based on format
    case "$output_format" in
        "summary")
            generate_comparison_summary "$result" ""
            ;;
        "report")
            generate_comparison_report "$json1" "$json2" "$result" "$output_file" "$report_title"
            ;;
        "silent")
            # Only return result code
            ;;
        *)
            echo "Error: Unknown output format: $output_format" >&2
            return $COMPARISON_ERROR
            ;;
    esac
    
    return $result
}

# ==============================================================================
# Utility Functions
# ==============================================================================

# Extract and compare specific command outputs
compare_command_outputs() {
    local github_output="$1"
    local gitlab_output="$2"
    local command_type="${3:-unknown}"
    
    debug_log "Comparing $command_type command outputs"
    
    case "$command_type" in
        "issue-view")
            # Issue view specific comparison
            compare_json_outputs "$github_output" "$gitlab_output" \
                --type "github-to-gitlab" \
                --required-fields "title,state,body" \
                --title "Issue View Comparison"
            ;;
        "issue-list")
            # Issue list specific comparison
            compare_json_outputs "$github_output" "$gitlab_output" \
                --type "github-to-gitlab" \
                --required-fields "title,state,number" \
                --title "Issue List Comparison"
            ;;
        "repo-view")
            # Repository view specific comparison
            compare_json_outputs "$github_output" "$gitlab_output" \
                --type "github-to-gitlab" \
                --required-fields "name" \
                --title "Repository View Comparison"
            ;;
        *)
            # Generic comparison
            compare_json_outputs "$github_output" "$gitlab_output" \
                --type "auto" \
                --title "Generic Command Output Comparison"
            ;;
    esac
}

# Display usage information
show_comparison_help() {
    cat << EOF
JSON Output Comparison Engine - Usage Guide

MAIN FUNCTIONS:
  compare_json_outputs JSON1 JSON2 [OPTIONS]
    Compare two JSON inputs with semantic equivalence checking
    
  compare_command_outputs GITHUB_JSON GITLAB_JSON COMMAND_TYPE
    Compare provider-specific command outputs with appropriate field mapping

OPTIONS:
  --type TYPE           Comparison type: auto|github-to-gitlab|gitlab-to-github
  --format FORMAT       Output format: summary|report|silent  
  --output FILE         Output file for reports
  --required-fields F   Comma-separated list of required fields
  --title TITLE         Report title

UTILITY FUNCTIONS:
  validate_json_input INPUT [NAME]     Validate JSON input
  normalize_json INPUT [OUTPUT_FILE]   Normalize JSON structure
  generate_comparison_report ...       Generate detailed report

EXAMPLES:
  compare_json_outputs file1.json file2.json --format report
  compare_command_outputs "\$gh_out" "\$glab_out" "issue-view"

RETURN CODES:
  0 = Identical          1 = Equivalent
  2 = Different          3 = Error
EOF
}

# Export functions for use in other scripts
if [[ "${BASH_SOURCE[0]}" != "${0}" ]]; then
    # Being sourced - export functions
    export -f compare_json_outputs
    export -f compare_command_outputs  
    export -f normalize_json
    export -f validate_json_input
    export -f generate_comparison_report
    export -f show_comparison_help
    
    debug_log "JSON comparison engine loaded successfully"
fi