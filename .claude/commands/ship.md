Add all changes to staging, create a commit, push to remote, and create a pull request.

Steps:
1. Run `git status` and `git diff` to see all changes that will be committed
2. Analyze the changes and draft a clear, concise commit message that:
   - Summarizes the nature of the changes
   - Focuses on the "why" rather than the "what"
   - Follows the repository's commit message style (check recent commits with `git log`)
3. Add all files to staging with `git add .`
4. Create the commit with the message ending with:
   🤖 Generated with [Claude Code](https://claude.com/claude-code)

   Co-Authored-By: Claude <noreply@anthropic.com>
5. Push the changes to the remote repository
6. Create a pull request with:
   - A clear title
   - A summary of changes (1-3 bullet points)
   - A test plan if applicable

Important: Follow all git safety protocols and never skip hooks unless explicitly requested.
