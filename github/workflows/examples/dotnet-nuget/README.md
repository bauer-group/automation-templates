# .NET NuGet Publishing Examples

Example workflows for building and publishing .NET libraries to NuGet.org and GitHub Packages.

## Examples

### [basic-publish.yml](basic-publish.yml)

Simple workflow for publishing a single .NET library.

```yaml
uses: bauer-group/automation-templates/.github/workflows/dotnet-publish-library.yml@main
with:
  project-path: 'src/MyLibrary.csproj'
  push-to-github: true
```

### [multi-target.yml](multi-target.yml)

Build for multiple .NET versions (net8.0, net9.0, net10.0).

### [signed-package.yml](signed-package.yml)

Assembly signing with SNK (Strong Name Key) for enterprise libraries.

### [release-workflow.yml](release-workflow.yml)

Full CI/CD pipeline with semantic-release integration:
1. Validate on PR
2. Create semantic release on main
3. Publish to NuGet.org and GitHub Packages

### [windows-desktop.yml](windows-desktop.yml)

Windows-specific builds for WPF/WinForms libraries using platform matrix.

## Features

All examples support:

- Multi-package solutions (all packages published)
- Symbol packages (.snupkg)
- Deterministic builds
- Code coverage collection
- Test auto-discovery

## Outputs

Access package information in subsequent jobs:

```yaml
post-publish:
  needs: publish
  steps:
    - run: |
        echo "Version: ${{ needs.publish.outputs.version }}"
        echo "Package Count: ${{ needs.publish.outputs.package-count }}"
        echo "Packages: ${{ needs.publish.outputs.package-names }}"
```

## Related

- [dotnet-publish-library.yml](../../../../.github/workflows/dotnet-publish-library.yml) - Reusable workflow
- [dotnet-nuget action](../../../../.github/actions/dotnet-nuget/) - Composite action
- [Documentation](../../../../docs/workflows/dotnet-publish-library.md) - Full documentation
