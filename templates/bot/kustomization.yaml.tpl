apiVersion: kustomize.config.k8s.io/v1beta1
kind: Kustomization
images:
  - name: __IMAGE__
    newTag: sha-0000000
resources:
  - deployment.yaml
