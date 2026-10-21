apiVersion: apps/v1
kind: Deployment
metadata:
  name: __NAME__
spec:
  replicas: 1
  selector:
    matchLabels:
      app: __NAME__
  template:
    metadata:
      labels:
        app: __NAME__
    spec:
      nodeSelector:
        role: apps
      containers:
        - name: __NAME__
          image: __IMAGE__
          imagePullPolicy: IfNotPresent
          envFrom:
            - secretRef:
                name: __NAME__-secrets
          resources:
            requests:
              cpu: 50m
              memory: 128Mi
            limits:
              cpu: 500m
              memory: 512Mi
