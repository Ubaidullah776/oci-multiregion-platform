# Incident Response Runbook

## Overview
This runbook provides procedures for responding to incidents in the multi-region microservices platform.

## Incident Severity Levels

### P0 - Critical
- **Service completely down**
- **Data loss or corruption**
- **Security breach**
- **Response Time**: Immediate (within 15 minutes)
- **Escalation**: DevOps Lead + Management

### P1 - High
- **Service degraded (high latency, errors)**
- **Partial functionality loss**
- **Response Time**: 30 minutes
- **Escalation**: DevOps Team

### P2 - Medium
- **Minor functionality issues**
- **Performance degradation**
- **Response Time**: 2 hours
- **Escalation**: On-call Engineer

### P3 - Low
- **Cosmetic issues**
- **Minor bugs**
- **Response Time**: 24 hours
- **Escalation**: Development Team

## Initial Response Procedures

### 1. Incident Detection and Triage

#### 1.1 Alert Assessment
```bash
# Check alert sources
- Prometheus alerts
- Grafana dashboards
- Application logs
- Infrastructure monitoring
- Business metrics
```

#### 1.2 Quick Health Check
```bash
# Check application health
curl -f http://$LOAD_BALANCER_IP/actuator/health

# Check all microservices
for service in user-service order-service payment-service inventory-service notification-service; do
  echo "Checking $service..."
  curl -f http://$LOAD_BALANCER_IP/$service/actuator/health
done

# Check database connectivity
mysql -h $DB_HOST -u $DB_USER -p -e "SELECT 1;"

# Check Kubernetes cluster status
kubectl get nodes
kubectl get pods --all-namespaces
```

#### 1.3 Incident Documentation
```bash
# Create incident ticket
echo "INCIDENT: $(date) - $(hostname)" > incident-$(date +%Y%m%d-%H%M%S).md

# Document initial state
kubectl get pods --all-namespaces -o wide > incident-state-$(date +%Y%m%d-%H%M%S).txt
```

### 2. P0 Critical Incident Response

#### 2.1 Immediate Actions
```bash
# 1. Notify stakeholders
./scripts/notify-critical-incident.sh

# 2. Check if it's a region-wide issue
curl -f http://$SECONDARY_LB_IP/actuator/health

# 3. If primary region is down, initiate failover
if [ $? -ne 0 ]; then
  echo "Primary region down, initiating failover..."
  ./scripts/region-failover.sh
fi
```

#### 2.2 Database Emergency Procedures
```bash
# Check database status
mysql -h $MYSQL_PRIMARY_HOST -u admin -p -e "SHOW MASTER STATUS;"
mysql -h $MYSQL_SECONDARY_HOST -u admin -p -e "SHOW SLAVE STATUS;"

# If primary DB is down, promote secondary
if [ $? -ne 0 ]; then
  echo "Primary database down, promoting secondary..."
  mysql -h $MYSQL_SECONDARY_HOST -u admin -p -e "STOP SLAVE; RESET SLAVE ALL;"
  
  # Update application configuration
  kubectl patch configmap microservice-config -n microservices \
    -p '{"data":{"db.host":"'$MYSQL_SECONDARY_HOST'"}}'
fi
```

#### 2.3 Application Emergency Procedures
```bash
# Check application logs
kubectl logs -l app=user-service -n microservices --tail=100

# Restart problematic pods
kubectl delete pod -l app=user-service -n microservices

# Scale up if needed
kubectl scale deployment user-service --replicas=3 -n microservices
```

### 3. P1 High Priority Incident Response

#### 3.1 Performance Issues
```bash
# Check resource utilization
kubectl top pods -n microservices
kubectl top nodes

# Check application metrics
curl http://$PROMETHEUS_IP:9090/api/v1/query?query=rate(http_server_requests_seconds_count[5m])

# Check database performance
mysql -h $DB_HOST -u $DB_USER -p -e "SHOW PROCESSLIST;"
```

#### 3.2 Scaling Response
```bash
# Scale up microservices
kubectl scale deployment user-service --replicas=5 -n microservices
kubectl scale deployment order-service --replicas=5 -n microservices

# Check if scaling helped
kubectl get hpa -n microservices
```

### 4. P2 Medium Priority Incident Response

#### 4.1 Application Issues
```bash
# Check specific service logs
kubectl logs -l app=payment-service -n microservices --tail=50

# Check service endpoints
kubectl get endpoints -n microservices

# Restart specific service
kubectl rollout restart deployment payment-service -n microservices
```

#### 4.2 Configuration Issues
```bash
# Check ConfigMaps and Secrets
kubectl get configmaps -n microservices
kubectl get secrets -n microservices

# Update configuration if needed
kubectl patch configmap microservice-config -n microservices -p '{"data":{"new.config":"value"}}'
```

## Investigation Procedures

