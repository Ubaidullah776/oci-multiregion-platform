# Deployment Procedures Runbook

## Overview
This runbook provides step-by-step procedures for deploying the multi-region microservices platform on OCI.

## Prerequisites
- OCI CLI configured with appropriate permissions
- Terraform installed (v1.5.0+)
- kubectl configured for OKE clusters
- ArgoCD CLI installed
- GitHub access with repository permissions

## 1. Initial Infrastructure Deployment

### 1.1 Terraform Infrastructure Setup

```bash
# Navigate to infrastructure directory
cd infra/terraform/

# Initialize Terraform
terraform init

# Plan the deployment
terraform plan -var-file="production.tfvars"

# Apply infrastructure
terraform apply -var-file="production.tfvars" -auto-approve
```

### 1.2 Verify Infrastructure Components

```bash
# Verify OKE clusters
oci container-engine cluster list --compartment-id $COMPARTMENT_ID

# Verify load balancers
oci lb load-balancer list --compartment-id $COMPARTMENT_ID

# Verify databases
oci mysql db-system list --compartment-id $COMPARTMENT_ID
```

### 1.3 Configure kubectl for OKE

```bash
# Primary region (Frankfurt)
oci ce cluster create-kubeconfig --cluster-id $PRIMARY_CLUSTER_ID --file ~/.kube/config-frankfurt

# Secondary region (Jeddah)
oci ce cluster create-kubeconfig --cluster-id $SECONDARY_CLUSTER_ID --file ~/.kube/config-jeddah

# Set context
kubectl config use-context $PRIMARY_CLUSTER_ID
```

## 2. ArgoCD Setup and Configuration

### 2.1 Install ArgoCD

```bash
# Create namespace
kubectl create namespace argocd

# Install ArgoCD
kubectl apply -n argocd -f https://raw.githubusercontent.com/argoproj/argo-cd/stable/manifests/install.yaml

# Wait for ArgoCD to be ready
kubectl wait --for=condition=ready pod -l app.kubernetes.io/name=argocd-server -n argocd --timeout=300s
```

### 2.2 Configure ArgoCD Applications

```bash
# Apply ArgoCD applications
kubectl apply -f argo/apps/springboot-app.yaml
kubectl apply -f argo/apps/monitoring-stack.yaml
kubectl apply -f argo/apps/infrastructure.yaml
```

### 2.3 Verify ArgoCD Sync

```bash
# Check application status
argocd app list

# Sync applications if needed
argocd app sync springboot-app
argocd app sync monitoring-stack
```

## 3. Monitoring Stack Deployment

### 3.1 Deploy Prometheus and Grafana

```bash
# Apply monitoring stack
kubectl apply -f monitoring/prometheus-grafana/

# Verify monitoring pods
kubectl get pods -n monitoring

# Port forward to access Grafana
kubectl port-forward svc/grafana 3000:3000 -n monitoring
```

### 3.2 Configure Dashboards and Alerts

```bash
# Import dashboards
kubectl apply -f monitoring/prometheus-grafana/dashboards/

# Apply alerting rules
kubectl apply -f monitoring/prometheus-grafana/alerts.yml
```

## 4. Database Setup and Migration

### 4.1 Initialize Databases

```bash
# Connect to MySQL primary
mysql -h $MYSQL_PRIMARY_HOST -u admin -p

# Run initialization script
source scripts/init.sql
```

### 4.2 Verify Database Replication

```bash
# Check primary status
mysql -h $MYSQL_PRIMARY_HOST -u admin -p -e "SHOW MASTER STATUS;"

# Check secondary status
mysql -h $MYSQL_SECONDARY_HOST -u admin -p -e "SHOW SLAVE STATUS;"
```

## 5. Application Deployment

### 5.1 Deploy Microservices

```bash
# Deploy using Helm
helm install microservices helm/microservice/ -n microservices

# Verify deployment
kubectl get pods -n microservices
kubectl get services -n microservices
```

