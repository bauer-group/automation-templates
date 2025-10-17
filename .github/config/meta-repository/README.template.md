# {{TITLE}}

> {{DESCRIPTION}}

---

## 📋 Overview

This meta repository automatically synchronizes and organizes projects from the **{{ORGANIZATION}}** organization based on GitHub topics.

**Last synchronized:** {{DATE}}

## 🎯 Purpose

This repository serves as a central hub for:
- 📦 **Submodule Management** - All projects are included as Git submodules
- 📊 **Documentation** - Automatically generated lists of all projects
- 🔍 **Discovery** - Easy browsing of project portfolio by category
- 🔄 **Synchronization** - Automatic updates when projects change

## 📦 Project Collections

{{GROUPS}}

## 🔄 Automatic Synchronization

This repository is automatically maintained by GitHub Actions:

- **Schedule**: Weekly updates every Saturday at 23:45 UTC
- **Triggers**:
  - Scheduled runs (cron)
  - Manual workflow dispatch
  - Repository dispatch events from individual projects
- **Features**:
  - ✅ Auto-detects default branch (main/master)
  - ✅ Per-topic prefix removal for clean names
  - ✅ Automatic cleanup of removed repositories
  - ✅ Submodules updated to latest commits
  - ✅ README.md regenerated with current project lists
  - ✅ JSON/TXT files updated with repository metadata

## 📁 Repository Structure

```
.
├── Plugins/              # Submodules organized by topic
│   ├── Plugin1/
│   ├── Plugin2/
│   └── ...
├── Themes/               # Another topic group
├── shopware5-plugins.json  # Machine-readable project list
├── shopware5-plugins.txt   # Simple text list
└── README.md             # This file (auto-generated)
```

## 🚀 Usage

### Clone with Submodules

```bash
# Clone the meta repository with all submodules
git clone --recursive https://github.com/{{ORGANIZATION}}/meta-repository-name.git

# Or initialize submodules after cloning
git clone https://github.com/{{ORGANIZATION}}/meta-repository-name.git
cd meta-repository-name
git submodule update --init --recursive
```

### Update All Submodules

```bash
# Update all submodules to their latest commits
git submodule update --remote --recursive
```

### Work with Individual Projects

```bash
# Navigate to a specific project
cd Plugins/ProjectName

# Make changes
git checkout -b feature/my-feature
# ... make changes ...
git commit -am "feat: add new feature"
git push origin feature/my-feature

# Return to meta repository
cd ../..
```

## 📊 Data Formats

### JSON Format
Each topic group has a corresponding `.json` file containing:
- Repository name
- Description
- Default branch
- HTML and Git URLs
- Topics
- Last update timestamp

### TXT Format
Simple newline-separated list of repository names for easy scripting.

## ⚙️ Configuration

The meta repository is configured via `.github/config/meta-repository/topics.json`:

```json
{
  "title": "Repository Title",
  "description": "Repository description",
  "groups": [
    {
      "topic": "github-topic-name",
      "folder": "FolderName",
      "name": "Display Name",
      "description": "Group description",
      "remove_prefix": "^PREFIX[-_]"
    }
  ]
}
```

**Key features:**
- **Per-topic prefix removal**: Each topic can have its own `remove_prefix` pattern
- **Flexible organization**: Group repositories by any GitHub topic
- **Auto-cleanup**: Removed repositories are automatically deleted from submodules

## 🤝 Contributing

This is an automated repository. To contribute:

1. **Make changes in individual projects** - Commit to the actual project repositories
2. **Trigger sync** - The meta repository will update automatically, or trigger manually via workflow dispatch
3. **Update configuration** - Modify `.github/config/meta-repository/topics.json` to change grouping or prefix patterns

## 📞 Support

For issues with individual projects, please use their respective issue trackers.
For meta repository configuration or synchronization issues, open an issue in this repository.

---

*This README is automatically generated. Do not edit manually - changes will be overwritten.*
*Generated on {{DATE}}*
