apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: __NAME__
  annotations:
    nginx.ingress.kubernetes.io/ssl-redirect: "true"
    cert-manager.io/cluster-issuer: "letsencrypt-prod"
    nginx.ingress.kubernetes.io/proxy-body-size: "50m"
spec:
  ingressClassName: nginx
  rules:
    - host: __DOMAIN__
      http:
        paths:
          - path: /
            pathType: Prefix
            backend:
              service:
                name: __NAME__
                port:
                  number: 80
  tls:
    - hosts:
        - __DOMAIN__
      secretName: __NAME__-tls
