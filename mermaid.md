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

baseline:
``` mermaid
flowchart LR
  U[Users] --> LB[LB/Ingress]
  LB --> K8s[Kubernetes]
  K8s --> APP[App]
  APP --> PG[(PostgreSQL)]
```

HA:
``` mermaid
flowchart LR
  U[Users]
  VIP[VIP / Load Balancer]
  K8s[(K8s Cluster)]
  APP[App - multiple replicas]
  PG1[(PostgreSQL Primary)]
  PG2[(PostgreSQL Sync Standby)]

  U --> VIP --> K8s --> APP --> PG1
  PG1 --- PG2
```
DR:

``` mermaid
flowchart LR
  U[Users]
  DNS[DNS / GSLB]

  subgraph SiteA [Active DC]
    AAPP[App on K8s]
    APG[(PG Primary)]
    AAPP --> APG
  end

  subgraph SiteB [DR DC]
    BAPP[App on K8s paused]
    BPG[(PG Standby)]
    BAPP --> BPG
  end

  U --> DNS
  DNS --> SiteA
  DNS --> SiteB
  APG -.-> BPG
```
