{{- define "microservice.name" -}}
{{ .Chart.Name }}
{{- end }}

{{- define "microservice.fullname" -}}
{{ .Release.Name }}-{{ .Chart.Name }}
{{- end }}
