# Права участника в своём namespace: смотреть, читать логи, заходить в под,
# перезапускать. Секреты не читаются, деплой идёт только через git.
apiVersion: rbac.authorization.k8s.io/v1
kind: Role
metadata:
  name: team-developer
rules:
  - apiGroups: [""]
    resources: [pods, pods/log, services, endpoints, configmaps, events, persistentvolumeclaims]
    verbs: [get, list, watch]
  - apiGroups: [""]
    resources: [pods/exec, pods/portforward]
    verbs: [create]
  - apiGroups: [""]
    resources: [pods]
    verbs: [delete]
  - apiGroups: [apps]
    resources: [deployments, statefulsets, replicasets]
    verbs: [get, list, watch, patch]
  - apiGroups: [batch]
    resources: [jobs, cronjobs]
    verbs: [get, list, watch]
  - apiGroups: [networking.k8s.io]
    resources: [ingresses]
    verbs: [get, list, watch]
  - apiGroups: [metrics.k8s.io]
    resources: [pods]
    verbs: [get, list]
