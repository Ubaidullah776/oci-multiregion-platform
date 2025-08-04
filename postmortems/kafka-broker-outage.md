# 📛 Postmortem: Kafka Broker Outage

**Date:** 2025-08-15  
**Incident ID:** KAFKA-BROKER-2025-0815  
**Severity:** Major  
**Duration:** 28 minutes  
**Regions Affected:** Frankfurt (Primary), Jeddah (Secondary)

---

## 🚨 Summary

On August 15th, 2025, a Kafka broker in the primary region (Frankfurt) experienced an unexpected outage due to high CPU utilization and memory pressure, causing message processing delays and potential data loss for real-time streaming applications. The incident affected order processing and payment notification systems.

---

## 🧠 Root Cause

- **Primary Cause**: Memory pressure on Kafka broker due to sudden spike in message volume
- **Secondary Cause**: Insufficient monitoring of broker resource utilization
- **Contributing Factor**: Network partition between broker nodes during high load

---

## 🔍 Detection

### Initial Detection
- **Prometheus Alert**: `KafkaBrokerHighCPU` triggered at 14:32 UTC
- **Grafana Dashboard**: Broker CPU utilization > 90% for 5 minutes
- **Application Logs**: Message processing delays reported in order service

### Monitoring Queries
```promql
# Kafka Broker CPU Usage
kafka_server_brokertopicmetrics_messagesin_total{broker="kafka-broker-1"}

# Message Processing Rate
rate(kafka_server_brokertopicmetrics_messagesin_total[5m])

# Consumer Lag
kafka_consumer_group_lag_sum{group="order-processing-group"}
```

---

## 🛠️ Mitigation

### Immediate Actions (0-5 minutes)
1. **Scale Up Resources**
   ```bash
   # Increase broker memory allocation
   kubectl patch deployment kafka-broker-1 \
     --patch '{"spec":{"template":{"spec":{"containers":[{"name":"kafka","resources":{"memory":"4Gi"}}]}}}}'
   ```

2. **Restart Affected Broker**
   ```bash
   # Graceful restart of problematic broker
   kubectl rollout restart deployment kafka-broker-1
   ```

### Recovery Actions (5-15 minutes)
3. **Verify Replication Factor**
   ```bash
   # Check topic replication
   kafka-topics.sh --describe --topic orders --bootstrap-server kafka:9092
   ```

4. **Rebalance Partitions**
   ```bash
   # Rebalance to distribute load
   kafka-reassign-partitions.sh --execute --reassignment-json-file reassignment.json
   ```

### Long-term Actions (15-28 minutes)
5. **Scale Consumer Groups**
   ```bash
   # Scale order processing consumers
   kubectl scale deployment order-consumer --replicas=5
   ```

---

## 📊 Impact

| Metric | Before | During | After |
|--------|--------|--------|-------|
| Message Processing Rate | 10,000 msg/sec | 2,000 msg/sec | 12,000 msg/sec |
| Consumer Lag | 0 seconds | 15 minutes | 0 seconds |
| Order Processing Time | 2 seconds | 45 seconds | 1.5 seconds |
| Failed Orders | 0 | 127 | 0 |

---

## ✅ Action Items

| Owner | Task | Priority | Status |
|-------|------|----------|--------|
| Platform Team | Implement auto-scaling for Kafka brokers | High | ☐ Open |
| SRE Team | Add memory pressure alerts | High | ✅ Done |
| DevOps Team | Create Kafka health check endpoints | Medium | ☐ Open |
| Data Team | Implement message replay mechanism | Medium | ☐ Open |

---

## 🧠 Lessons Learned

### What Went Well
- **Quick Detection**: Prometheus alerts triggered within 2 minutes
- **Graceful Recovery**: No data loss during broker restart
- **Team Response**: SRE team responded within 5 minutes

### What Went Wrong
- **Resource Monitoring**: Insufficient memory monitoring thresholds
- **Auto-scaling**: No automatic scaling for sudden load spikes
- **Consumer Lag**: Delayed detection of consumer lag issues

### What to Improve
- **Proactive Monitoring**: Implement predictive scaling based on trends
- **Chaos Testing**: Regular testing of broker failure scenarios
- **Documentation**: Update runbooks with specific recovery procedures

---

## 📈 Metrics

### Performance Metrics
- **Recovery Time**: 28 minutes (Target: < 15 minutes)
- **Data Loss**: 0 messages (Target: 0)
- **Service Impact**: 15 minutes of degraded performance

### Business Impact
- **Orders Affected**: 127 orders delayed
- **Revenue Impact**: Minimal (orders processed after recovery)
- **Customer Impact**: 15-minute delay in order confirmations

---

## 📎 References

- [Kafka Operations Guide](https://kafka.apache.org/documentation/#operations)
- [Internal Runbook: Kafka Broker Recovery](https://git.company.local/runbooks/kafka-recovery)
- [Chaos Testing: Kafka Broker Outage](chaos-testing/kafka-broker-outage.yaml)

---

## 🧪 Recommended Follow-up

1. **Implement Auto-scaling**: Deploy HPA for Kafka brokers
2. **Enhanced Monitoring**: Add memory pressure and consumer lag alerts
3. **Chaos Testing**: Schedule regular Kafka broker failure simulations
4. **Documentation**: Update runbooks with specific recovery procedures

--- 