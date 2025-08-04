# Disaster Recovery Strategy

## Overview
This document outlines the disaster recovery (DR) strategy for our multi-region microservices platform on Oracle Cloud Infrastructure (OCI).

## Recovery Objectives

### Recovery Point Objective (RPO)
- **Primary Services**: 5 minutes
- **Database Services**: 1 minute
- **Configuration Data**: 0 minutes (real-time replication)
- **User Sessions**: 0 minutes (session replication)

### Recovery Time Objective (RTO)
- **Critical Services**: 2 minutes
- **Non-Critical Services**: 5 minutes
- **Full Platform Recovery**: 15 minutes
- **Database Failover**: 30 seconds

## Multi-Region Architecture

### Primary Region (Frankfurt)
- **Purpose**: Primary production environment
- **Services**: All microservices, primary databases
- **Load**: 70% of traffic
- **Backup Strategy**: Real-time replication to secondary

### Secondary Region (Jeddah)
- **Purpose**: Disaster recovery and load balancing
- **Services**: Standby microservices, replicated databases
- **Load**: 30% of traffic
- **Backup Strategy**: Continuous replication from primary

## Failover Strategy

### Automatic Failover Scenarios

#### 1. Service-Level Failover
```yaml
# Triggered by health check failures
conditions:
  - service_health_check_fails: 3 consecutive times
  - response_time_p95 > 500ms for 2 minutes
  - error_rate > 10% for 1 minute

actions:
  - route_traffic_to_secondary_region: 100%
  - scale_up_secondary_services: 2x
  - notify_ops_team: immediate
```

#### 2. Database Failover
```yaml
# Triggered by database connectivity issues
conditions:
  - mysql_connection_fails: 30 seconds
  - replication_lag > 60 seconds
  - primary_db_down: 1 minute

actions:
  - promote_secondary_mysql: immediate
  - update_connection_strings: automatic
  - notify_dba_team: immediate
```

#### 3. Region-Level Failover
```yaml
# Triggered by regional outages
conditions:
  - region_health_check_fails: 5 minutes
  - load_balancer_unhealthy: 2 minutes
  - api_gateway_unavailable: 1 minute

actions:
  - activate_secondary_region: full
  - update_dns_records: automatic
  - scale_secondary_region: 3x capacity
```

### Manual Failover Procedures

#### Step 1: Assessment
1. **Verify Primary Region Status**
   ```bash
   # Check region health
   curl -f https://primary-region.health.com/status
   
   # Check database connectivity
   mysql -h primary-db -u admin -p -e "SELECT 1"
   
   # Check load balancer status
   oci lb backend-health-checker get --load-balancer-id $LB_ID
   ```

2. **Verify Secondary Region Readiness**
   ```bash
   # Check secondary region capacity
   kubectl get nodes -o wide
   
   # Check database replication lag
   mysql -h secondary-db -u admin -p -e "SHOW SLAVE STATUS"
   
   # Check service readiness
   kubectl get pods --all-namespaces
   ```

#### Step 2: Traffic Routing
1. **Update DNS Records**
   ```bash
   # Update primary DNS to point to secondary region
   oci dns record update \
     --zone-name "myapp.com" \
     --domain "api.myapp.com" \
     --rtype "A" \
     --rdata "SECONDARY_REGION_IP"
   ```

2. **Update Load Balancer Configuration**
   ```bash
   # Disable primary region backends
   oci lb backend update \
     --load-balancer-id $LB_ID \
     --backend-set-name "primary-backend" \
     --backends '[{"ipAddress": "PRIMARY_IP", "port": 8080, "weight": 0}]'
   
   # Enable secondary region backends
   oci lb backend update \
     --load-balancer-id $LB_ID \
     --backend-set-name "secondary-backend" \
     --backends '[{"ipAddress": "SECONDARY_IP", "port": 8080, "weight": 100}]'
   ```

#### Step 3: Database Failover
1. **Promote Secondary Database**
   ```bash
   # Stop replication on secondary
   mysql -h secondary-db -u admin -p -e "STOP SLAVE"
   
   # Promote to primary
   mysql -h secondary-db -u admin -p -e "RESET SLAVE ALL"
   ```

2. **Update Application Configuration**
   ```bash
   # Update database connection strings
   kubectl patch configmap app-config \
     --patch '{"data":{"DB_HOST":"secondary-db"}}'
   
   # Restart applications
   kubectl rollout restart deployment/microservice
   ```

