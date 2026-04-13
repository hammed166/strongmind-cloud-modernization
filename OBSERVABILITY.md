# Observability Plan: Identity Server on AWS ECS

## Service Level Objectives (SLOs) & Indicators (SLIs)

**SLO 1: Availability**
- Target: 99.9% monthly availability
- SLI: Percentage of successful HTTP 2xx/3xx responses over total requests (measured at ALB/ECS)
- Breach: If availability drops below 99.9% in a month, trigger a SEV-1 incident, page on-call, and initiate postmortem review.

**SLO 2: Latency**
- Target: p95 response time < 300ms (measured at ALB)
- SLI: 95th percentile of HTTP response times
- Breach: If p95 exceeds 300ms for >10 consecutive minutes, trigger a SEV-2 alert and investigate for bottlenecks or downstream issues.

## Metrics & Alarms

### ECS Task Health
- **ECS Service Desired vs. Running Tasks**
  - Alarm: Running < Desired for 5 min (SEV-1, page on-call)
- **Task CPU Utilization**
  - Alarm: >80% for 10 min (SEV-2, notify)
- **Task Memory Utilization**
  - Alarm: >80% for 10 min (SEV-2, notify)

### RDS (PostgreSQL) Performance
- **CPU Utilization**
  - Alarm: >80% for 10 min (SEV-2, notify)
- **Free Storage Space**
  - Alarm: <10% free (SEV-1, page)
- **Database Connections**
  - Alarm: >90% of max_connections (SEV-2, notify)

### Application-Level Signals
- **HTTP 5xx Error Rate**
  - Alarm: >1% of requests for 5 min (SEV-1, page)
- **Queue Backlog (if using Sidekiq/ActiveJob)**
  - Alarm: >1000 jobs pending (SEV-2, notify)
- **Custom Business Metrics**
  - e.g., Auth failures, login attempts, etc. (set thresholds as needed)

## Distributed Tracing (AWS X-Ray)
- Enable X-Ray SDK in the .NET Identity Server and configure ECS task definition with X-Ray daemon sidecar.
- Instrument HTTP handlers, database calls, and external service calls.
- In traces, look for:
  - Spans with high duration (latency bottlenecks)
  - Errors or faults in specific segments (e.g., DB, external API)
  - Trace breaks or missing segments (instrumentation gaps)
  - Correlate trace IDs with logs for deep debugging

## Log Strategy
- **Centralized Logging:**
  - All app logs sent to CloudWatch Log Group: `/ecs/identity-server-${ENV}`
  - Retention: 30 days for prod, 7 days for dev/uat
  - Use structured JSON logs for easy querying
- **CloudWatch Insights Query Example:**
  - Find all requests with latency > 1s and 5xx errors in the last hour:
    ```
    fields @timestamp, @message, status, latency
    | filter status >= 500 and latency > 1000
    | sort @timestamp desc
    | limit 50
    ```

## Alerting Pipeline
- **CloudWatch Alarms** trigger SNS topics by severity (SEV-1, SEV-2)
- **SNS** topics integrated with Jira Operations (OpsGenie)
- **OpsGenie** routes:
  - SEV-1: Page on-call engineer immediately (SMS/call)
  - SEV-2: Notify on-call via app/email, escalate if unacknowledged
- **Alert Documentation:**
  - Each alarm includes runbook link and troubleshooting steps
  - Alerts auto-close when alarm clears

---

_This document is a living reference. Update SLOs, metrics, and runbooks as the system evolves._