### 1. Log Analysis
```bash
# Collect logs from all services
for service in user-service order-service payment-service inventory-service notification-service; do
  kubectl logs -l app=$service -n microservices --tail=1000 > logs-$service-$(date +%Y%m%d-%H%M%S).log
done

# Check system logs
kubectl logs -n kube-system --tail=100 > system-logs-$(date +%Y%m%d-%H%M%S).log
```

### 2. Metrics Analysis
```bash
# Query Prometheus for metrics
curl -G http://$PROMETHEUS_IP:9090/api/v1/query_range \
  --data-urlencode 'query=rate(http_server_requests_seconds_count[5m])' \
  --data-urlencode 'start='$(date -d '1 hour ago' +%s) \
  --data-urlencode 'end='$(date +%s) \
  --data-urlencode 'step=60' > metrics-$(date +%Y%m%d-%H%M%S).json
```

### 3. Network Analysis
```bash
# Check network connectivity
kubectl exec -it $(kubectl get pods -l app=user-service -n microservices -o jsonpath='{.items[0].metadata.name}') -n microservices -- ping $DB_HOST

# Check DNS resolution
kubectl exec -it $(kubectl get pods -l app=user-service -n microservices -o jsonpath='{.items[0].metadata.name}') -n microservices -- nslookup $DB_HOST
```

## Resolution Procedures

### 1. Application Fixes
```bash
# Deploy hotfix
git checkout hotfix/incident-$(date +%Y%m%d)
# Make changes
git commit -m "Hotfix for incident $(date +%Y%m%d)"
git push origin hotfix/incident-$(date +%Y%m%d)

# Deploy via ArgoCD
argocd app sync springboot-app
```

### 2. Infrastructure Fixes
```bash
# Apply infrastructure changes
cd infra/terraform/
terraform plan -var-file="production.tfvars"
terraform apply -var-file="production.tfvars" -auto-approve
```

### 3. Configuration Updates
```bash
# Update application configuration
kubectl patch configmap microservice-config -n microservices -p '{"data":{"updated.config":"new-value"}}'

# Restart applications to pick up new config
kubectl rollout restart deployment user-service -n microservices
kubectl rollout restart deployment order-service -n microservices
```

## Post-Incident Procedures

### 1. Incident Documentation
```bash
# Create postmortem document
cat > postmortem-$(date +%Y%m%d-%H%M%S).md << EOF
# Postmortem: $(date)

## Incident Summary
- **Date**: $(date)
- **Duration**: [Duration]
- **Severity**: [P0/P1/P2/P3]
- **Services Affected**: [List services]

## Root Cause
[Describe root cause]

## Impact
- **Users Affected**: [Number]
- **Revenue Impact**: [Amount]
- **SLA Impact**: [Details]

## Resolution
[Describe resolution steps]

## Lessons Learned
[Document lessons learned]

## Action Items
- [ ] [Action item 1]
- [ ] [Action item 2]
- [ ] [Action item 3]

## Timeline
- [Time] - Incident detected
- [Time] - Initial response
- [Time] - Root cause identified
- [Time] - Resolution implemented
- [Time] - Service restored
EOF
```

### 2. Follow-up Actions
```bash
# Schedule postmortem meeting
./scripts/schedule-postmortem.sh

# Update monitoring and alerting
./scripts/update-alerts.sh

# Review and update runbooks
./scripts/update-runbooks.sh
```

## Communication Procedures

### 1. Stakeholder Updates
```bash
# Send status updates
./scripts/send-status-update.sh

# Update status page
./scripts/update-status-page.sh
```

### 2. Customer Communication
```bash
# Send customer notifications
./scripts/send-customer-notification.sh
```

## Emergency Contacts

### Primary Contacts
- **DevOps Lead**: devops-lead@company.com
- **On-Call Engineer**: oncall@company.com
- **Database Admin**: db-admin@company.com

### Escalation Contacts
- **CTO**: cto@company.com
- **VP Engineering**: vp-engineering@company.com
- **Security Team**: security@company.com

### External Contacts
- **OCI Support**: [Support ticket number]
- **Third-party Services**: [Contact information]

## Tools and Resources

### Monitoring Tools
- **Prometheus**: http://$PROMETHEUS_IP:9090
- **Grafana**: http://$GRAFANA_IP:3000
- **Jaeger**: http://$JAEGER_IP:16686

### Documentation
- [Architecture Overview](../architecture-overview.md)
- [Deployment Procedures](./deployment-procedures.md)
- [Disaster Recovery Plan](../disaster-recovery-strategy.md)
- [Security Procedures](../security-procedures.md)

### Scripts
- `./scripts/health-check.sh` - Comprehensive health check
- `./scripts/region-failover.sh` - Region failover procedure
- `./scripts/database-failover.sh` - Database failover procedure
- `./scripts/notify-critical-incident.sh` - Critical incident notification 