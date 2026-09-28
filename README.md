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
