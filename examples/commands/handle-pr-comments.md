# Handle PR Comments

Address review comments on a pull request interactively.

## Arguments

- `$ARGUMENTS`: PR number or URL (e.g., `200` or full URL)

## Workflow

### Phase 1: Collect and Analyze

1. **Extract PR number** from arguments (strip URL if needed)

2. **Fetch unresolved review comments**:

```bash
# GitHub - inline code comments
gh api repos/{owner}/{repo}/pulls/<number>/comments \
  --jq '.[] | {id, user: .user.login, path, line, body}'

# GitHub - general discussion comments
gh api repos/{owner}/{repo}/issues/<number>/comments \
  --jq '.[] | {id, user: .user.login, body}'
```

3. **Present a summary** of all comments to the user:
   - Comment number, author, file/line, and summary
   - Group by topic if related
   - Distinguish inline (code) comments from general comments

### Phase 2: Process Each Comment

For each comment, **one at a time**:

1. **Read the relevant code** to understand the context
2. **Propose a solution**:
   - If code change needed: describe the change
   - If just a response needed: draft the response
   - If disagreement: explain the tradeoff and let the user decide
3. **Wait for user validation** before proceeding
4. **Apply the change** if approved (code modification)
5. Move to the next comment

### Phase 3: Commit and Push

After all comments are addressed:

1. **Run tests** to ensure nothing is broken
2. **Commit** with a descriptive message summarizing all changes
3. **Push** to the remote branch

### Phase 4: Reply to Comments

For each comment that was addressed:

1. **Draft a response** explaining what was done
2. **Wait for user validation** before sending
3. **Post the reply**:

```bash
# Reply to an inline review comment (GitHub)
gh api repos/{owner}/{repo}/pulls/<number>/comments/<comment_id>/replies \
  -X POST \
  -f body="<response>"

# Reply to a general issue comment (GitHub)
gh api repos/{owner}/{repo}/issues/<number>/comments \
  -X POST \
  -f body="<response>"
```

### Phase 5: Introspection

After all comments are replied to, **reflect on the review**:

1. **Identify patterns** in the feedback
2. **Propose rule updates** if relevant (see `auto-introspection.md`)
3. **Ask user** before applying any config changes

## Key Principles

1. **One comment at a time** - Don't batch process, let user validate each step
2. **Propose before acting** - Always get approval before code changes
3. **Test before commit** - Run tests after all changes are applied
4. **Validate before posting** - Let user approve each reply
5. **Learn from feedback** - Update rules to prevent future similar comments

$ARGUMENTS
