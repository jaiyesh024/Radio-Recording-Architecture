# Radio-Recording-Architecture
Infrastructure design for continuously recording audio from a dynamic list of radio station URLs and writing the output to object storage, built to run 24/7 and scale from 20+ to 100 stations with a config change, not a redeploy of new code.

## Contents
```
├── README.md                  — this file
├── terraform/                 — all infrastructure as code (AWS reference implementation)
│   ├── versions.tf
│   ├── providers.tf
│   ├── variables.tf
│   ├── vpc.tf
│   ├── eks.tf
│   ├── s3.tf
│   ├── iam.tf
│   ├── recorder.tf            — the per-station Deployments (the core of requirement 3)
│   ├── autoscaler.tf
│   ├── monitoring.tf
│   ├── outputs.tf
│   └── terraform.tfvars.example
├── kubernetes/
│   └── example-recorder-deployment.yaml   — one manifest, standalone, for reference/review
└── monitoring/
    └── alerts.yaml             — PrometheusRule: gap detection + supporting alerts
```

1. **Station registry**
The desired state (which URLs should be recording), expressed here as a Terraform variable (`var.stations`); in production this would more naturally be a small database table, with Terraform reading it via a data source, or a generated `.tfvars` file from a CI step.

2. **Terraform** diffs that list against what's running and creates/deletes one Kubernetes `Deployment` per station accordingly, via `for_each`.
3. Each **recorder pod** wraps the pre-built recording binary, writes segmented audio (bounding data loss on a crash to one segment), and is self-healing - `restartPolicy: Always` plus a liveness probe means Kubernetes restarts a crashed process or reschedules it on a new node.
   
5. Segments upload to **S3**, partitioned `bucket/station_id/date/hour/segment.ext`, with lifecycle rules tiering older audio to cheaper storage classes.

6. **Monitoring** watches for recording gaps (a station going stale), pod restarts, upstream URL reachability, and storage growth.

## Recording strategy
The binary is assumed to write fixed-duration segments (5 minutes, configurable) rather than one continuous file for the life of the stream:

- **Bounded blast radius** — a crash loses at most one in-progress segment, not the whole session.
- **No large local disk needed** — each completed segment uploads to S3 as soon as it closes; the pod only ever buffers one segment locally (`emptyDir` is enough).
