# Потолок команды. Значения задаются при make team (QUOTA_*), по умолчанию:
# 2 CPU / 2Gi по requests. Нода apps: 4 vCPU / 6 GB на всех команд сразу.
apiVersion: v1
kind: ResourceQuota
metadata:
  name: team-quota
spec:
  hard:
    requests.cpu: "__REQ_CPU__"
    requests.memory: __REQ_MEM__
    limits.cpu: "__LIM_CPU__"
    limits.memory: __LIM_MEM__
    pods: "20"
    persistentvolumeclaims: "0"
