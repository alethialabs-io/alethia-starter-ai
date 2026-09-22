# `gpu/` — opt in, on purpose

Nothing in this directory is delivered. The root Application reads one directory and does not
recurse, and `addons/` is a different directory, so these files sit here inert until you move one.

```bash
cp gpu/gpu-operator.yaml addons/
git commit -am "enable the GPU operator" && git push
```

## Why it is a copy and not a flag

**A GPU node pool is the most expensive thing a reader of this repository could provision by
accident.** Depending on cloud and instance shape, one GPU node is a four-figure monthly bill —
enough that discovering the price after provisioning is the worst version of this feature.

A commented-out block, a `gpu.enabled: false` value or a disabled Application are all one
character from being on. A file in a directory nothing syncs is one deliberate act away, and the
act leaves a commit with your name on it.

## What the default path costs instead

The default AI stack in this template is **CPU-only**: a small instruct model served by
`llama.cpp`, a small embedding model served by Text Embeddings Inference, and Qdrant. It asks for
roughly **2.3 vCPU and 5 GiB of memory** in total across the namespace and runs on ordinary nodes.

## What you need before this is useful

1. A node pool with NVIDIA GPUs attached, created deliberately in your cloud.
2. The operator, from here.
3. A workload that asks for `nvidia.com/gpu` — the CPU stack in `chart/` never does.

Once the operator has labelled and provisioned your GPU nodes, a GPU-backed `InferenceService`
belongs on the KServe side of the split, not in the bring-your-own chart: see
[`../addons/README.md`](../addons/README.md).

## Turning it off again

Delete `addons/gpu-operator.yaml` and push. The Application carries ArgoCD's finalizer, so removing
it deletes what the operator created. **It does not delete your GPU nodes** — those are a node pool
in your cloud, and only you can remove them. That is the bill, so remove them too.
