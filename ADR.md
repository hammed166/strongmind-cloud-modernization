
# Architecture Decision Record: Identity Server Migration (Azure → AWS)

## Architectural Diagram

```mermaid
graph TD
  A[Azure App Service]
  B[ECS Fargate]
  C[RDS SQL Server]
  D[Secrets Manager]
  E[IAM Identity Center (AWS Identity Federation)]
  F[Route 53]
  G[ALB]

  F -- Weighted Routing --> A
  F -- Weighted Routing --> G
  G --> B
  B --> C
  B --> D
  B --> E
```

## Status
Draft – Pending Approval (as of 13 April 2026)

## Context
The Identity Server is a legacy .NET application currently hosted on Azure App Service, using Azure SQL Database for persistence, Azure Key Vault for secrets, and Azure Entra ID (Azure Active Directory) for directory services. The system handles approximately 400 authentication requests per minute at baseline. The migration is driven by:
- Cost optimization and vendor consolidation
- Need for deeper integration with AWS-native workloads
- Desire to leverage AWS managed services for scalability, security, and operational efficiency

## Decision
We will migrate the Identity Server to AWS, targeting a containerized deployment on ECS Fargate, with supporting AWS managed services for database, secrets, and directory. This approach was chosen for its balance of operational simplicity, scalability, and alignment with AWS best practices. The migration will be executed with a focus on zero downtime, robust rollback, and data integrity.

## Trade-off Analysis
| Option | Pros | Cons |
|--------|------|------|
| Remain on Azure | No migration risk, familiar stack | Higher cost, less AWS integration, missed AWS features |
| Lift-and-shift to EC2 | Full control, easy for legacy apps | Higher ops overhead, less scalable, more patching |
| ECS Fargate (chosen) | Managed, scalable, lower ops, integrates with AWS services | Requires containerization, learning curve, dual-cloud cost during migration |

Key trade-offs resolved:
- Chose ECS Fargate for managed scaling and lower operational burden, accepting the need to containerize the legacy app.
- Accepted temporary dual-cloud costs for a safer, gradual cutover and rollback capability.

## Migration Architecture
- **ECS Fargate Task Definition:**
	- Start with 1 vCPU / 2GB RAM per task, autoscaling enabled based on CPU/memory and request throughput.
	- Docker images built via CI/CD and stored in Amazon ECR.
	- Environment variables and secrets injected at runtime from AWS Secrets Manager.
	- IAM roles assigned to tasks for least-privilege access to AWS resources (e.g., RDS, Secrets Manager, CloudWatch).
- **RDS for SQL Server:**
	- Multi-AZ deployment for high availability.
	- Instance class sized to match or exceed current Azure SQL performance.
	- Automated backups, enhanced monitoring, and encryption at rest enabled.
- **Secrets Manager:**
	- All application secrets and connection strings migrated from Azure Key Vault.
	- Enable automatic rotation for database credentials.
- **VPC/Networking:**
	- ECS services deployed in private subnets within a dedicated VPC.
	- Application Load Balancer (ALB) in public subnets for ingress.
	- Security groups restrict access to only required ports and sources.
- **IAM & Directory:**
	- Use AWS IAM Identity Center (formerly AWS SSO) as the equivalent to Azure Entra ID for user/group management and SSO.
	- Update .NET app configuration to authenticate against AWS IAM Identity Center endpoints.


## Traffic Cutover Strategy
- Use Amazon Route 53 weighted routing to gradually shift traffic from Azure App Service to the new ECS Fargate service.
- Initial state: 100% traffic to Azure, 0% to AWS.
- Gradually increase AWS weight (e.g., 10% increments) while monitoring error rates, latency, and authentication success.
- Blue/green deployment supported via ALB target groups and CodeDeploy.

**Rollback Triggers:**
- Error rate >1% sustained for 5 minutes
- Latency >2x baseline for 5 minutes
- Authentication failures >0.5% of requests
- Any critical alert from CloudWatch or manual SRE intervention

**Rollback Procedure:**
1. Immediately shift Route 53 weights back to 100% Azure
2. Scale down ECS tasks to minimum
3. Investigate root cause, validate Azure is healthy, and communicate status to stakeholders

## Observability Plan
- **Metrics:**
  - Application: request rate, error rate, latency, authentication success/failure
  - Infrastructure: ECS CPU/memory, RDS connections/IO, Secrets Manager access, IAM auth events
- **Logging:**
  - Centralized in CloudWatch Logs; structured logging for traceability
- **Tracing:**
  - Enable AWS X-Ray for distributed tracing across ECS, RDS, and external dependencies
- **Alerting:**
  - CloudWatch Alarms for SLO breaches, resource exhaustion, and security events
- **Dashboards:**
  - CloudWatch dashboards for real-time and historical visibility
- **Runbooks:**
  - Documented runbooks for common failure scenarios, rollback, and escalation


## Database Migration Plan
- Use AWS Database Migration Service (DMS) to replicate data from Azure SQL Database to RDS for SQL Server.
- Initial full load followed by ongoing change data capture (CDC) to keep RDS in sync.
- Data validation: Run row counts, checksums, and targeted queries to compare source and target.
- Cutover:
  - Schedule a brief maintenance window for final sync and switchover.
  - Pause writes on Azure SQL, allow DMS to catch up, then point ECS app to RDS.
- Minimal downtime: Target <5 minutes of read-only mode during cutover.


## Risk Register
| Risk | Likelihood | Impact | Mitigation |
|------|------------|--------|------------|
| Data inconsistency during migration | Medium | High | Use DMS CDC, validate with checksums, keep Azure SQL as source of truth until cutover |
| Authentication failures post-migration | Low | High | Gradual traffic shift, monitor auth success, retain Azure as fallback |
| Under-provisioned ECS tasks | Medium | Medium | Start with conservative sizing, enable autoscaling, monitor CloudWatch metrics |
| Misconfigured IAM roles or security groups | Low | Medium | Principle of least privilege, peer review, automated tests |


## Definition of Done
- 100% of production traffic is served by AWS ECS Fargate service
- RDS for SQL Server is the sole system of record, with validated data integrity
- All secrets and configuration are managed in AWS Secrets Manager
- Directory integration is fully functional with AWS IAM Identity Center
- No SLO breaches (error rate, latency, auth failures) for 2 weeks post-cutover
- Azure resources decommissioned
