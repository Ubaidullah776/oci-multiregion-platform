# Service Level Objectives (SLOs) and Service Level Indicators (SLIs)

## Overview
This document defines the Service Level Objectives (SLOs) and corresponding Service Level Indicators (SLIs) for our multi-region microservices platform.

## Service Level Objectives (SLOs)

### 1. Availability SLO
**Objective**: 99.9% uptime (8.76 hours of downtime per year)
- **Target**: 99.9% availability
- **Measurement Period**: 30 days rolling window
- **Error Budget**: 0.1% (43.8 minutes per month)

### 2. Latency SLO
**Objective**: 95% of requests complete within 200ms
- **Target**: P95 latency ≤ 200ms
- **Measurement Period**: 5-minute rolling window
- **Error Budget**: 5% of requests can exceed 200ms

### 3. Throughput SLO
**Objective**: Handle 1000 requests per second with 99% success rate
- **Target**: 1000 RPS with 99% success rate
- **Measurement Period**: 1-minute rolling window
- **Error Budget**: 1% of requests can fail

## Service Level Indicators (SLIs)

### 1. Availability SLIs

#### 1.1 HTTP Success Rate
```promql
# SLI: HTTP Success Rate
sum(rate(http_requests_total{status=~"2.."}[5m])) / sum(rate(http_requests_total[5m])) * 100
```
- **Measurement**: Percentage of successful HTTP responses (2xx, 3xx)
- **Target**: ≥ 99.9%
- **Alert Threshold**: < 99.5%

#### 1.2 Service Health Checks
```promql
# SLI: Service Health Status
up{job="springboot-microservice"}
```
- **Measurement**: Service availability (1 = healthy, 0 = unhealthy)
- **Target**: 1 (healthy)
- **Alert Threshold**: 0 (unhealthy)

#### 1.3 Database Connectivity
```promql
# SLI: Database Connection Pool Health
mysql_global_status_threads_connected / mysql_global_variables_max_connections * 100
```
- **Measurement**: Database connection pool utilization
- **Target**: < 80%
- **Alert Threshold**: > 90%

### 2. Latency SLIs

#### 2.1 Response Time P95
```promql
# SLI: 95th Percentile Response Time
histogram_quantile(0.95, sum(rate(http_request_duration_seconds_bucket[5m])) by (le))
```
- **Measurement**: 95th percentile response time
- **Target**: ≤ 200ms
- **Alert Threshold**: > 500ms

#### 2.2 Response Time P99
```promql
# SLI: 99th Percentile Response Time
histogram_quantile(0.99, sum(rate(http_request_duration_seconds_bucket[5m])) by (le))
```
- **Measurement**: 99th percentile response time
- **Target**: ≤ 500ms
- **Alert Threshold**: > 1000ms

#### 2.3 Database Query Latency
```promql
# SLI: Database Query Response Time
mysql_global_status_slow_queries / mysql_global_status_questions * 100
```
- **Measurement**: Percentage of slow database queries
- **Target**: < 1%
- **Alert Threshold**: > 5%

### 3. Throughput SLIs

#### 3.1 Request Rate
```promql
# SLI: Requests Per Second
sum(rate(http_requests_total[1m]))
```
- **Measurement**: Requests per second
- **Target**: ≥ 1000 RPS
- **Alert Threshold**: < 500 RPS

#### 3.2 Error Rate
```promql
# SLI: Error Rate
sum(rate(http_requests_total{status=~"4..|5.."}[5m])) / sum(rate(http_requests_total[5m])) * 100
```
- **Measurement**: Percentage of error responses (4xx, 5xx)
- **Target**: < 1%
- **Alert Threshold**: > 5%

#### 3.3 Database Throughput
```promql
# SLI: Database Operations Per Second
rate(mysql_global_status_questions[1m])
```
- **Measurement**: Database queries per second
- **Target**: Based on application requirements
- **Alert Threshold**: Sudden drops or spikes

## SLO Error Budget Tracking

### Monthly Error Budget Allocation
| SLO | Monthly Budget | Current Usage | Remaining |
|-----|----------------|---------------|-----------|
| Availability | 43.8 minutes | 0 minutes | 43.8 minutes |
| Latency | 5% of requests | 0% | 5% |
| Throughput | 1% of requests | 0% | 1% |

### Error Budget Burn Rate
```promql
# Error Budget Burn Rate for Availability
(1 - (sum(rate(http_requests_total{status=~"2.."}[5m])) / sum(rate(http_requests_total[5m])))) * 100
```

## Alerting Rules

### Critical Alerts (P0)
- Service down (health check fails)
- Database connectivity lost
- Error rate > 10%

### Warning Alerts (P1)
- Response time P95 > 500ms
- Error rate > 5%
- Database connection pool > 90%

### Info Alerts (P2)
- Response time P95 > 200ms
- Error rate > 1%
- High memory usage > 80%

## SLO Dashboard Queries

### Availability Dashboard
```promql
# Overall Availability
(1 - (sum(rate(http_requests_total{status=~"4..|5.."}[30d])) / sum(rate(http_requests_total[30d])))) * 100
```

### Latency Dashboard
```promql
# Response Time Percentiles
histogram_quantile(0.50, sum(rate(http_request_duration_seconds_bucket[5m])) by (le)) as p50,
histogram_quantile(0.95, sum(rate(http_request_duration_seconds_bucket[5m])) by (le)) as p95,
histogram_quantile(0.99, sum(rate(http_request_duration_seconds_bucket[5m])) by (le)) as p99
```

### Throughput Dashboard
```promql
# Request Rate by Endpoint
sum(rate(http_requests_total[5m])) by (uri)
``` 