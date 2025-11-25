{{/*
Expand the name of the chart.
*/}}
{{- define "keycloak.name" -}}
{{- default .Chart.Name .Values.nameOverride | trunc 63 | trimSuffix "-" }}
{{- end }}

{{/*
Create a default fully qualified app name.
*/}}
{{- define "keycloak.fullname" -}}
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
{{- define "keycloak.chart" -}}
{{- printf "%s-%s" .Chart.Name .Chart.Version | replace "+" "_" | trunc 63 | trimSuffix "-" }}
{{- end }}

{{/*
Common labels
*/}}
{{- define "keycloak.labels" -}}
helm.sh/chart: {{ include "keycloak.chart" . }}
{{ include "keycloak.selectorLabels" . }}
{{- if .Chart.AppVersion }}
app.kubernetes.io/version: {{ .Chart.AppVersion | quote }}
{{- end }}
app.kubernetes.io/managed-by: {{ .Release.Service }}
{{- end }}

{{/*
Selector labels
*/}}
{{- define "keycloak.selectorLabels" -}}
app.kubernetes.io/name: {{ include "keycloak.name" . }}
app.kubernetes.io/instance: {{ .Release.Name }}
{{- end }}

{{/*
Create the name of the service account to use
*/}}
{{- define "keycloak.serviceAccountName" -}}
{{- if .Values.serviceAccount.create }}
{{- default (include "keycloak.fullname" .) .Values.serviceAccount.name }}
{{- else }}
{{- default "default" .Values.serviceAccount.name }}
{{- end }}
{{- end }}

{{/*
Get the database secret name
*/}}
{{- define "keycloak.databaseSecretName" -}}
{{- if .Values.postgresql.existingSecret.name }}
{{- .Values.postgresql.existingSecret.name }}
{{- else }}
{{- include "keycloak.fullname" . }}-db
{{- end }}
{{- end }}

{{/*
Get the admin secret name
*/}}
{{- define "keycloak.adminSecretName" -}}
{{- if .Values.admin.existingSecret }}
{{- .Values.admin.existingSecretName }}
{{- else }}
{{- include "keycloak.fullname" . }}-admin
{{- end }}
{{- end }}

{{/*
Secret containing admin CLI credentials (works for operator + legacy modes)
*/}}
{{- define "keycloak.adminCredentialsSecretName" -}}
{{- if and .Values.operator.enabled (not .Values.admin.existingSecret) }}
{{- printf "%s-initial-admin" (include "keycloak.fullname" .) }}
{{- else }}
{{- include "keycloak.adminSecretName" . }}
{{- end }}
{{- end }}

{{/*
Get the Discord OAuth secret name
*/}}
{{- define "keycloak.discordSecretName" -}}
{{- if .Values.oauth.discord.existingSecret }}
{{- .Values.oauth.discord.existingSecret }}
{{- else }}
{{- include "keycloak.fullname" . }}-discord-oauth
{{- end }}
{{- end }}
