# Common GitOps

Shared GitOps declarations for infrastructure that is not owned by a single application.

Local services for the m2host are grouped under `clusters/macosserver-cluster/infra/m2host-services`.
The host-monitoring and Frigate Compose stacks remain independent so either one can be restarted
without affecting the other.

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

## m2host Services

The local host services are organized as:

```text
clusters/macosserver-cluster/infra/m2host-services/
  host-monitoring/
  frigate/
```

Run each stack from its own directory with `docker compose up -d`. Frigate stores its
configuration in `frigate/config` and recordings in `frigate/media`; the media directory is
intentionally excluded from Git.
