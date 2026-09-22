{{/*
Names. Every one is bounded at 63 characters because it becomes a Service name, which is a DNS
label — a truncation that happens silently at apply time is worse than one that happens the same
way every render.
*/}}
{{- define "ai.name" -}}
{{- default .Chart.Name .Values.nameOverride | trunc 63 | trimSuffix "-" -}}
{{- end -}}

{{- define "ai.fullname" -}}
{{- if .Values.fullnameOverride -}}
{{- .Values.fullnameOverride | trunc 63 | trimSuffix "-" -}}
{{- else -}}
{{- $name := default .Chart.Name .Values.nameOverride -}}
{{- if contains $name .Release.Name -}}
{{- .Release.Name | trunc 63 | trimSuffix "-" -}}
{{- else -}}
{{- printf "%s-%s" .Release.Name $name | trunc 63 | trimSuffix "-" -}}
{{- end -}}
{{- end -}}
{{- end -}}

{{/* One component's object name: <fullname>-<component>, bounded. */}}
{{- define "ai.component" -}}
{{- printf "%s-%s" (include "ai.fullname" .root) .component | trunc 63 | trimSuffix "-" -}}
{{- end -}}

{{- define "ai.labels" -}}
helm.sh/chart: {{ printf "%s-%s" .Chart.Name .Chart.Version | replace "+" "_" | trunc 63 | trimSuffix "-" }}
app.kubernetes.io/name: {{ include "ai.name" . }}
app.kubernetes.io/instance: {{ .Release.Name }}
app.kubernetes.io/version: {{ .Chart.AppVersion | quote }}
app.kubernetes.io/managed-by: {{ .Release.Service }}
{{- end -}}

{{/*
The ServiceAccount the pods run as. `serviceAccount.create` defaults to false and should stay
false — the BYO project blacklists ServiceAccount. Empty renders no field at all, so the pods use
the namespace's `default`.
*/}}
{{- define "ai.serviceAccountName" -}}
{{- if .Values.serviceAccount.create -}}
{{- default (include "ai.fullname" .) .Values.serviceAccount.name -}}
{{- else -}}
{{- .Values.serviceAccount.name -}}
{{- end -}}
{{- end -}}

{{/* In-cluster URLs. Written once so the RAG app and the README cannot disagree about them. */}}
{{- define "ai.qdrantUrl" -}}
http://{{ include "ai.component" (dict "root" . "component" "qdrant") }}:{{ .Values.qdrant.service.httpPort }}
{{- end -}}

{{- define "ai.embeddingsUrl" -}}
http://{{ include "ai.component" (dict "root" . "component" "embeddings") }}:{{ .Values.embeddings.port }}
{{- end -}}

{{- define "ai.llmUrl" -}}
http://{{ include "ai.component" (dict "root" . "component" "llm") }}:{{ .Values.llm.port }}
{{- end -}}

{{/*
Pod-level scheduling, shared by every component.

No nodeSelector for a GPU anywhere in this chart, deliberately — see values.yaml.
*/}}
{{- define "ai.scheduling" -}}
{{- with .Values.nodeSelector }}
nodeSelector:
  {{- toYaml . | nindent 2 }}
{{- end }}
{{- with .Values.tolerations }}
tolerations:
  {{- toYaml . | nindent 2 }}
{{- end }}
{{- with .Values.affinity }}
affinity:
  {{- toYaml . | nindent 2 }}
{{- end }}
{{- end -}}
