``` mermaid
flowchart LR
  subgraph Users
    U[Clients]
  end

  subgraph Edge
    LB[Ext LB/VIP]
  end

  subgraph K8s[ Kubernetes Cluster ]
    IN[Ingress Controller]
    SVC[Services]
    APP[App Pods]
    CSI[(CSI Volumes)]
    MON[Monitoring/Alerts]
    LOG[Logging]
  end

  subgraph DB[PostgreSQL]
    PG1[(Primary)]
    PG2[(Standby)]
    WAL[WAL Archive]
  end

  U --> LB --> IN --> SVC --> APP
  APP <---> DB
  APP --- MON
  APP --- LOG
  DB --> WAL
  CSI --- APP
```
