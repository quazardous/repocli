# CLAUDE.md

> Think carefully and implement the most concise solution that changes as little code as possible.

## USE SUB-AGENTS FOR CONTEXT OPTIMIZATION

### 1. Always use the file-analyzer sub-agent when asked to read files.
The file-analyzer agent is an expert in extracting and summarizing critical information from files, particularly log files and verbose outputs. It provides concise, actionable summaries that preserve essential information while dramatically reducing context usage.

### 2. Always use the code-analyzer sub-agent when asked to search code, analyze code, research bugs, or trace logic flow.

The code-analyzer agent is an expert in code analysis, logic tracing, and vulnerability detection. It provides concise, actionable summaries that preserve essential information while dramatically reducing context usage.

### 3. Always use the test-runner sub-agent to run tests and analyze the test results.

Using the test-runner agent ensures:

- Full test output is captured for debugging
- Main conversation stays clean and focused
- Context usage is optimized
- All issues are properly surfaced
- No approval dialogs interrupt the workflow

## Philosophy

### Error Handling

- **Fail fast** for critical configuration (missing text model)
- **Log and continue** for optional features (extraction model)
- **Graceful degradation** when external services unavailable
- **User-friendly messages** through resilience layer

### Testing

- Always use the test-runner agent to execute tests.
- Do not use mock services for anything ever.
- Do not move on to the next test until the current test is complete.
- If the test fails, consider checking if the test is structured correctly before deciding we need to refactor the codebase.
- Tests to be verbose so we can use them for debugging.


## Tone and Behavior

- Criticism is welcome. Please tell me when I am wrong or mistaken, or even when you think I might be wrong or mistaken.
- Please tell me if there is a better approach than the one I am taking.
- Please tell me if there is a relevant standard or convention that I appear to be unaware of.
- Be skeptical.
- Be concise.
- Short summaries are OK, but don't give an extended breakdown unless we are working through the details of a plan.
- Do not flatter, and do not give compliments unless I am specifically asking for your judgement.
- Occasional pleasantries are fine.
- Feel free to ask many questions. If you are in doubt of my intent, don't guess. Ask.

## ABSOLUTE RULES:

- NO PARTIAL IMPLEMENTATION
- NO SIMPLIFICATION : no "//This is simplified stuff for now, complete implementation would blablabla"
- NO CODE DUPLICATION : check existing codebase to reuse functions and constants Read files before writing new functions. Use common sense function name to find them easily.
- NO DEAD CODE : either use or delete from codebase completely
- IMPLEMENT TEST FOR EVERY FUNCTIONS
- NO CHEATER TESTS : test must be accurate, reflect real usage and be designed to reveal flaws. No useless tests! Design tests to be verbose so we can use them for debuging.
- NO INCONSISTENT NAMING - read existing codebase naming patterns.
- NO OVER-ENGINEERING - Don't add unnecessary abstractions, factory patterns, or middleware when simple functions would work. Don't think "enterprise" when you need "working"
- NO MIXED CONCERNS - Don't put validation logic inside API handlers, database queries inside UI components, etc. instead of proper separation
- NO RESOURCE LEAKS - Don't forget to close database connections, clear timeouts, remove event listeners, or clean up file handles

## PROJECT MANAGEMENT RULES:

### Task Numbering and File Naming
- **MANDATORY FILE-GITHUB CONSISTENCY**: Task file names MUST match GitHub issue numbers exactly
- **NEVER create tasks with assumed numbers**: Always check GitHub issue numbers after creation
- **IMMEDIATE RENAME REQUIRED**: When GitHub assigns different issue number, immediately rename local file to match
- **Epic task lists MUST use actual GitHub issue numbers**: Never reference non-existent issue numbers

**Examples:**
- ✅ CORRECT: File `.claude/epics/epic-name/14.md` for GitHub issue #14
- ❌ WRONG: File `.claude/epics/epic-name/11.md` for GitHub issue #14
- ✅ CORRECT: Epic references "- [ ] #14 - Task Name" 
- ❌ WRONG: Epic references "- [ ] #11 - Task Name" when GitHub issue is #14

**Process:**
1. Create task file with sequential number (e.g., `11.md`) with `github: # TO BE CREATED`
2. Create GitHub issue from file (`gh issue create --body-file 11.md`)  
3. GitHub assigns actual number (e.g., #14)
4. **IMMEDIATELY** extract GitHub issue number from URL
5. **SYSTEMATICALLY** check if file name matches GitHub issue number
6. **IMMEDIATELY** rename file if needed (`mv 11.md 14.md`)
7. **IMMEDIATELY** update file frontmatter (`github: .../issues/14`)
8. **IMMEDIATELY** update epic task list to reference correct number (#14)

### GitHub URL Assignment Rules
- **NEVER pre-fill GitHub URLs for non-existent issues**
- **USE `github: # TO BE CREATED` for new tasks**
- **ONLY add actual GitHub URL after issue creation**
- **PHANTOM URLS cause --fix flag confusion and sync issues**

**✅ CORRECT:**
```yaml
github: # TO BE CREATED - issue not yet on GitHub
```

**❌ INCORRECT:**
```yaml
github: https://github.com/owner/repo/issues/27  # Issue doesn't exist yet!
```

### Sync Operations
- **ALWAYS maintain file-GitHub number consistency** during sync operations
- **SYSTEMATICALLY check file names after every GitHub URL assignment**
- **AUTOMATIC verification: file name MUST match GitHub issue number**
- **DETECT and FIX naming mismatches** during `/pm:sync`
- **UPDATE epic task lists** when issue numbers change
- **--fix flag is ONLY for existing issues with file naming problems**
- **--fix flag does NOT work on phantom GitHub URLs**

### Critical Verification Algorithm
**MANDATORY after every GitHub issue creation:**
```bash
# Extract GitHub issue number from URL
github_number=$(grep "^github:" file.md | grep -o '[0-9]*$')
local_number=$(basename file.md .md)

# SYSTEMATIC check - NEVER skip this
if [[ "$local_number" != "$github_number" ]]; then
    echo "🚨 CRITICAL: File name mismatch detected!"
    echo "   File: $local_number.md"  
    echo "   GitHub: #$github_number"
    echo "   IMMEDIATE ACTION REQUIRED"
    # Auto-fix MUST happen immediately
    mv "$local_number.md" "$github_number.md"
    # Update all references...
fi
```