### 5.2 Verify Application Health

```bash
# Check application endpoints
curl -f http://$LOAD_BALANCER_IP/actuator/health

# Check all microservices
for service in user-service order-service payment-service inventory-service notification-service; do
  curl -f http://$LOAD_BALANCER_IP/$service/actuator/health
done
```

## 6. Load Balancer Configuration

### 6.1 Configure Global Load Balancer

```bash
# Update load balancer backend sets
oci lb backend-set update --load-balancer-id $LOAD_BALANCER_ID --backend-set-name "microservices-backend" --health-checker-protocol HTTP --health-checker-port 8080 --health-checker-url-path "/actuator/health"
```

### 6.2 Verify Load Balancer Health

```bash
# Check backend health
oci lb backend-health get --load-balancer-id $LOAD_BALANCER_ID --backend-set-name "microservices-backend"
```

## 7. Security Configuration

### 7.1 Configure WAF Rules

```bash
# Apply WAF policy
oci waas waas-policy update --waas-policy-id $WAF_POLICY_ID --access-rules '[{"action":"ALLOW","criteria":[{"condition":"URL_IS","value":"/api/*"}]}]'
```

### 7.2 Configure API Gateway

```bash
# Deploy API Gateway
oci api-gateway gateway create --compartment-id $COMPARTMENT_ID --display-name "microservices-gateway" --endpoint-type PUBLIC
```

## 8. Post-Deployment Verification

### 8.1 Run Health Checks

```bash
# Comprehensive health check script
./scripts/health-check.sh
```

### 8.2 Performance Testing

```bash
# Run load tests
k6 run scripts/load-test.js
```

### 8.3 Security Scanning

```bash
# Run security scans
./scripts/security-scan.sh
```

## 9. Rollback Procedures

### 9.1 Application Rollback

```bash
# Rollback to previous version
helm rollback microservices 1 -n microservices

# Verify rollback
kubectl get pods -n microservices
```

### 9.2 Infrastructure Rollback

```bash
# Terraform rollback
terraform apply -var-file="production.tfvars" -target=module.oke_primary
```

## 10. Emergency Procedures

### 10.1 Database Failover

```bash
# Promote secondary to primary
mysql -h $MYSQL_SECONDARY_HOST -u admin -p -e "STOP SLAVE; RESET SLAVE ALL;"

# Update application configuration
kubectl patch configmap microservice-config -n microservices -p '{"data":{"db.host":"'$MYSQL_SECONDARY_HOST'"}}'
```

### 10.2 Region Failover

```bash
# Switch to secondary region
kubectl config use-context $SECONDARY_CLUSTER_ID

# Update DNS
oci dns record zone update --zone-name-or-id $ZONE_ID --items '[{"domain":"api.company.com","rtype":"A","ttl":300,"rdata":"'$SECONDARY_LB_IP'"}]'
```

## Troubleshooting

### Common Issues

1. **ArgoCD Sync Failures**
   ```bash
   argocd app logs springboot-app
   kubectl describe application springboot-app -n argocd
   ```

2. **Database Connection Issues**
   ```bash
   kubectl logs -l app=user-service -n microservices
   mysql -h $DB_HOST -u $DB_USER -p -e "SHOW PROCESSLIST;"
   ```

3. **Load Balancer Health Check Failures**
   ```bash
   kubectl describe service user-service -n microservices
   kubectl get endpoints -n microservices
   ```

### Emergency Contacts

- **DevOps Lead**: devops-lead@company.com
- **Database Admin**: db-admin@company.com
- **Security Team**: security@company.com
- **On-Call Engineer**: oncall@company.com

## Documentation

- [Architecture Overview](../architecture-overview.md)
- [Monitoring Guide](../monitoring-guide.md)
- [Security Procedures](../security-procedures.md)
- [Disaster Recovery Plan](../disaster-recovery-strategy.md) 