# Trace Change

Trace the history and context of a code change to understand why it was made and which
versions are affected.

## Arguments

- `$ARGUMENTS`: Either a commit SHA or a file path with line number (e.g., `a1b2c3d` or
  `src/controller.py:142`)

## Instructions

### 1. Identify the commit

**If given a commit SHA:**

```bash
git show <SHA> --stat
```

**If given a file:line:**

Use git blame to find the commit that last modified that line:

```bash
git blame -L <line>,<line> <file> --porcelain | head -1
```

Extract the commit SHA from the output.

### 2. Get commit details

```bash
git show <SHA> --format=fuller
```

Note:

- Author and committer
- Date
- Commit message (may contain issue references like `#1234`)

### 3. Find affected versions

**ALWAYS fetch tags first** to ensure you have the latest releases:

```bash
git fetch --tags
```

Then list all tags that contain this commit:

```bash
git tag --contains <SHA> | sort -V
```

**Find first version containing the commit:**

```bash
FIRST_TAG=$(git tag --contains <SHA> | sort -V | head -1)
echo "First version: $FIRST_TAG"
```

**Find versions NOT containing the commit (useful for regression analysis):**

```bash
git tag --no-contains <SHA> | sort -V | tail -10
```

### 4. Find the PR/MR

```bash
# GitHub — find PR containing this commit
gh api search/issues -X GET \
  -f q="repo:{owner}/{repo} is:pr SHA:<SHA>" \
  --jq '.items[] | {number, title, user: .user.login, html_url}'

# GitLab
glab api "projects/<project_path>/repository/commits/<SHA>/merge_requests" | \
  jq '.[] | {iid, title, author: .author.username, web_url}'
```

### 5. Find linked issues

**From commit message:**

Look for patterns like `#1234`, `fixes #1234`, `closes #1234` in the commit message.

**From PR/MR description:**

Parse the PR/MR description for issue references.

### 6. Build the timeline

Reconstruct the change timeline:

```
Issue #XXX: <title>
    ↓
PR/MR #YYY: <title> (by @author, merged YYYY-MM-DD)
    ↓
Commit <SHA>: <first line of message>
    ↓
First released in: vX.Y.Z (YYYY-MM-DD)
```

### 7. Summarize the context

Present a summary including:

1. **What changed**: Brief description of the code change
2. **Why it changed**: Context from issue/PR (bug fix, feature, refactoring)
3. **Who made it**: Author and reviewer(s)
4. **When it landed**: Merge date and first release version with date
5. **Affected versions**: List of versions containing this change

## Output Format

```markdown
## Change Context

**Commit**: `<SHA>` - <first line of commit message>
**Author**: @<username> on <date>

### Why this change was made

<Summary from issue/PR description>

### Related links

- Issue: #<number> - <title>
- PR: #<number> - <title>

### Affected versions

| Milestone         | Date           | Notes                             |
| ----------------- | -------------- | --------------------------------- |
| Commit merged     | YYYY-MM-DD     | Into main branch                  |
| **First release** | **YYYY-MM-DD** | **vX.Y.Z** - first in production  |
| Latest release    | YYYY-MM-DD     | vX.Y.Z                            |

### Versions WITHOUT this change

<List of recent versions not containing the commit - useful for regression analysis>
```

## Use Cases

### Investigating a regression

1. User reports bug in v1.5.0 that wasn't in v1.3.0
2. Developer identifies suspicious code
3. Run `/trace-change src/controller.py:142`
4. See that the line was introduced in v1.4.0 via PR #234
5. Confirm timeline matches when user first saw the issue

### Understanding legacy code

1. Developer encounters confusing code during review
2. Run `/trace-change <file>:<line>`
3. Find the original PR and issue explaining why it was written that way

### Code review context

1. Reviewer sees a change to existing code
2. Run `/trace-change` on the original code
3. Understand the history before approving modifications

$ARGUMENTS
