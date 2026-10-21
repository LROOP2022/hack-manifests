# Без значений по умолчанию под без resources отклоняется квотой
apiVersion: v1
kind: LimitRange
metadata:
  name: team-defaults
spec:
  limits:
    - type: Container
      defaultRequest:
        cpu: 50m
        memory: 128Mi
      default:
        cpu: 500m
        memory: 512Mi
