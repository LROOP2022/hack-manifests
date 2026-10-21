apiVersion: rbac.authorization.k8s.io/v1
kind: RoleBinding
metadata:
  name: team-user-developer
subjects:
  - kind: ServiceAccount
    name: team-user
roleRef:
  apiGroup: rbac.authorization.k8s.io
  kind: Role
  name: team-developer
