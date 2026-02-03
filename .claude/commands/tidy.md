# Tidy

Lint, format, and generate documentation for the codebase.

## Steps

### 1. Find Terraform Directories

Find all directories containing `main.tf` files from the project root, excluding `.terraform/` directories:
```bash
cd <project-root> && find . -name "main.tf" -not -path "*/.terraform/*" -exec dirname {} \; | sort -u
```

All subsequent steps should operate from the project root to ensure consistent paths.

### 2. Add Missing Terraform Docstrings

For each `main.tf` found, check if it starts with a `/** ... */` docstring block. If missing, add one describing what the module does.

If a `Taskfile.yml` exists in the same directory, include a "Tasks" section documenting the key tasks.

Example format:
```hcl
/**
 * # Module Name
 *
 * Brief description of what this module deploys/manages.
 *
 * ## Tasks
 *
 * Run with `task <name>` from this directory.
 *
 * - `apply` - Apply terraform and create DNS record
 * - `destroy` - Full destroy - cleanup resources and run terraform destroy
 * - `setup-tfvars` - Create terraform.tfvars with IAM user and SSO role
 */
```

Include tasks that are useful for operators (apply, destroy, setup, cleanup, etc.). Skip internal/helper tasks.

### 3. Tidy Terraform Section Comments

Ensure all `.tf` files use consistent section comment headers. Each logical group of resources should have a header in this format:

```hcl
# -----------------------------------------------------------------------------
# Section Title
# -----------------------------------------------------------------------------
```

Rules:
- Use 77 dashes (total line width: 79 chars with `# `)
- Title should be descriptive (e.g., "VPC Configuration", "IAM Roles", "EKS Cluster")
- Add missing section headers for ungrouped resources
- Standardize inconsistent headers to match this format
- Group related resources under the same section

### 4. Python Linting and Formatting

Always run from the project root to catch all Python files:
```bash
cd <project-root> && ruff check --fix . && ruff format .
```

If no Python files exist in the project, this step can be skipped.

### 5. Terraform Formatting and Docs

Run in each directory containing `main.tf`:
```bash
terraform fmt -recursive
terraform-docs markdown table --output-file README.md .
```

Or use the global task from the project root:
```bash
task -g tf:pre-commit
```

Then for each subfolder with `main.tf`, run:
```bash
cd <subfolder> && terraform-docs markdown table --output-file README.md .
```

### 6. Tidy Conda Environment Files

Find all `environment.yml` files and:

1. **Alphabetize dependencies** - Keep `python` at the top, sort the rest alphabetically
2. **Add version constraints** - Ensure all deps follow `>=minor,<nextmajor` pattern

Version constraint format:
- `package >=X.Y,<Z` where Z is the next major version
- Example: `openai >=2.14,<3` (allows 2.14+ but not 3.x)

If a dependency is missing version constraints, look up the current version and add appropriate bounds.

Example:
```yaml
dependencies:
  - python >=3.14,<4

  - openai >=2.14,<3
  - pydantic >=2,<3
  - pydantic-settings >=2,<3
  - streamlit >=1.52,<2
```

### 7. Update VS Code Conventional Commit Scopes

Check `.vscode/settings.json` for the `conventionalCommits.scopes` array. Add any tracked files (non-gitignored) that are missing from the list.

Files to consider adding:
- Root `.tf` files
- Key config files (Taskfile.yml, .gitignore, etc.)
- Directories containing source code (images/*, deployment/*)
- New `.tf` files in subdirectories

Do NOT add:
- Files/folders in `.gitignore`
- `.terraform/` directories
- Generated files (README.md, lock files)
- Hidden files except `.vscode`, `.gitignore`

## Instructions

**Important:** Always run all steps from the project root directory, regardless of where the user invoked the command.

1. Find all directories with `main.tf` from project root (excluding `.terraform/`)
2. Read each `main.tf` and add missing docstring headers (include Tasks section if Taskfile.yml exists)
3. Tidy Terraform section comments (77 dashes, consistent format)
4. Run ruff for Python linting/formatting from project root (searches all subdirectories)
5. Run terraform fmt and terraform-docs in each Terraform directory
6. Tidy `environment.yml`: alphabetize deps (python first) and add version constraints (`>=minor,<nextmajor`)
7. Update `.vscode/settings.json` with any missing tracked files
8. Report any issues found and changes made
