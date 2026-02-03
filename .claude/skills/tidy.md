# Tidy

Lint, format, and generate documentation for the codebase.

## Steps

### 1. Find Terraform Directories

Find all directories containing `main.tf` files, excluding `.terraform/` directories:
```bash
find . -name "main.tf" -not -path "*/.terraform/*" -exec dirname {} \; | sort -u
```

### 2. Add Missing Terraform Docstrings

For each `main.tf` found, check if it starts with a `/** ... */` docstring block. If missing, add one describing what the module does.

Example format:
```hcl
/**
 * # Module Name
 *
 * Brief description of what this module deploys/manages.
 */
```

### 3. Python Linting and Formatting

```bash
ruff check --fix . && ruff format .
```

### 4. Terraform Formatting and Docs

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

### 5. Update VS Code Conventional Commit Scopes

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

1. Find all directories with `main.tf` (excluding `.terraform/`)
2. Read each `main.tf` and add missing docstring headers
3. Run ruff for Python linting/formatting
4. Run terraform fmt and terraform-docs in each Terraform directory
5. Update `.vscode/settings.json` with any missing tracked files
6. Report any issues found and changes made
