# Documentation Center

**Comprehensive documentation templates and guides for automation workflows**

## 📚 Overview

This directory contains all documentation templates, guides, and reference materials for the automation templates repository. Our documentation system supports template-based generation, multi-format output, and enterprise-grade content standards.

## 📄 Available Documentation

### Core Templates

#### `README.template.MD`

Master template for generating repository README files with dynamic content injection.

**Features:**

- Variable substitution system
- Conditional content blocks
- Badge generation
- Multi-project support
- Automated metadata extraction

**Usage:**

```yaml
# Use via GitHub workflow call
- name: 📝 Generate README
  uses: bauer-group/automation-templates/.github/workflows/documentation.yml@main
  with:
    force-update: true
    custom-version: "1.0.0"
    
# Or use the action directly
- name: 📝 Generate README 
  uses: bauer-group/automation-templates/.github/actions/readme-generate@main
  with:
    template-path: 'docs/README.template.MD'
    output-path: 'README.MD'
    project-name: 'My Project'
    company-name: 'My Company'
    custom-version: '1.0.0'
```

**Template Variables:**

```yaml
# Repository information
REPO_FULL_NAME: "owner/repository"
REPO_URL: "https://github.com/owner/repository"
REPO_OWNER: "owner"
REPO_NAME: "repository"
CURRENT_BRANCH: "main"

# Project information
PROJECT_NAME: "Project Name"
PROJECT_DESCRIPTION: "Project description"
COMPANY_NAME: "Company Name"
CONTACT_EMAIL: "contact@company.com"
VERSION: "1.0.0"
DATE: "2024-01-01"

# Feature flags
ENABLE_SECURITY_SECTION: true
ENABLE_RELEASE_SECTION: true
ENABLE_DOCUMENTATION_SECTION: true
```

### Release Documentation

#### `ENHANCED-RELEASE-SUMMARY.md`

Comprehensive summary of enhanced release management features and capabilities.

**Contents:**

- Release automation overview
- Security integration details
- Workflow configuration examples
- Best practices and guidelines

#### `ENHANCED-RELEASE-FIXES.md`

Documentation of fixes and improvements implemented in the enhanced release system.

**Contents:**

- Issue resolution history
- Performance improvements
- Security enhancements
- Compatibility updates

#### `ENHANCED-RELEASE-UPDATE.md`

Update guide for migrating to enhanced release management workflows.

**Contents:**

- Migration procedures
- Configuration updates
- Breaking changes
- Upgrade paths

#### `UNIVERSAL-RELEASE.MD`

Universal release management documentation covering cross-platform release automation.

**Contents:**

- Multi-platform release strategies
- Environment-specific configurations
- Release pipeline architectures
- Integration patterns

## 🔧 Template System

### Variable Substitution

The template system supports multiple variable formats:

```markdown
# Simple variables
{{VARIABLE_NAME}}

# Conditional blocks
{{#IF CONDITION}}
Content shown when condition is true
{{/IF}}

# Loops
{{#EACH ITEMS}}
- {{name}}: {{description}}
{{/EACH}}

# Includes
{{>INCLUDE_FILE}}
```

### Configuration Files

#### Template Configuration (`template-config.json`)

```json
{
  "template_settings": {
    "variable_prefix": "{{",
    "variable_suffix": "}}",
    "conditional_prefix": "{{#",
    "conditional_suffix": "}}",
    "encoding": "utf-8"
  },
  "default_variables": {
    "COMPANY_NAME": "Your Company",
    "LICENSE": "MIT",
    "SUPPORT_EMAIL": "support@company.com"
  },
  "content_sections": {
    "security": true,
    "release": true,
    "documentation": true,
    "contributing": true
  }
}
```

#### Project Variables (`project-vars.json`)

```json
{
  "repository": {
    "name": "automation-templates",
    "owner": "bauer-group",
    "description": "Professional automation templates",
    "url": "https://github.com/bauer-group/automation-templates"
  },
  "project": {
    "name": "Automation Templates",
    "version": "1.0.0",
    "license": "MIT",
    "author": "Bauer Group Development Team"
  },
  "features": {
    "security_scanning": true,
    "release_automation": true,
    "branch_protection": true,
    "compliance_checking": true
  }
}
```

