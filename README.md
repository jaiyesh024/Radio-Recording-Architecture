# Radio Recording Architecture

Infrastructure design for a resilient, continuously running radio recording platform.

The system records audio streams from a dynamic list of radio station URLs, stores the resulting audio segments in object storage, and provides monitoring to detect recording gaps and infrastructure failures.

The design is intended to run continuously (24/7), support multiple radio stations, and scale from tens of stations to 100+ with minimal operational effort.

---

## Architecture Overview

This implementation uses:

- **AWS** as the cloud provider
- **Amazon EKS** for Kubernetes orchestration
- **Terraform** for infrastructure provisioning
- **Amazon S3** for durable audio storage
- **Amazon ECR** for the recorder container image
- **Prometheus / Grafana** for monitoring and alerting
- **Kubernetes Deployments** to provide one recorder workload per radio station
- **Cluster Autoscaler** to automatically increase or decrease Kubernetes node capacity

The recording application itself is assumed to be a pre-built binary supplied by the platform/application team. This solution does not attempt to implement the recording software.

Although the reference implementation uses AWS/EKS, the core recorder workload is Kubernetes-based. The Kubernetes workload could therefore be adapted to another Kubernetes platform if required.

---

## Repository Structure

```text
Radio-Recording-Architecture/
│
├── README.md
│
├── terraform/
│   ├── versions.tf
│   ├── providers.tf
│   ├── variables.tf
│   ├── vpc.tf             # vpc & submets
│   ├── eks.tf             # EKS cluster, managed node group and ECR
│   ├── s3.tf              # Store Recording 
│   ├── iam.tf             # IRSA & S3 permission
│   ├── recorder.tf        # One recorder Deployment per station
│   ├── autoscaler.tf      # Cluster Autoscaler
│   ├── monitoring.tf      # Prometheus?grafana and POD monitor
│   ├── outputs.tf         # Terraform outputs
│   └── terraform.tfvars.example     # Env configuration
│
├── k8s/
│   └── example-recorder-deployment.yaml
│
└── monitoring/
    └── alerts.yaml

terraform/ is the primary source of truth for the infrastructure and Kubernetes resources.

The Kubernetes manifest is provided as an example/reference manifest showing the recorder workload independently of Terraform.
```

## High-Level Architecture

<img width="539" height="686" alt="image" src="https://github.com/user-attachments/assets/834f7575-f453-4fcc-8ff9-d83793daf058" />

flowchart LR
    Internet(("Internet")) --> NATGW["NAT Gateway"]

    subgraph PrivateNetwork["Private Network"]
        direction TB
        subgraph SubnetA["Private Subnet A"]
            direction TB
            EKSNodeA["EKS Node A"]
        end
        subgraph SubnetB["Private Subnet B"]
            direction TB
            EKSNodeB["EKS Node B"]
        end
    end

    NATGW --> EKSNodeA
    NATGW --> EKSNodeB
    EKSNodeA -->|"writes data"| S3[("Amazon S3")]
    EKSNodeB -->|"writes data"| S3

    classDef external fill:#ecfeff,stroke:#22d3ee,color:#0f172a;
    classDef gateway fill:#fff7ed,stroke:#fb923c,color:#0f172a;
    classDef private fill:#f0fdf4,stroke:#4ade80,color:#0f172a;
    classDef compute fill:#eef2ff,stroke:#818cf8,color:#0f172a;
    classDef storage fill:#f5f3ff,stroke:#a78bfa,color:#0f172a;

    class Internet external;
    class NATGW gateway;
    class SubnetA,SubnetB private;
    class EKSNodeA,EKSNodeB compute;
    class S3 storage;


The recorder pods run in private EKS subnets.

They establish outbound connections to the configured radio streams through the NAT Gateway and write completed audio segments to S3.

S3 provides durable storage that can be consumed independently by downstream processing systems.


## One Recorder Deployment Per Station
Each configured station is represented by one Kubernetes Deployment.

```
                         EKS
                          │
          ┌───────────────┼───────────────┐
          │               │               │
          V               V               V
     recorder-A      recorder-B         recorder-C
          │               │               │
       Radio A          Radio B         Radio C
       stream           stream          stream

```
Terraform uses for_each over the configured station map:

