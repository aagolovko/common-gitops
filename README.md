# Common GitOps

Shared GitOps declarations for infrastructure that is not owned by a single application.

This repository owns common `macosserver` cluster resources such as:

- the shared Cloudflare tunnel runner
- shared ingress routes in the `cloudflared` config

Application repositories such as `schnapper-gitops` and `poicrafter-gitops` should own only their own application resources.

## Bootstrap

The existing Flux installation can consume this repository as an additional source:

```bash
kubectl apply -f clusters/macosserver-cluster/flux-system/common-gitops-sync.yaml
```

The main kustomization renders from:

```text
clusters/macosserver-cluster
```

## Cloudflare Routes

Routes for shared hostnames live in:

```text
clusters/macosserver-cluster/infra/cloudflared/configmap.yaml
```