## 🚀 Documentation Generation

### Automated Generation

```yaml
name: Documentation Update

on:
  push:
    branches: [main]
    paths: ['docs/**', 'scripts/**']

jobs:
  generate-docs:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
        with:
          token: ${{ secrets.GITHUB_TOKEN }}
          
      - name: Setup Python
        uses: actions/setup-python@v4
        with:
          python-version: '3.12'
          
      - name: Install dependencies
        run: |
          pip install jinja2 pyyaml markdown
          
      - name: 📝 Generate Professional README
        uses: bauer-group/automation-templates/.github/actions/readme-generate@main
        with:
          template-path: 'docs/README.template.MD'
          output-path: 'README.MD'
          force-update: true
            
      - name: Commit documentation
        run: |
          git config --local user.email "action@github.com"
          git config --local user.name "GitHub Action"
          git add README.MD
          git diff --staged --quiet || git commit -m "docs: update generated documentation"
          git push
```

### Manual Generation

```yaml
# Manual trigger workflow
name: Manual README Generation
on: workflow_dispatch

jobs:
  generate:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - name: 📝 Generate README
        uses: bauer-group/automation-templates/.github/actions/readme-generate@main
        with:
          template-path: 'docs/README.template.MD'
          output-path: 'README.MD'
          project-name: 'My Project'
          company-name: 'My Company'
          force-update: true
  --outputs "README.MD,docs/generated/README.html,docs/generated/README.pdf"
```

## 📊 Documentation Standards

### Content Guidelines

1. **Structure**:
   - Use hierarchical heading structure (H1 → H2 → H3)
   - Include table of contents for long documents
   - Provide quick start sections
   - Include comprehensive examples

2. **Formatting**:
   - Use consistent markdown formatting
   - Include code syntax highlighting
   - Use tables for structured data
   - Include diagrams where helpful

3. **Content Quality**:
   - Write clear, concise explanations
   - Include practical examples
   - Provide troubleshooting sections
   - Keep documentation up-to-date

### Style Guide

#### Code Blocks

```yaml
# Always specify language
name: Example Workflow
on: [push]
jobs:
  test:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
```

#### Configuration Examples

```json
{
  "example": "Always provide complete, working examples",
  "comments": "Include explanatory comments",
  "formatting": "Use proper JSON formatting"
}
```

#### Command Examples

```bash
# Provide context and explanation
export GITHUB_TOKEN=your_token_here

# Show expected output where helpful
python script.py --help
# Output: Usage: script.py [OPTIONS]
```

### Documentation Types

#### API Documentation

- **Endpoint descriptions**: Clear API endpoint documentation
- **Parameter tables**: Structured parameter documentation
- **Example requests**: Complete request/response examples
- **Error handling**: Common error scenarios and solutions

#### User Guides

- **Step-by-step instructions**: Clear procedural documentation
- **Screenshots**: Visual guides where helpful
- **Prerequisites**: Required setup and dependencies
- **Troubleshooting**: Common issues and solutions

#### Reference Documentation

- **Configuration options**: Complete configuration reference
- **Command-line interfaces**: CLI documentation
- **Environment variables**: Environment configuration
- **File formats**: Supported file format documentation

## 🔄 Documentation Workflow

### Content Lifecycle

1. **Planning**: Document requirements and structure
2. **Creation**: Write initial content using templates
3. **Review**: Peer review for accuracy and clarity
4. **Publication**: Generate and deploy documentation
5. **Maintenance**: Regular updates and improvements

### Review Process

```yaml
name: Documentation Review

on:
  pull_request:
    paths: ['docs/**', '*.md']

jobs:
  review:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      
      - name: Lint documentation
        uses: DavidAnson/markdownlint-action@v1
        with:
          files: '**/*.md'
          config: '.markdownlint.json'
          
      - name: Check links
        uses: gaurav-nelson/github-action-markdown-link-check@v1
        with:
          use-quiet-mode: 'yes'
          
      - name: Validate templates
        run: |
          python scripts/validate_templates.py docs/
```

### Quality Assurance

#### Automated Checks

- **Markdown linting**: Consistent formatting and style
- **Link validation**: Ensure all links are functional
- **Template validation**: Verify template syntax
- **Content validation**: Check for required sections

