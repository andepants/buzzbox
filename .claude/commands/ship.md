Add all changes to staging, create a commit, push to remote, and create a pull request.

## Usage
- `/ship` - Auto-generate commit message and PR based on changes
- `/ship <custom message>` - Use custom text as context for commit message/PR
- `/ship commit:"<msg>" pr:"<title>"` - Override commit message and/or PR title

## Arguments
When arguments are provided after `/ship`:
- **Plain text**: Used as additional context/description for the auto-generated commit and PR
- **commit:"..."**: Explicitly override the commit message (still adds co-author footer)
- **pr:"..."**: Explicitly override the PR title
- **Both**: You can combine, e.g., `/ship commit:"fix: typo in auth" pr:"Quick auth fix"`

## Steps
1. Run `git status` and `git diff` to see all changes that will be committed
2. If custom commit message provided via `commit:"..."`, use it. Otherwise:
   - Analyze the changes and draft a clear, concise commit message
   - Incorporate any plain text arguments as context
   - Follow the repository's commit message style (check recent commits with `git log`)
   - Summarize the nature of changes and focus on the "why" rather than the "what"
3. Add all files to staging with `git add .`
4. Create the commit with the message ending with:
   🤖 Generated with [Claude Code](https://claude.com/claude-code)

   Co-Authored-By: Claude <noreply@anthropic.com>
5. Push the changes to the remote repository
6. Create a pull request:
   - Use custom PR title from `pr:"..."` if provided
   - Otherwise, use the commit message subject as the PR title
   - Generate a summary of changes (1-3 bullet points)
   - Include a test plan if applicable
   - Incorporate any plain text arguments as additional context

Important: Follow all git safety protocols and never skip hooks unless explicitly requested.
