apiVersion: argoproj.io/v1alpha1
kind: Application
metadata:
  name: __PARENT__
  namespace: argocd
  finalizers:
    - resources-finalizer.argocd.argoproj.io
spec:
  project: default
  source:
    repoURL: __REPO_URL__
    targetRevision: __REPO_BRANCH__
    path: __PARENT__
  destination:
    server: https://kubernetes.default.svc
    namespace: __PARENT__
  syncPolicy:
    automated:
      prune: true
      selfHeal: true
    syncOptions:
      - CreateNamespace=true
