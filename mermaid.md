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

## baseline:

### Baseline — подробнее: компоненты и бэкапы
``` mermaid
flowchart LR
  U[Users]
  LB[Load Balancer or Ingress]
  U --> LB

  subgraph K8s Cluster
    IN[Ingress Controller 2 replicas]
    SVC[Service layer]
    APP1[App pod 1]
    APP2[App pod 2]
    JOBBKP[K8s backup job]
    MON[Monitoring Prometheus Alertmanager]
    LOG[Logging Loki]
    CSI[CSI storage simple]
    LB --> IN --> SVC --> APP1
    SVC --> APP2
    APP1 --- CSI
    APP2 --- CSI
    MON --- APP1
    LOG --- APP1
  end

  subgraph Database
    PG[PostgreSQL single]
    DBDUMP[Logical dump job]
    BASEBKP[Physical basebackup job]
    WAL[WAL archive dir]
  end

  APP1 --> PG
  APP2 --> PG

  %% backup flows
  JOBBKP -. export manifests .-> BKPK8S[K8s backups storage]
  DBDUMP -. pg dump .-> BKPPG[DB backups storage]
  BASEBKP -. basebackup .-> BKPPG
  PG -. archive wal .-> WAL
```
### Baseline — поток восстановления

``` mermaid
flowchart LR
  BKPK8S[K8s backups storage] --> RESTK8S[Apply manifests]
  BKPPG[DB backups storage] --> RESTDB[Restore from dump]
  WAL[WAL archive dir] --> RESTDB

  RESTK8S --> K8sReady[K8s objects created]
  RESTDB --> DBReady[Database restored]

  K8sReady --> APPStart[App rollout]
  DBReady --> APPStart
  APPStart --> OK[Smoke tests and go live]
  ```

### brief
``` mermaid
flowchart LR
  U[Users] --> LB[LB/Ingress]
  LB --> K8s[Kubernetes]
  K8s --> APP[App]
  APP --> PG[(PostgreSQL)]
```

## HA:

### HA в одном ЦОД — подробнее: контроль плейн, реплики PG, отказ:

``` mermaid
flowchart TB
  U[Users] --> VIP[VIP or External LB]

  subgraph Control Plane
    CP1[Control plane node 1]
    CP2[Control plane node 2]
    CP3[Control plane node 3]
    ETCD[Etcd quorum 3 nodes]
    CP1 --- ETCD
    CP2 --- ETCD
    CP3 --- ETCD
  end

  subgraph Workers
    W1[Worker node A]
    W2[Worker node B]
    W3[Worker node C]
    PDB[Pod disruption budget]
    ANTI[Pod anti affinity rules]
  end

  subgraph Apps
    IN[Ingress Controller 2 replicas]
    API[Backend deployment 3 replicas]
    UI[Frontend deployment 2 replicas]
    MON[Monitoring]
    LOG[Logging]
    VIP --> IN
    IN --> API
    IN --> UI
    MON --- API
    LOG --- API
  end

  subgraph Storage
    CSI[CSI with replication 3 copies]
  end

  subgraph PostgreSQL
    PG1[Primary]
    PG2[Sync standby]
    PATR[Patroni synchronous mode]
    PG1 --- PG2
    PATR --- PG1
    PATR --- PG2
  end

  API --> PG1
  UI --> API
  API --- CSI

  %% failure handling
  FAIL1[Worker down] -. pods rescheduled .-> API
  FAIL2[Primary PG down] -. automatic failover .-> PG2
  FAIL3[CP node down] -. etcd quorum ok .-> ETCD

  %% backups
  BKPK8S[K8s backups] -.-> RESTK8S[restore ready]
  BKPDB[DB backups] -.-> RESTDB[restore ready]
```
### HA в одном ЦОД — зоны отказа и политика размещения:

```mermaid
flowchart LR
  subgraph Zone A
    WA[Worker A]
    PODA1[App pod]
    PODA2[Ingress pod]
  end

  subgraph Zone B
    WB[Worker B]
    PODB1[App pod]
    PODB2[Ingress pod]
  end

  subgraph Zone C
    WC[Worker C]
    PODC1[App pod]
    PODC2[Ingress pod]
  end

  PDB[Pod disruption budget min available 2] --- PODA1
  PDB --- PODB1
  PDB --- PODC1

  AntiAffinity[Anti affinity spread across zones] --- PODA1
  AntiAffinity --- PODB1
  AntiAffinity --- PODC1

  LB[VIP or External LB] --> PODA2
  LB --> PODB2
  LB --> PODC2

  PG1[PostgreSQL primary Zone A] --- PG2[Sync standby Zone B]
  APP[Service] --> PG1
  APP --> PG2

```

### brief
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

## DR:

### DR два ЦОДа — подробнее: трафик, GitOps, репликация:

```mermaid
flowchart LR
  U[Users] --> DNS[DNS or GSLB]

  subgraph Site A Active DC
    AIN[Ingress]
    AAPP[App on K8s]
    APG[Postgres primary]
    AGIT[ArgoCD sync enabled]
    AOBJ[Object storage backups]
    AIN --> AAPP --> APG
  end

  subgraph Site B DR DC
    BIN[Ingress]
    BAPP[App on K8s paused]
    BPG[Postgres standby]
    BGIT[ArgoCD sync paused]
    BOBJ[Object storage backups]
    BIN --> BAPP --> BPG
  end

  DNS --> AIN
  DNS --> BIN

  APG -. async wal .-> BPG
  AOBJ -. replicate .-> BOBJ
  AGIT -. git pull .-> AAPP
  BGIT -. git pull paused .-> BAPP

```

### DR два ЦОДа — упорядоченный фейловер:
```mermaid
flowchart TB
  S1[Detect incident at Site A] --> S2[Stop writes at Site A]
  S2 --> S3[Ensure latest wal shipped to Site B]
  S3 --> S4[Promote Postgres at Site B]
  S4 --> S5[Unpause GitOps sync at Site B]
  S5 --> S6[Scale up apps at Site B]
  S6 --> S7[Switch DNS or GSLB to Site B]
  S7 --> S8[Run smoke tests and open traffic]
  S8 --> DONE[Service restored from DR]

```

### brief
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
