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
          env:
            - name: JAVA_TOOL_OPTIONS
              value: "-XX:MaxRAMPercentage=75"
          envFrom:
            - secretRef:
                name: __NAME__-secrets
          ports:
            - name: http
              containerPort: __PORT__
          resources:
            requests:
              cpu: 100m
              memory: 384Mi
            limits:
              cpu: "1"
              memory: 768Mi
          # Spring Boot с Actuator: management.endpoint.health.probes.enabled=true
          startupProbe:
            httpGet:
              path: /actuator/health/readiness
              port: __PORT__
            periodSeconds: 5
            failureThreshold: 36
          readinessProbe:
            httpGet:
              path: /actuator/health/readiness
              port: __PORT__
            periodSeconds: 10
            timeoutSeconds: 3
          livenessProbe:
            httpGet:
              path: /actuator/health/liveness
              port: __PORT__
            periodSeconds: 20
            timeoutSeconds: 3
