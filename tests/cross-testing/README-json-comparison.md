# JSON Output Comparison Engine

The JSON Output Comparison Engine provides semantic equivalence validation between GitHub and GitLab command outputs. It focuses on meaningful data comparison rather than exact format matching, making it ideal for cross-provider validation in the REPOCLI testing framework.

## Features

- **Semantic Equivalence Validation**: Compares JSON structures based on meaningful data rather than exact formatting
- **Field Mapping**: Automatically maps between GitHub and GitLab JSON field names (e.g., `body` ↔ `description`)
- **JSON Normalization**: Handles formatting differences, type normalization, and sorting
- **Edge Case Handling**: Gracefully handles empty responses, malformed JSON, and missing fields
- **Detailed Reporting**: Generates comprehensive comparison reports with diff output
- **Flexible Comparison Types**: Supports different comparison strategies (auto, github-to-gitlab, gitlab-to-github)

## Usage

### Basic Usage

```bash
# Source the comparison engine
source tests/cross-testing/lib/output-comparison.sh

# Compare two JSON outputs
compare_json_outputs github_output.json gitlab_output.json

# Compare with specific options
compare_json_outputs file1.json file2.json \
    --type github-to-gitlab \
    --format report \
    --output comparison_report.md

# Command-specific comparison
compare_command_outputs github.json gitlab.json "issue-view"
```

### Return Codes

The comparison functions return specific codes to indicate the result:

- `0` (`COMPARISON_IDENTICAL`): JSON structures are byte-for-byte identical
- `1` (`COMPARISON_EQUIVALENT`): JSON structures are semantically equivalent after field mapping
- `2` (`COMPARISON_DIFFERENT`): JSON structures contain meaningful differences
- `3` (`COMPARISON_ERROR`): An error occurred during comparison

### Field Mappings

The engine automatically handles field mappings between providers:

| GitHub Field | GitLab Field | Description |
|--------------|--------------|-------------|
| `body` | `description` | Issue/PR description text |
| `html_url` | `web_url` | Web interface URL |
| `number` | `iid` | Issue/PR number |
| `user.login` | `author.username` | Creator username |
| `assignees[].login` | `assignees[].username` | Assignee usernames |
| `created_at` | `created_at` | Creation timestamp |
| `updated_at` | `updated_at` | Last update timestamp |
| `state` | `state` | Issue/PR state |
| `labels[].name` | `labels[].name` | Label names |

## API Reference

### Core Functions

#### `compare_json_outputs(json1, json2, [options...])`

Main comparison function that handles all comparison types.

**Parameters:**
- `json1`: First JSON input (file path or JSON string)
- `json2`: Second JSON input (file path or JSON string)
- `options`: Array of option flags

**Options:**
- `--type TYPE`: Comparison type (`auto`, `github-to-gitlab`, `gitlab-to-github`)
- `--format FORMAT`: Output format (`summary`, `report`, `silent`)
- `--output FILE`: Output file for reports
- `--required-fields FIELDS`: Comma-separated list of required fields
- `--title TITLE`: Report title

**Example:**
```bash
compare_json_outputs github.json gitlab.json \
    --type github-to-gitlab \
    --format report \
    --output results.md \
    --title "Issue Comparison Report"
```

#### `compare_command_outputs(github_json, gitlab_json, command_type)`

Compare provider-specific command outputs with appropriate field mapping.

**Parameters:**
- `github_json`: GitHub command output JSON
- `gitlab_json`: GitLab command output JSON  
- `command_type`: Type of command (`issue-view`, `issue-list`, `repo-view`)

**Example:**
```bash
compare_command_outputs "$gh_issue_output" "$glab_issue_output" "issue-view"
```

### Utility Functions

#### `validate_json_input(input, [name])`

Validate JSON input before processing.

**Parameters:**
- `input`: JSON input (file path or JSON string)
- `name`: Optional name for error messages

**Returns:** 0 for valid JSON, 1 for invalid, 2 for empty

#### `normalize_json(input, [output_file])`

Normalize JSON structure for consistent comparison.

**Parameters:**
- `input`: JSON input (file path or JSON string)
- `output_file`: Optional output file path

**Returns:** Normalized JSON string or writes to file

#### `map_github_to_gitlab_fields(github_json)`

Map GitHub JSON fields to GitLab equivalents.

**Parameters:**
- `github_json`: GitHub JSON string

**Returns:** JSON with GitLab-equivalent field names

#### `map_gitlab_to_github_fields(gitlab_json)`

Map GitLab JSON fields to GitHub equivalents.

**Parameters:**
- `gitlab_json`: GitLab JSON string

**Returns:** JSON with GitHub-equivalent field names

#### `generate_comparison_report(json1, json2, result, [output_file], [title])`

