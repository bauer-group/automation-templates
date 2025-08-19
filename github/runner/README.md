# GitHub Runner Management

**Self-hosted GitHub Actions runners with enterprise-grade security and scalability**

## 🏗️ Overview

This directory provides production-ready solutions for deploying and managing self-hosted GitHub Actions runners in enterprise environments. All configurations follow security best practices and support high-availability deployments.

## 📦 Components

### Docker Deployment
- **Multi-architecture support**: AMD64, ARM64
- **Container orchestration**: Docker Compose with health checks
- **Auto-scaling**: Dynamic runner registration/deregistration
- **Security hardening**: Non-root containers, minimal attack surface

### Cloud Infrastructure
- **Cloud-init configuration**: Automated VM setup
- **Systemd integration**: Professional service management
- **Auto-updates**: Automated runner and system updates
- **Monitoring**: Built-in health checks and logging

### Management Scripts
- **Installation**: Automated runner deployment
- **Configuration**: Dynamic runner configuration
- **Monitoring**: Health checks and performance metrics
- **Cleanup**: Safe runner decommissioning

## 🚀 Quick Start

### Docker Deployment

```bash
# Clone configuration
git clone https://github.com/bauer-group/automation-templates.git
cd automation-templates/github/runner

# Configure environment
cp .env.example .env
# Edit .env with your GitHub token and settings

# Deploy runners
docker-compose up -d

# Scale runners
docker-compose up -d --scale runner=5
```

### Cloud VM Deployment

```bash
# Use cloud-init for automated setup
cat cloud-init/user-data.yaml | \
  sed 's/YOUR_GITHUB_TOKEN/ghp_your_token_here/' | \
  sed 's/YOUR_ORG_NAME/your-org/' > user-data-configured.yaml

# Deploy on cloud provider with user-data-configured.yaml
```

## 🔧 Configuration

### Environment Variables

```bash
# GitHub Configuration
GITHUB_TOKEN=ghp_xxxxxxxxxxxxxxxxxxxxx    # GitHub PAT with admin:org scope
GITHUB_URL=https://github.com/your-org    # Organization or repository URL
RUNNER_NAME_PREFIX=enterprise-runner      # Runner name prefix
RUNNER_LABELS=self-hosted,linux,X64      # Runner labels

# Runner Configuration
RUNNER_GROUP=default                      # Runner group assignment
RUNNER_WORK_DIR=/tmp/_work               # Work directory
RUNNER_REPLACE_EXISTING=true             # Replace existing runners

# Security Configuration
RUNNER_USER=runner                       # Non-root user
DISABLE_AUTO_UPDATE=false               # Auto-update control
EPHEMERAL=true                          # Ephemeral runners (recommended)
```

### Docker Compose Configuration

```yaml
version: '3.8'

services:
  runner:
    build: .
    environment:
      - GITHUB_TOKEN=${GITHUB_TOKEN}
      - GITHUB_URL=${GITHUB_URL}
      - RUNNER_NAME_PREFIX=${RUNNER_NAME_PREFIX}
      - RUNNER_LABELS=${RUNNER_LABELS}
      - EPHEMERAL=true
    volumes:
      - /var/run/docker.sock:/var/run/docker.sock
    restart: unless-stopped
    deploy:
      replicas: 3
      resources:
        limits:
          cpus: '2.0'
          memory: 4G
```

## 🛡️ Security Features

### Container Security
- **Non-root execution**: Runners execute as unprivileged user
- **Resource limits**: CPU and memory constraints
- **Network isolation**: Restricted network access
- **Secret management**: Secure token handling

### Infrastructure Security
- **Automated updates**: Security patches and runner updates
- **Firewall configuration**: Minimal port exposure
- **Audit logging**: Comprehensive activity logs
- **Access control**: Token-based authentication

### Runtime Security
- **Ephemeral runners**: Fresh environment for each job
- **Workspace isolation**: Isolated work directories
- **Cleanup automation**: Automatic resource cleanup
- **Monitoring**: Real-time security monitoring

## 📊 Monitoring & Management

### Health Checks

```bash
# Check runner status
./scripts/manage.sh status

# View runner logs
docker-compose logs -f runner

# Monitor resource usage
docker stats
```

### Performance Metrics

- **Job execution time**: Average job duration
- **Queue wait time**: Time in queue before execution
- **Resource utilization**: CPU, memory, disk usage
- **Success rate**: Job completion percentage

### Scaling Operations

```bash
# Scale up runners
docker-compose up -d --scale runner=10

# Scale down runners
docker-compose up -d --scale runner=2

# Emergency shutdown
docker-compose down
```

## 🔄 Maintenance

### Automated Updates

The runners are configured for automatic updates:

- **GitHub Actions Runner**: Auto-updates to latest version
- **System packages**: Automated security updates
- **Container images**: Scheduled rebuilds with latest base images

### Manual Operations

```bash
# Update runners
./scripts/manage.sh update

# Restart all runners
./scripts/manage.sh restart

# Clean up old runners
./scripts/manage.sh cleanup

# Backup configuration
./scripts/manage.sh backup
```

## 🏛️ Enterprise Features

### High Availability
- **Multi-zone deployment**: Runners across availability zones
- **Load balancing**: GitHub automatic job distribution
- **Failover**: Automatic runner replacement
- **Backup runners**: Standby capacity for peak loads

### Compliance
- **Audit logging**: Complete audit trail
- **Resource tagging**: Compliance and cost tracking
- **Access controls**: Fine-grained permissions
- **Retention policies**: Log and data retention

### Cost Optimization
- **Auto-scaling**: Dynamic capacity adjustment
- **Spot instances**: Cost-effective cloud instances
- **Scheduling**: Off-hours capacity reduction
- **Resource monitoring**: Usage optimization

## 🚀 Deployment Patterns

### Development Environment

```yaml
# Minimal development setup
version: '3.8'
services:
  runner:
    image: github-runner:latest
    environment:
      - EPHEMERAL=true
      - RUNNER_LABELS=dev,linux
    deploy:
      replicas: 1
```

### Production Environment

```yaml
# Production-grade setup
version: '3.8'
services:
  runner:
    image: github-runner:latest
    environment:
      - EPHEMERAL=true
      - RUNNER_LABELS=prod,linux,X64
      - RUNNER_GROUP=production
    deploy:
      replicas: 5
      resources:
        limits:
          cpus: '4.0'
          memory: 8G
      restart_policy:
        condition: on-failure
        max_attempts: 3
```

## 🔧 Troubleshooting

### Common Issues

1. **Registration failures**: Check GitHub token permissions
2. **Connection issues**: Verify network connectivity
3. **Resource exhaustion**: Monitor CPU/memory usage
4. **Job failures**: Review runner logs

### Debug Commands

```bash
# View runner registration logs
docker-compose logs runner | grep -i registration

# Check runner connectivity
curl -H "Authorization: token $GITHUB_TOKEN" \
     https://api.github.com/orgs/YOUR_ORG/actions/runners

# Test runner performance
./scripts/manage.sh benchmark
```

## 📚 Documentation

- [Installation Guide](./docs/installation.md)
- [Configuration Reference](./docs/configuration.md)
- [Security Best Practices](./docs/security.md)
- [Troubleshooting Guide](./docs/troubleshooting.md)

## 📞 Support

- **Issues**: [GitHub Issues](https://github.com/bauer-group/automation-templates/issues)
- **Enterprise Support**: Contact your GitHub Enterprise administrator
- **Community**: [GitHub Community Discussions](https://github.com/github/docs/discussions)

---

*This runner deployment solution is production-tested and used in enterprise environments worldwide.*
