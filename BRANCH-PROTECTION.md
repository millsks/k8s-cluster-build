# Branch Protection Quick Start Guide

This is a quick reference for configuring branch protection on GitHub. For detailed information, see [docs/github-branch-protection.md](docs/github-branch-protection.md).

## Quick Setup (5 minutes)

1. Go to: **Settings** → **Branches** → **Add rule**
2. Branch name pattern: `main`
3. Enable these essential settings:
   - ☑ **Do not allow force pushes**
   - ☑ **Do not allow deletions**
4. Click **Create** or **Save changes**

✅ Your main branch is now protected from deletion and force pushes!

## Recommended Additional Settings

For a more robust workflow, also enable:

- ☑ **Require a pull request before merging** (with 0 required approvals)
- ☑ **Require conversation resolution before merging**
- ☑ **Require linear history**

## Why These Settings?

- **Prevents accidents**: Can't accidentally delete or force-push to main
- **Better workflow**: Encourages feature branches and PRs
- **Clean history**: Linear git history is easier to understand
- **Solo-friendly**: No approval requirements, so you can merge immediately

## Development Workflow

```bash
# Create feature branch
git checkout -b feature/my-change

# Make changes and commit
git add .
git commit -m "Description of change"
git push origin feature/my-change

# Create PR on GitHub, review, and merge
# Then update local main
git checkout main
git pull origin main
```

## Full Documentation

See [docs/github-branch-protection.md](docs/github-branch-protection.md) for:
- Detailed explanation of all settings
- Rationale for each recommendation
- Solo developer considerations
- Troubleshooting tips
- Future collaboration guidance
