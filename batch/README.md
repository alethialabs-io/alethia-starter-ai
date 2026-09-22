# `batch/` — queues, applied after Kueue exists

Nothing in this directory is delivered either. `queues.yaml` holds custom resources of the CRDs
that `addons/kueue.yaml` installs, and an ArgoCD sync that applies a chart and a resource of that
chart's CRD in one pass dry-runs the second against a type the API server has not heard of.

So the order is: let `kueue` go Healthy, then

```bash
cp batch/queues.yaml addons/
git commit -am "add the starter queues" && git push
```

Sync waves do not solve this for you. They order the resources *inside one Application's sync*, and
the CRDs arrive through a **different** Application whose completion nothing here waits on.

## What is in `queues.yaml`

The smallest complete Kueue setup:

| Object | What it is |
|---|---|
| `ResourceFlavor/default-flavor` | "any node" — a GPU setup adds a second flavour selecting the GPU pool |
| `ClusterQueue/starter-cluster-queue` | the cluster-wide ceiling: 4 CPU, 8Gi |
| `LocalQueue/starter-queue` | what a Job names, in one namespace |

Change the `LocalQueue`'s namespace to the namespace your Jobs run in. Kueue matches by name within
a namespace, and a Job naming a queue that is not there is never admitted — with no event that says
why on the Job itself.

## Try it

```bash
kubectl apply -f batch/sample-job.yaml
kubectl get workloads
kubectl describe clusterqueue starter-cluster-queue
```

`sample-job.yaml` is applied by hand, not committed into `addons/`: a Job is one-shot, and an
Application that prunes and self-heals recreates it every time it completes.

## Why this is worth having before you have a GPU

The failure Kueue removes is not exotic. A batch embedding or fine-tuning Job submitted to a
cluster with no room is admitted immediately by the default scheduler and then sits `Pending`,
holding nothing, telling you nothing, while the next one queues behind it. Kueue admits a Job only
when the whole of it fits, and shows you the budget it is fitting into.

It matters more with a GPU, because that is when the resource being queued for is the one you are
paying four figures a month for. It is easier to set up before then.