Generate detailed comparison report.

**Parameters:**
- `json1`: First JSON input
- `json2`: Second JSON input
- `result`: Comparison result code
- `output_file`: Optional output file path
- `title`: Optional report title

### Advanced Functions

#### `compare_json_semantic(json1, json2, [comparison_type])`

Perform semantic comparison of JSON structures.

**Parameters:**
- `json1`: First JSON input
- `json2`: Second JSON input
- `comparison_type`: Type of comparison (`auto`, `github-to-gitlab`, `gitlab-to-github`)

#### `compare_json_fields(json1, json2, fields)`

Compare specific fields between JSON structures.

**Parameters:**
- `json1`: First JSON input
- `json2`: Second JSON input
- `fields`: Comma-separated list of field paths

**Returns:** Field-by-field comparison results

## Examples

### Example 1: Basic Issue Comparison

```bash
# GitHub issue JSON
cat > github_issue.json << EOF
{
  "number": 42,
  "title": "Bug report",
  "body": "Description of the bug",
  "state": "open",
  "html_url": "https://github.com/user/repo/issues/42"
}
EOF

# GitLab issue JSON
cat > gitlab_issue.json << EOF
{
  "iid": 42,
  "title": "Bug report", 
  "description": "Description of the bug",
  "state": "opened",
  "web_url": "https://gitlab.com/user/repo/-/issues/42"
}
EOF

# Compare issues
source lib/output-comparison.sh
compare_json_outputs github_issue.json gitlab_issue.json --type github-to-gitlab
```

### Example 2: Command Output Validation

```bash
# Capture command outputs
gh_output=$(repocli issue view 42 --json title,body,state)
glab_output=$(repocli issue view 42 --json title,description,state)

# Compare outputs
compare_command_outputs "$gh_output" "$glab_output" "issue-view"
```

### Example 3: Detailed Report Generation

```bash
compare_json_outputs github.json gitlab.json \
    --format report \
    --output detailed_comparison.md \
    --title "Cross-Provider Issue Comparison" \
    --required-fields "title,state,body"
```

## Testing

Run the validation tests to ensure the comparison engine is working correctly:

```bash
# Run comprehensive validation
./validate-comparison-engine.sh

# Test specific functionality
source lib/output-comparison.sh
validate_json_input sample.json "Sample JSON"
normalize_json sample.json
```

## Integration with Cross-Testing Framework

The JSON comparison engine integrates seamlessly with the REPOCLI cross-testing framework:

```bash
# In test scripts
source "$LIB_DIR/output-comparison.sh"

# Execute commands and compare outputs
github_result=$(execute_repocli_isolated issue view 42 --json title,body)
gitlab_result=$(execute_repocli_isolated issue view 42 --json title,description)

# Validate equivalence
if compare_command_outputs "$github_result" "$gitlab_result" "issue-view"; then
    echo "✅ Issue view commands produce equivalent output"
else
    echo "❌ Issue view commands produce different output"
fi
```

## Error Handling

The comparison engine includes comprehensive error handling:

- **Invalid JSON**: Returns `COMPARISON_ERROR` with descriptive error messages
- **Missing Files**: Validates file existence and readability
- **Empty Responses**: Handles empty JSON objects and arrays gracefully  
- **Missing Fields**: Warns about missing required fields but continues comparison
- **Malformed Data**: Uses `jq` for robust JSON parsing and validation

## Performance Considerations

- **Large JSON Files**: Uses streaming JSON processing where possible
- **Memory Usage**: Normalizes JSON in-place to minimize memory overhead
- **Temporary Files**: Automatically cleans up temporary files used for diff generation
- **Caching**: Reuses normalized JSON within single comparison operations

## Troubleshooting

### Common Issues

1. **jq not found**: Ensure `jq` is installed and available in PATH
2. **Permission denied**: Check file permissions for input JSON files
3. **Invalid JSON**: Use `validate_json_input` to check JSON syntax before comparison
4. **Field mapping issues**: Review field mapping tables and use debug mode

### Debug Mode

Enable debug logging for detailed troubleshooting:

```bash
export REPOCLI_DEBUG=1
compare_json_outputs file1.json file2.json
```

### Getting Help

```bash
# Show usage information
source lib/output-comparison.sh
show_comparison_help
```

## Contributing

When extending the JSON comparison engine:

1. **Add new field mappings** to the `GITHUB_TO_GITLAB_FIELD_MAP` array
2. **Test thoroughly** with real provider data
3. **Update documentation** with new features and mappings
4. **Add validation tests** for new functionality
5. **Consider edge cases** and error conditions

## Dependencies

- **bash**: Shell scripting environment
- **jq**: JSON parsing and manipulation
- **diff**: Text comparison for detailed reports
- **mktemp**: Temporary file creation