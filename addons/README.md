# `addons/` — the trusted half

Alethia renders an `addons` ArgoCD Application pointed at this directory with `recurse: true`, under
a project that differs from the `apps` project in exactly one way that matters here: its
`sourceRepos` accepts **any** repository, not only this one. That is what lets an `Application` in
this directory pull a chart from `ghcr.io` or `registry.k8s.io`.

Everything here is CRD-bearing, cluster-scoped platform. None of it can ship as a bring-your-own
chart — see [the split](../README.md#the-split) — and that is the single thing this template exists
to teach.

| File | Chart | Into | Wave |
|---|---|---|---|
| `kserve-crd.yaml` | `oci://ghcr.io/kserve/charts/kserve-crd` `v0.15.2` | `kserve` | `-1` |
| `kserve.yaml` | `oci://ghcr.io/kserve/charts/kserve` `v0.15.2` | `kserve` | `0` |
| `kueue.yaml` | `oci://registry.k8s.io/kueue/charts/kueue` `0.19.5` | `kueue-system` | `0` |

## Before these converge

**cert-manager must be running.** KServe's admission webhook needs a certificate from it. There is
no cert-manager add-on in Alethia's marketplace — it is part of the platform. Create the project
from the **AI Workloads** template and Alethia installs it for you, on any cloud, with no domain. If
you copied this repository into a project created some other way, turn on a managed certificate
instead: a **Domain name** plus **Managed TLS certificate** on the DNS component (AWS, Google Cloud
and Azure).

Do not add cert-manager to this directory. It is not shipped here on purpose: two things installing
cert-manager into one cluster fight over the same CRDs, and ArgoCD resolves that by flapping.

## What is deliberately NOT here

**The NVIDIA GPU operator** — see [`../gpu/`](../gpu). It is one `cp` away, and it is one `cp` away
rather than one comment away because a GPU node pool is the most expensive thing you can provision
by accident.

**The Kueue queue objects** — see [`../batch/`](../batch). They are custom resources of the CRDs
`kueue.yaml` installs, so applying them in the same sync means dry-running against a type the API
server has not heard of yet.

**The workloads.** The vector database, the embedding server, CPU inference and the RAG app are all
plain namespaced resources, so they belong in [`../chart/`](../chart), under the default-deny
project, where an untrusted chart belongs.

## Treat this directory as trusted content

The `addons` project permits cluster-scoped resources of any kind, in any namespace. Anything you
add here runs with that. Review it the way you would review a cluster-admin manifest, because that
is what it is.
