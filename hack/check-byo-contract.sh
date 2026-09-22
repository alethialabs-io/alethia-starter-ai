#!/usr/bin/env bash
# Fail if a rendered chart would be refused by Alethia's bring-your-own-chart ArgoCD project.
#
# That project is default-deny: `clusterResourceWhitelist: []`, plus a namespaced blacklist of
# Role, RoleBinding and ServiceAccount. A chart that renders anything else fails its SYNC — in a
# cluster, minutes after a deploy that reported success, with an Application stuck `Missing`. This
# script asks the same question in about a second and with no cluster at all.
#
# Usage:
#   hack/check-byo-contract.sh <chart-dir> [helm template args...]
#
# The test is an ALLOWLIST, not a list of forbidden kinds. "Is this kind cluster-scoped?" has no
# offline answer for a kind nobody has heard of, and a deny list answers "no" for every one of
# them — which is the direction that passes on the regression it exists to catch. Adding a kind
# here is a deliberate act: check that it is namespaced and is not RBAC, then add it.
set -euo pipefail

ALLOWED_KINDS=(
  ConfigMap
  CronJob
  Deployment
  Endpoints
  HorizontalPodAutoscaler
  Ingress
  Job
  NetworkPolicy
  PersistentVolumeClaim
  Pod
  PodDisruptionBudget
  ReplicaSet
  Secret
  Service
  StatefulSet
)

# The three namespaced kinds the project blacklists BY NAME, each with the reason, so the error
# says why rather than only that.
declare -A BLACKLISTED=(
  [ServiceAccount]="the project blacklists it — a chart that can mint an identity could grant itself more than the project allows"
  [Role]="the project blacklists it — RBAC is not delegated to a bring-your-own chart"
  [RoleBinding]="the project blacklists it — RBAC is not delegated to a bring-your-own chart"
)

chart="${1:?usage: check-byo-contract.sh <chart-dir> [helm template args...]}"
shift || true

rendered="$(helm template byo-contract-check "$chart" "$@")"

if [ -z "${rendered//[[:space:]]/}" ]; then
  echo "error: the chart rendered nothing — this check would pass by examining an empty document" >&2
  exit 2
fi

kinds="$(printf '%s\n' "$rendered" | sed -n 's/^kind:[[:space:]]*\([A-Za-z0-9]*\).*/\1/p' | sort -u)"

if [ -z "$kinds" ]; then
  echo "error: no 'kind:' found in the render — refusing to report a pass on output this script could not read" >&2
  exit 2
fi

fail=0
while read -r kind; do
  [ -n "$kind" ] || continue
  if [ -n "${BLACKLISTED[$kind]:-}" ]; then
    echo "REFUSED  $kind — ${BLACKLISTED[$kind]}" >&2
    fail=1
    continue
  fi
  ok=0
  for a in "${ALLOWED_KINDS[@]}"; do
    [ "$kind" = "$a" ] && { ok=1; break; }
  done
  if [ "$ok" -eq 1 ]; then
    echo "ok       $kind"
  else
    echo "REFUSED  $kind — not in the allowlist. If it is namespaced and is not RBAC, add it to ALLOWED_KINDS in $0; if it is cluster-scoped, it cannot ship in a bring-your-own chart at all." >&2
    fail=1
  fi
done <<< "$kinds"

if [ "$fail" -ne 0 ]; then
  echo >&2
  echo "This chart would be refused by Alethia's bring-your-own-chart project." >&2
  echo "See https://alethialabs.io/docs/concepts/bring-your-own-charts" >&2
  exit 1
fi

echo "every rendered kind is namespaced and non-RBAC"
