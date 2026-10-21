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
          ports:
            - name: http
              containerPort: __PORT__
          resources:
            requests:
              cpu: 20m
              memory: 32Mi
            limits:
              cpu: 200m
              memory: 128Mi
          readinessProbe:
            httpGet:
              path: /
              port: __PORT__
            initialDelaySeconds: 3
            periodSeconds: 10
            timeoutSeconds: 2
          livenessProbe:
            httpGet:
              path: /
              port: __PORT__
            initialDelaySeconds: 5
            periodSeconds: 20
            timeoutSeconds: 2