#### Manual Review

- **Technical accuracy**: Verify technical content
- **Clarity and readability**: Ensure clear communication
- **Completeness**: Check for missing information
- **Consistency**: Maintain consistent style and tone

## 🛠️ Advanced Features

### Multi-Format Output

```bash
# Generate multiple formats
python scripts/generate_readme.py \
  --template docs/README.template.MD \
  --formats "markdown,html,pdf" \
  --output-dir docs/generated/

# Custom styling
python scripts/generate_readme.py \
  --template docs/README.template.MD \
  --format html \
  --style-sheet docs/styles/custom.css \
  --output docs/generated/README.html
```

### Internationalization

```bash
# Generate localized documentation
python scripts/generate_readme.py \
  --template docs/README.template.MD \
  --language en \
  --output README.en.MD

python scripts/generate_readme.py \
  --template docs/README.template.MD \
  --language de \
  --output README.de.MD
```

### Integration Capabilities

#### CMS Integration

```python
# Export to content management system
from scripts.cms_export import CMSExporter

exporter = CMSExporter(
    cms_type='confluence',
    base_url='https://company.atlassian.net',
    api_token=os.environ['CONFLUENCE_TOKEN']
)

exporter.export_documentation(
    source_dir='docs/',
    space_key='AUTOMATION',
    parent_page='Templates'
)
```

#### Static Site Generation

```bash
# Generate static site
python scripts/generate_site.py \
  --source docs/ \
  --output site/ \
  --theme corporate

# Deploy to GitHub Pages
python scripts/deploy_docs.py \
  --source site/ \
  --repository owner/docs-repo \
  --branch gh-pages
```

## 📈 Analytics and Metrics

### Documentation Metrics

- **Page views**: Track documentation usage
- **Search queries**: Understand user needs
- **Feedback scores**: Measure documentation quality
- **Update frequency**: Monitor content freshness

### Quality Metrics

- **Link health**: Monitor broken links
- **Content age**: Track outdated content
- **Completion rate**: Measure task completion
- **User satisfaction**: Collect user feedback

## 🔧 Troubleshooting

### Common Issues

1. **Template rendering errors**:
   ```bash
   # Check template syntax
   python scripts/validate_templates.py docs/README.template.MD
   
   # Debug variable substitution
   python scripts/generate_readme.py --debug --dry-run
   ```

2. **Missing variables**:
   ```bash
   # List required variables
   python scripts/analyze_template.py docs/README.template.MD
   
   # Validate variable file
   python scripts/validate_variables.py project-vars.json
   ```

3. **Formatting issues**:
   ```bash
   # Lint markdown
   markdownlint docs/**/*.md
   
   # Fix common issues
   markdownlint --fix docs/**/*.md
   ```

### Debug Commands

```bash
# Verbose generation
python scripts/generate_readme.py --verbose --debug

# Template analysis
python scripts/analyze_template.py --template docs/README.template.MD

# Variable validation
python scripts/validate_variables.py --variables project-vars.json
```

## 📚 Resources

### Templates

- [Basic Project Template](templates/basic-project.MD)
- [Enterprise Template](templates/enterprise.MD)
- [API Documentation Template](templates/api-docs.MD)
- [User Guide Template](templates/user-guide.MD)

### Style Guides

- [Markdown Style Guide](style-guides/markdown.md)
- [API Documentation Style](style-guides/api-docs.md)
- [Technical Writing Guide](style-guides/technical-writing.md)

### Tools and Utilities

- [Template Validator](../scripts/validate_templates.py)
- [Documentation Generator](../scripts/generate_readme.py)
- [Link Checker](../scripts/check_links.py)
- [Content Analyzer](../scripts/analyze_content.py)

## 📞 Support

- **Issues**: [GitHub Issues](https://github.com/bauer-group/automation-templates/issues)
- **Documentation**: [Project Wiki](https://github.com/bauer-group/automation-templates/wiki)
- **Style Guide**: [Writing Standards](style-guides/README.md)
- **Templates**: [Template Gallery](templates/README.md)

---

*Professional documentation system for enterprise automation workflows. Maintained by the Bauer Group Development Team.*
