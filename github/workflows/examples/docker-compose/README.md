# Docker Compose Release Examples

This directory contains example workflows for projects that use Docker Compose without building custom images. These workflows validate configuration and create semantic releases.

## Use Cases

- **Deployment Configurations**: Projects that deploy pre-built images via Docker Compose
- **Development Environments**: Local development setups with docker-compose.yml
- **Infrastructure as Code**: Docker Compose based infrastructure definitions
- **Multi-Service Orchestration**: Projects coordinating multiple containers

## Examples

| Example | Description |
|---------|-------------|
| [simple-release.yml](simple-release.yml) | Basic validation and release |
| [comprehensive-release.yml](comprehensive-release.yml) | Full validation with all options |
| [multi-environment.yml](multi-environment.yml) | Multiple compose files for different environments |

## Quick Start

Copy one of the examples to your repository's `.github/workflows/` directory and customize as needed.

## Related Documentation

- [modules-validate-compose.yml](../../../../docs/workflows/modules-validate-compose.md)
- [modules-validate-shellscript.yml](../../../../docs/workflows/modules-validate-shellscript.md)
- [modules-semantic-release.yml](../../../../docs/workflows/modules-semantic-release.md)
