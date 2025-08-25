# PM_TODO - PM System Reminders

**NOTE: This is a reminder file only for this REPOCLI project.**
**PM-specific improvements will be addressed in a separate PM system project.**

## PM System Improvements

### 🚨 CRITICAL: Use Existing PM Scripts
- [ ] **STOP creating temporary scripts** - Always use/test/update `.claude/scripts/pm/*.sh`
- [ ] Update `.claude/scripts/pm/fix.sh` to handle PR/Issue confusion (like #28 being a PR not an issue)
- [ ] Add `--pr-check` option to `/pm:fix` for detecting and fixing PR mistaken as issues
- [ ] Add `--epic` option to `/pm:fix` to fix only specific epic (e.g., `/pm:fix --issue --epic futur`)
- [ ] Update `.claude/scripts/pm/sync.sh` to use the fix.sh script instead of inline code

### 🧠 Brainstorming: Simple Dirty State Tracking
- [ ] **Track Local Changes with Dirty Flag**:
  - Add `dirty: true/false` to frontmatter when file is modified locally
  - Set `dirty: true` when:
    - User edits the file locally
    - Status changes locally (e.g., marking task as completed)
    - Any local modification that needs to sync to GitHub
  - Set `dirty: false` when:
    - Successfully pushed to GitHub
    - Pulled from GitHub (GitHub state applied)
  - **Key insight**: Local completed task MUST be pushed to GitHub (dirty: true)
  - Benefits:
    - Simple boolean flag, easy to implement
    - Clear semantics: dirty = needs push to GitHub
    - Handles the important case: local status changes need syncing
  - Economy mode behavior:
    - Skip tasks with `dirty: false` (already synced)
    - Always sync tasks with `dirty: true` (have local changes)
    - `--all` flag forces sync even if `dirty: false`

### 🧠 Brainstorming: Conflict Resolution & Merging
- [ ] **Task Conflict Merge Strategies**:
  - When both local and GitHub changed since last sync, how to merge?
  - Options to consider:
    1. **Interactive merge**: Show diff, ask user to choose/edit
    2. **Field-by-field merge**: Title from GitHub, body from local, etc.
    3. **Timestamp-based**: Always take the newer version
    4. **GitHub-wins**: GitHub always takes precedence (simpler but may lose local work)
    5. **Local-wins with backup**: Keep local, save GitHub version as .backup
  - Special cases:
    - Status conflicts (local: open, GitHub: closed) - GitHub should probably win
    - Title changes - probably need human decision
    - Body/description changes - could attempt 3-way merge?
  - Should maintain conflict markers in file like git? `<<<<<<< LOCAL`

### 🧠 Brainstorming: Smart Comment Tracking with Role Context
- [ ] **Lightweight Comment Monitoring with Role-Aware AI Summary**:
  - Track `comment_count: N` in frontmatter
  - Track `comment_participants` with roles for context
  - AI needs to understand WHO is commenting for proper weight/relevance
  - Benefits:
    - Super economical - no full comment sync needed
    - AI can prioritize based on roles (owner decisions vs external suggestions)
    - User knows when important stakeholders commented
  - Implementation:
    ```yaml
    comment_count: 5
    comment_participants:
      - user: "@projectowner"
        role: "owner"      # owner/maintainer/contributor/external
        comments: 2
      - user: "@techarch"
        role: "maintainer"
        comments: 1
      - user: "@randomuser"
        role: "external"
        comments: 2
    comment_summary: "Owner approved approach. Tech architect raised performance concern. External user suggested feature - marked for later."
    comment_last_update: 2025-08-25T10:00:00Z
    ```
  - Role detection:
    - Check repo permissions/collaborators via API
    - Maintain a `.team-roles.yml` file with known roles
    - Default to "external" for unknown users
  - AI prompt: "Summarize comments, noting WHO said what based on their role. Prioritize decisions from owners/maintainers over suggestions from external users."
  - This helps understand if comments need immediate action or are just suggestions

### Sync Logic Improvements
- [ ] **Skip Completed Issues by Default (Economy Mode)**:
  - Don't sync `status: completed` tasks from local → GitHub to save API calls
  - Default behavior is economical - only sync active/open tasks
  - Reduces unnecessary GitHub operations and API rate limit usage
  - Exception: If GitHub shows a completed issue as OPEN, still update locally (GitHub state wins)
- [ ] **Add `--all` flag for full sync when needed**:
  - `/pm:sync --all` - Force sync ALL issues including completed ones (more API calls)
  - `/pm:sync` (without --all) - Economical mode, only sync active tasks
  - Most of the time you only need to sync active work, not historical completed tasks

### Specific Recurring Problems to Add to fix.sh
- [ ] **PR/Issue Confusion**: Detect when a GitHub URL points to a PR instead of an issue
  - Check with `gh issue view` vs `gh pr view`
  - Clean broken URL with explanation
  - Create proper issue and update references
- [ ] **Phantom URLs**: Detect URLs that return 404 or point to wrong repo
- [ ] **Sequential Number Breaks**: Handle when PRs disrupt issue numbering sequence

### Testing Requirements
- [ ] Test all PM scripts with edge cases before deployment
- [ ] Ensure scripts handle errors gracefully
- [ ] Add verbose logging mode for debugging

## Notes
Created: 2025-08-25
Reason: Keep using permanent scripts in `.claude/scripts/pm/` instead of creating temporary scripts repeatedly. This ensures consistency and allows for iterative improvements.