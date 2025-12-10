{{/*
Expand the name of the chart.
*/}}
{{- define "membarr.name" -}}
{{- default .Chart.Name .Values.nameOverride | trunc 63 | trimSuffix "-" }}
{{- end }}

{{/*
Create a default fully qualified app name.
We truncate at 63 chars because some Kubernetes name fields are limited to this (by the DNS naming spec).
If release name contains chart name it will be used as a full name.
*/}}
{{- define "membarr.fullname" -}}
{{- if .Values.fullnameOverride }}
{{- .Values.fullnameOverride | trunc 63 | trimSuffix "-" }}
{{- else }}
{{- $name := default .Chart.Name .Values.nameOverride }}
{{- if contains $name .Release.Name }}
{{- .Release.Name | trunc 63 | trimSuffix "-" }}
{{- else }}
{{- printf "%s-%s" .Release.Name $name | trunc 63 | trimSuffix "-" }}
{{- end }}
{{- end }}
{{- end }}

{{/*
Create chart name and version as used by the chart label.
*/}}
{{- define "membarr.chart" -}}
{{- printf "%s-%s" .Chart.Name .Chart.Version | replace "+" "_" | trunc 63 | trimSuffix "-" }}
{{- end }}

{{/*
Common labels
*/}}
{{- define "membarr.labels" -}}
helm.sh/chart: {{ include "membarr.chart" . }}
{{ include "membarr.selectorLabels" . }}
{{- if .Chart.AppVersion }}
app.kubernetes.io/version: {{ .Chart.AppVersion | quote }}
{{- end }}
app.kubernetes.io/managed-by: {{ .Release.Service }}
{{- end }}

{{/*
Selector labels
*/}}
{{- define "membarr.selectorLabels" -}}
app.kubernetes.io/name: {{ include "membarr.name" . }}
app.kubernetes.io/instance: {{ .Release.Name }}
{{- end }}

{{/*
Create the name of the service account to use
*/}}
{{- define "membarr.serviceAccountName" -}}
{{- if .Values.serviceAccount.create }}
{{- default (include "membarr.fullname" .) .Values.serviceAccount.name }}
{{- else }}
{{- default "default" .Values.serviceAccount.name }}
{{- end }}
{{- end }}

{{/*
Get the discord token secret name
*/}}
{{- define "membarr.secretName" -}}
{{- if .Values.openbao.enabled }}
{{- .Values.openbao.staticSecret.secretName | default (printf "%s-vault-secret" (include "membarr.fullname" .)) }}
{{- else if .Values.discord.existingSecret }}
{{- .Values.discord.existingSecret }}
{{- else }}
{{- include "membarr.fullname" . }}-secret
{{- end }}
{{- end }}
