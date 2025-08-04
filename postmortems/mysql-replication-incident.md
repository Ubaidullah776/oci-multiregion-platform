# 📛 Postmortem: MySQL Replication Failure (Cross-Region)

**Date:** 2025-08-03  
**Incident ID:** DB-REP-2025-0803  
**Severity:** Major  
**Duration:** 43 minutes  
**Regions Affected:** Frankfurt (Primary), Jeddah (Secondary)

---

## 🚨 Summary

On August 3rd, 2025, the MySQL HeatWave replication between the primary database in Frankfurt and the secondary in Jeddah experienced a failure due to a corrupted binary log position after a network packet loss during a failover simulation. Write operations continued in Frankfurt, but the Jeddah replica lagged significantly, posing a risk to RTO/RPO targets.

---

## 🧠 Root Cause

- A transient network interruption caused by a misconfigured route table in OCI led to partial packet drops.
- The replication thread in Jeddah failed to resume due to an inconsistent GTID (Global Transaction ID) state.
- The alert threshold for replication lag (30 seconds) was reached but not escalated due to a missing Prometheus alert route.

---

## 🔍 Detection

- Grafana dashboard showed `Replica Lag > 900s`
- Prometheus query:  




- Application error logs in Jeddah reported stale reads.

---

## 🛠️ Mitigation

- Manually stopped replication in Jeddah
- Used `mysqlbinlog` to extract missing transactions from Frankfurt
- Restored GTID consistency manually
- Restarted replication using a fresh snapshot
- Verified consistency via checksum comparison

---

## 📊 Impact

- Partial read inconsistency in Jeddah region for ~43 minutes
- No data loss
- No impact on write operations in Frankfurt
- CI/CD deployments to Jeddah were paused during incident

---

## ✅ Action Items

| Owner         | Task                                                                 | Status  |
|---------------|----------------------------------------------------------------------|---------|
| DBA Team      | Automate GTID failover detection and re-sync                         | ☐ Open  |
| DevOps Team   | Add Prometheus alert for replication lag > 30s                       | ✅ Done |
| SRE Team      | Add chaos test for binlog corruption and cross-region failover       | ☐ Open  |
| Network Team  | Audit route table changes in inter-region communication              | ✅ Done |
| Platform Team | Enable OCI Event Rule to catch MySQL health degradation              | ✅ Done |

---

## 🧠 Lessons Learned

- Network instability during maintenance can desynchronize GTID replication.
- Lag alerts need to be routed and escalated properly.
- Cross-region replication needs active chaos testing and re-validation.

---

## 📈 Metrics

| Metric                       | Before | During | After |
|-----------------------------|--------|--------|-------|
| Replica Lag (Jeddah)        | 0s     | 960s   | 0s    |
| App Errors (Jeddah)         | 0      | 58     | 0     |
| Recovery Time (RTO)         | -      | 43m    | -     |

---

## 📎 References

- [OCI MySQL HeatWave Docs](https://docs.oracle.com/en/cloud/mysql/)
- [Internal Playbook: MySQL DR Failover](https://git.company.local/runbooks/mysql-dr-failover)
- Incident Timeline: `#incident-db-0803` Slack thread (exported)

---

## 🧪 Recommended Follow-up

- Schedule controlled chaos engineering experiments on MySQL cross-region GTID failover.
- Review Prometheus-Grafana alert handoff workflows.

---