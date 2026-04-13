# strongmind-cloud-modernization

A comprehensive, production-grade reference for cloud migration, DevOps automation, and observability. This repository demonstrates:
- Migration of a legacy .NET Identity Server from Azure to AWS ECS Fargate
- Secure, standardized CI/CD for Ruby on Rails 8 (Ruby 3.3, PostgreSQL)
- Multi-stage, security-focused Docker builds
- End-to-end observability with SLOs, metrics, tracing, and alerting

---

## Overview
This repository demonstrates a production-ready approach for:
- Migrating a .NET Identity Server from Azure to AWS ECS Fargate
- Building and deploying a Ruby on Rails 8 application (Ruby 3.3, PostgreSQL)
- Standardized, secure CI/CD with GitHub Actions
- Lean, secure Docker image for Rails
- Comprehensive observability and alerting

---

## Architecture & Migration
- **See [`ADR.md`](ADR.md)** for the full migration decision record, AWS architecture diagram, and rollback strategy.
- Key highlights:
  - ECS Fargate for compute, RDS for PostgreSQL, AWS Secrets Manager, IAM Identity Center for SSO
  - Gradual DNS cutover with Route 53, automated rollback, and dual-cloud safety

---

## CI/CD Pipeline
- **See [`rails-deploy.yml`](.github/workflows/rails-deploy.yml)** for the standardized workflow.
- Features:
  - Triggers on push to main, any branch, or manual dispatch (with dev/uat/prod selection)
  - CI: Bundler caching, RSpec, Brakeman, multi-platform Docker build & ECR push
  - Deploy: ECS task update, service rollout, automated rollback on failure
  - OIDC for AWS authentication (no static keys)
  - Concurrency control and prod approval via GitHub Environments

---

## Dockerfile
- **See [`Dockerfile`](Dockerfile)** for a multi-stage, production-optimized build.
- Highlights:
  - Uses `ruby:3.3-slim` for compatibility and size
  - Installs only runtime dependencies in final image
  - Precompiles Rails assets, runs as non-root user
  - Healthcheck and production mode by default
  - Comments explain tradeoffs and security choices

---

## Observability
- **See [`OBSERVABILITY.md`](OBSERVABILITY.md)** for the full plan.
- Key points:
  - SLOs: 99.9% availability, p95 latency < 300ms
  - CloudWatch metrics & alarms for ECS, RDS, and app health
  - AWS X-Ray for distributed tracing
  - Centralized, structured logging with CloudWatch Insights queries
  - Alerting pipeline: CloudWatch → SNS → Jira Ops (OpsGenie) → on-call

---

## Quick Start
1. Review ADR.md for migration and architecture context
2. Use rails-deploy.yml as a template for Rails service CI/CD
3. Build images with the provided Dockerfile
4. Follow OBSERVABILITY.md to instrument and monitor your service

---

_This repository is designed for clarity, operational safety, and real-world production use. For questions or improvements, please open an issue or PR._
