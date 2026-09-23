# alethia-starter-ai

A working AI stack for [Alethia](https://alethialabs.io) — retrieval-augmented generation over your
own documents, with a vector database, a CPU embedding server, CPU inference, model serving and job
queueing — and, more importantly, **the worked example of where the line runs between the two trust
levels Alethia gives you.**

> **CPU-only by default. Nothing here provisions a GPU.**
> A GPU node pool is the most expensive thing you could provision by accident, so enabling one is a
> deliberate `cp` and a commit with your name on it. See [`gpu/`](./gpu).

## The split

Alethia gives your manifests one of two ArgoCD projects, and they are not the same shape:

| | apps repository (`addons/`) | bring-your-own chart (`chart/`) |
|---|---|---|
| Cluster-scoped resources | **any kind** | **none** |
| `Role` / `RoleBinding` / `ServiceAccount` | allowed | **blacklisted** |
| Source repositories | any (`addons` project) | only the one you configured |
| What runs here | KServe, Kueue, the GPU operator | Qdrant, embeddings, inference, the RAG app |

**KServe, Kueue and the NVIDIA GPU operator install CustomResourceDefinitions**, which are
cluster-scoped. They cannot be bring-your-own charts — not because of what they are, but because of
what they *create*. Qdrant is a database and could easily have been on the other side: what puts it
here is that a Deployment, a Service and a PersistentVolumeClaim are none of the forbidden things.
Most vector-database *charts* ship an operator and therefore cannot come this way; this one does not
ship an operator.

That is the whole lesson, and it is the one thing a diagram of an AI platform never tells you.

```
kustomization.yaml    the ROOT manifest — without one the root Application manages nothing
namespace.yaml        the ai-platform namespace
template-info.yaml    what this is, readable from inside the cluster
addons/               KServe + Kueue          → the wide-open `addons` project
chart/                the workloads           → the default-deny bring-your-own project
gpu/                  the GPU operator        → inert until you copy it into addons/
batch/                Kueue queues + a sample → applied after Kueue exists
hack/                 the contract check, runnable against any chart
```

## Use it

**Prerequisite: cert-manager.** KServe's admission webhook needs a certificate from cert-manager.
Alethia's marketplace has **no** cert-manager add-on: cert-manager is part of the platform, and you
get it one of two ways.

- **Create the project from the AI Workloads template** in the console. Alethia then installs
  cert-manager for you, on any cloud, with no domain.
- **Otherwise** — you copied this repository into a project created some other way — turn on a
  managed certificate: on the DNS component, set a **Domain name** and turn on **Managed TLS
  certificate**. This works on AWS, Google Cloud and Azure.

Do **not** add cert-manager to `addons/`. A second copy fights the platform's over the same CRDs, a
resource-ownership fight that ArgoCD resolves by flapping.

1. **Use this template** to create your own repository.

2. **The trusted half.** Point the environment's **ArgoCD apps repository** at your copy and leave
   the overlay path empty. Deploy. The root Application applies the namespace; the `addons`
   Application creates `kserve-crd`, `kserve` and `kueue`.

   ```bash
   alethia project component add --project <project> --env <env> --kind repositories \
     --set apps_destination_repo=https://github.com/<you>/<your-repo>
   ```

3. **The untrusted half.** **Add-ons → Bring your own chart**:
   - **Chart repository** — `https://github.com/<you>/<your-repo>`
   - **Chart path** — `chart`
   - **Ref** — `HEAD`, or a tag if you want deploys to be explicit

4. Wait. The first start downloads two models — roughly 950 MB in total — so give it a few
   minutes. The probes are sized for it; a pod that looks stuck for the first five minutes is
   downloading.

   ```bash
   kubectl -n <your-namespace> get pods -w
   kubectl -n <your-namespace> port-forward svc/<release>-alethia-starter-ai-webui 8080:80
   ```

   The first account you create in the web UI is the administrator. Upload a document, ask a
   question about it, and the answer has been through all four components.

## What is in `chart/`

| Component | Image | Why this one |
|---|---|---|
| Vector database | `qdrant/qdrant:v1.19.1` | A plain Deployment + Service + PVC, so it is legal under the default-deny project |
| Embeddings | `ghcr.io/huggingface/text-embeddings-inference:cpu-1.8` | The `cpu-` build. `BAAI/bge-small-en-v1.5` is ~130 MB and genuinely good at retrieval |
| Generation | `ghcr.io/ggml-org/llama.cpp:server-b5350` | OpenAI-compatible on CPU. `gemma-3-1b-it` quantised is ~800 MB and answers usefully |
| RAG app | `ghcr.io/open-webui/open-webui:v0.6.34` | Document upload, chunking and chat, wired to the three above |

Requests total roughly **2.3 vCPU and 5 GiB** across four pods. Both model caches are `emptyDir`:
the models re-download in seconds, and a volume claim per cache is storage you pay for to avoid
that. Qdrant's data and the RAG app's own database are on volume claims, because those you would
mind losing.

**Every image tag is pinned.** `:server` and `:main` exist upstream and move; a template whose
behaviour changes when someone else pushes is not a template.

## What is in `addons/`

| File | Chart | Into |
|---|---|---|
| `kserve-crd.yaml` | `oci://ghcr.io/kserve/charts/kserve-crd` `v0.15.2` | `kserve`, sync wave `-1` |
| `kserve.yaml` | `oci://ghcr.io/kserve/charts/kserve` `v0.15.2` | `kserve` |
| `kueue.yaml` | `oci://registry.k8s.io/kueue/charts/kueue` `0.19.5` | `kueue-system` |

KServe runs in **`RawDeployment`** mode. Its default is `Serverless`, which needs Knative Serving
and an Istio ingress gateway — three more platforms, none of them here, and an `InferenceService`
that never leaves `Unknown` if they are absent.

Each of these names `project: addons`, not `project: apps`. The `apps` project pins its
`sourceRepos` to **your** repository, so an Application under it cannot pull a chart from
`ghcr.io`. The `addons` project is the one that accepts another source, which is exactly why this
directory is where an upstream chart goes.

## Cost, stated before you spend it

| | Roughly |
|---|---|
| The default CPU stack | fits in an ordinary node pool: ~2.3 vCPU, ~5 GiB, ~10 GiB of volumes |
| One GPU node | a four-figure monthly bill, depending on cloud and shape |

Nothing in this template provisions the second one. [`gpu/`](./gpu) explains what it takes to, and
what to delete afterwards — including the node pool, which no manifest here can remove for you.

## Verification

`.github/workflows/validate.yml`, on every push, free:

- `helm lint --strict` and `helm template` over `chart/`, with the defaults and with every
  documented option on;
- an assertion that `values.schema.json` actually **refuses** an unknown key;
- `hack/check-byo-contract.sh` over the rendered chart — every kind against an allowlist of
  namespaced, non-RBAC kinds;
- **an assertion that the contract check fails** on a contract-breaking render, because a check
  that had quietly stopped looking would report a pass on every run;
- `kustomize build` over the root, and a parse of every manifest in `addons/`, `gpu/` and `batch/`;
- an assertion that every `Application` names `project: addons`;
- an assertion that **nothing outside `gpu/` asks for `nvidia.com/gpu`** — tested against parsed
  manifests and the rendered chart, not by grepping the source, so it cannot be satisfied by
  deleting the comment that promises it.

## The other starter templates

| Repository | What it is |
|---|---|
| [`alethia-starter-apps`](https://github.com/alethialabs-io/alethia-starter-apps) | the apps-destination repository — root manifest, overlays, add-ons |
| [`alethia-starter-chart`](https://github.com/alethialabs-io/alethia-starter-chart) | a minimal bring-your-own Helm chart |
| [`alethia-starter-ai`](https://github.com/alethialabs-io/alethia-starter-ai) | this one |
| [`alethia-examples`](https://github.com/alethialabs-io/alethia-examples) | larger worked references, including the isolation ladder |

Contracts in full:
[the apps repository](https://alethialabs.io/docs/console/design-project/repositories) ·
[bring your own charts](https://alethialabs.io/docs/concepts/bring-your-own-charts).
