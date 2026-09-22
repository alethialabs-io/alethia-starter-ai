# Changelog

This template is versioned with [semantic versioning](https://semver.org). `TEMPLATE_VERSION`,
`chart/Chart.yaml`'s `version` and the `version` key in `template-info.yaml` all hold the same
number, and CI fails if any of them disagrees or if the template changes without one moving.

What counts as which, for this repository:

| Change | Bump |
|---|---|
| A **values-schema change** — a key removed, renamed, or given a narrower type | **major** |
| A **chart-major bump** of KServe, Kueue or the GPU operator | **major** |
| A layout change a clone must follow — a moved path, a resource that must be deleted by hand | **major** |
| A new component, a new value with a default, a pinned image or chart version | **minor** |
| A comment, a README, a CI tweak | **patch** |

## 1.0.1 — 2026-09-22

- `chart/templates/serviceaccount.yaml`, rendered only when `serviceAccount.create` is true.

  It was missing, and the CI step that asserts the contract check **fails** on a contract-breaking
  render is what found it: with no such template the chart rendered the same thing whether the
  value was true or false, so the "mutation" mutated nothing and the check passed a render it
  should have refused. The control did its job on its first run. The chart now renders the
  ServiceAccount rather than silently dropping it, with the refusal explained in the template.

## 1.0.0 — 2026-09-22

Initial template.

**The trusted half** — `addons/`, under the wide-open `addons` project:

- KServe `v0.15.2` in `RawDeployment` mode, so it needs neither Knative nor Istio.
- Its CRDs as a separate Application at sync wave `-1`, with server-side apply.
- Kueue `0.19.5`.

**The untrusted half** — `chart/`, under the default-deny bring-your-own-chart project:

- Qdrant `v1.19.1` with a 5Gi volume claim.
- Text Embeddings Inference `cpu-1.8` serving `BAAI/bge-small-en-v1.5`.
- llama.cpp `server-b5350` serving `ggml-org/gemma-3-1b-it-GGUF` on CPU.
- Open WebUI `v0.6.34`, wired to all three.
- Nothing requests a GPU; every rendered kind is namespaced and non-RBAC.

**Opt-in, inert where it sits**:

- `gpu/gpu-operator.yaml` — the NVIDIA GPU operator `v26.7.0`, one `cp` from `addons/`.
- `batch/queues.yaml` — a ResourceFlavor, a ClusterQueue and a LocalQueue, applied after Kueue
  exists; plus a sample Job that demonstrates admission.

**CI**: `helm lint --strict`, `helm template`, `kustomize build`, an assertion that
`values.schema.json` refuses an unknown key, the bring-your-own-chart contract check over the
rendered chart, an assertion that the contract check itself fails on a contract-breaking render,
and a check that no manifest anywhere in the repository requests `nvidia.com/gpu` outside `gpu/`.