#### Step 4: Verification
1. **Health Checks**
   ```bash
   # Verify all services are healthy
   curl -f https://api.myapp.com/health
   
   # Check database connectivity
   curl -f https://api.myapp.com/db-health
   
   # Verify metrics collection
   curl -f https://prometheus.myapp.com/-/healthy
   ```

2. **Performance Monitoring**
   ```bash
   # Monitor response times
   curl -s https://api.myapp.com/metrics | grep response_time_p95
   
   # Monitor error rates
   curl -s https://api.myapp.com/metrics | grep error_rate
   ```

## Backup and Recovery

### Database Backup Strategy
```yaml
# MySQL Backup Configuration
backup_schedule:
  full_backup: "daily at 02:00 UTC"
  incremental_backup: "every 4 hours"
  retention:
    full_backups: "30 days"
    incremental_backups: "7 days"

backup_storage:
  primary: "OCI Object Storage"
  secondary: "Cross-region replication"
  encryption: "AES-256"
```

### Application Data Backup
```yaml
# Application Configuration Backup
config_backup:
  schedule: "every 6 hours"
  storage: "OCI Object Storage"
  retention: "90 days"

# User Data Backup
user_data_backup:
  schedule: "real-time replication"
  storage: "Cross-region MySQL replication"
  retention: "indefinite"
```

## Testing Procedures

### Monthly DR Tests
1. **Service Failover Test**
   - Simulate service failure in primary region
   - Verify automatic failover to secondary
   - Measure RTO and RPO compliance

2. **Database Failover Test**
   - Simulate primary database failure
   - Test secondary database promotion
   - Verify data consistency

3. **Full Region Failover Test**
   - Simulate complete regional outage
   - Test full failover to secondary region
   - Verify all services operational

### Quarterly DR Drills
1. **Communication Test**
   - Test incident response procedures
   - Verify stakeholder notifications
   - Test escalation procedures

2. **Recovery Time Validation**
   - Measure actual RTO vs objectives
   - Identify bottlenecks
   - Update procedures as needed

## Monitoring and Alerting

### DR-Specific Alerts
```yaml
# Cross-Region Replication Alerts
alerts:
  - name: "CrossRegionReplicationLag"
    condition: "replication_lag > 60 seconds"
    severity: "critical"
    action: "notify_dba_team"
  
  - name: "SecondaryRegionCapacity"
    condition: "secondary_region_cpu > 80%"
    severity: "warning"
    action: "scale_secondary_region"
  
  - name: "FailoverTriggered"
    condition: "failover_activated = true"
    severity: "critical"
    action: "notify_management_team"
```

### Health Check Endpoints
```yaml
# DR Health Check Endpoints
health_checks:
  - endpoint: "/health/dr-status"
    checks:
      - "cross_region_connectivity"
      - "database_replication_status"
      - "service_readiness"
  
  - endpoint: "/health/failover-readiness"
    checks:
      - "secondary_region_capacity"
      - "database_backup_status"
      - "dns_configuration"
```

## Recovery Procedures

### Post-Failover Actions
1. **Documentation**
   - Record failover timestamp
   - Document root cause analysis
   - Update runbooks

2. **Monitoring**
   - Monitor service performance
   - Track error rates
   - Monitor resource utilization

3. **Communication**
   - Notify stakeholders
   - Update status page
   - Communicate to customers

### Recovery to Primary
1. **Health Verification**
   - Verify primary region stability
   - Confirm all services operational
   - Validate performance metrics

2. **Gradual Traffic Migration**
   - Start with 10% traffic to primary
   - Monitor for 30 minutes
   - Gradually increase to 100%

3. **Database Synchronization**
   - Verify replication lag < 10 seconds
   - Promote primary database
   - Update connection strings

## Success Metrics

### RPO Compliance
- **Target**: 100% compliance
- **Measurement**: Monthly DR tests
- **Reporting**: Quarterly reviews

### RTO Compliance
- **Target**: 95% compliance
- **Measurement**: Actual failover times
- **Reporting**: Monthly reviews

### Recovery Success Rate
- **Target**: 100% successful recoveries
- **Measurement**: DR test results
- **Reporting**: Quarterly reviews 