```
resource "kubernetes_deployment" "recorder" {
  for_each = var.stations
  ...
}
```

This means that adding a station does not require creating another Kubernetes manifest manually.

For example:
```
20 stations                             100 stations
    │                                        |
    V                                        V
20 recorder Deployments             100 recorder Deployments

```

## Station Configuration

The current reference implementation stores the desired station configuration in:
```
var.stations
```

A station contains at least:
```
station ID
station URL
```

Eg:
```
stations = {
  radio_a = {
    url = "https://example.com/radio-a"
  }

  radio_b = {
    url = "https://example.com/radio-b"
  }
}
```
Adding or removing a station therefore becomes a configuration change followed by:
```
terraform apply
```
Note : No application code or Kubernetes manifest needs to be manually modified.

## Recording Strategy

The recorder is assumed to produce fixed-duration audio segments rather than maintaining one indefinitely growing audio file.

The default configuration uses:
```
5 minute segments
```
Eg:
```
Radio stream
     │
     V
┌───────────┐                                
│ Segment 1 │  00:00 - 05:00               
└───────────┘                                
     │
     V
     S3
┌───────────┐
│ Segment 2 │  05:00 - 10:00
└───────────┘
     │
     V
     S3
┌───────────┐
│ Segment 3 │  10:00 - 15:00
└───────────┘
     │
     V
     S3
```

## S3 Storage

Audio recordings are stored in an S3 bucket.

Objects are logically partitioned by station and recording time.

```
s3://radio-recordings/
    station-a/
        2026/
            09/
                29/
                    22/
                        segment-220000.mp3
                        segment-220500.mp3
                        segment-221000.mp3

    station-b/
        2026/
            09/
                29/
                    22/
                        segment-220000.mp3
                        segment-220500.mp3
```

## Network Architecture

The EKS worker nodes run in private subnets across multiple Availability Zones.

```
                    AWS VPC
                       │
        ┌──────────────┼──────────────┐
        │              │              │
      AZ-A            AZ-B           AZ-C
        |              │              │
        V              V              V 
   Private Subnet  Private Subnet  Private Subnet
        │              │              │
        V              V              V
       EKS Nodes      EKS Nodes      EKS Nodes
```
Note:

Recorder pods do not need public IP addresses.
Outbound access to radio streams is provided through the NAT Gateway.

## Resilience
The system is designed to continue operating when individual components fail.

### Recorder process failure

Kubernetes restarts the recorder container.
```
Recorder process
      │
      X
   crashes
      │
      ▼
Kubernetes detects failure
      │
      ▼
Container restarted
```
### Pod failure

If a pod disappears, Kubernetes recreates it.

### Node failure

If an EKS worker node fails, Kubernetes can reschedule the recorder workload onto another available node, subject to cluster capacity.

### Cluster capacity

Cluster Autoscaler monitors pending pods and can increase node capacity when the existing nodes cannot accommodate additional recorder workloads.

This is important when the number of stations increases significantly.

### Scaling:
There are two separate scaling problems:

1. Application scaling

Each station has its own recorder Deployment.
```
20 stations → approximately 20 recorder pods

50 stations → approximately 50 recorder pods

100 stations → approximately 100 recorder pods
```
Adding stations is primarily a configuration change.

2. Infrastructure scaling

As more recorder pods are created, Kubernetes may eventually require additional worker nodes.

Cluster Autoscaler handles this by increasing the EKS node group capacity when pods cannot be scheduled due to insufficient resources.

```
More stations
      │
      ▼
More recorder pods
      │
      ▼
Insufficient node capacity
      │
      ▼
Cluster Autoscaler
      │
      ▼
More EKS nodes
```

The node group has configurable minimum, desired and maximum sizes.

## Monitoring

Monitoring is split into two different concerns:

### Infrastructure health

Examples:

    - Pod restarts
    - Unschedulable pods
    - Node capacity
    - Kubernetes health

### Recording health

The most important signal is whether a station is actually producing recording segments.

A pod being Running does not necessarily mean that useful audio is being recorded.

Eg:
```
Pod = Running
Container = Running
        │
        ▼
But radio stream disconnected
        │
        ▼
No new audio segments
        │
        ▼
Recording gap
```
