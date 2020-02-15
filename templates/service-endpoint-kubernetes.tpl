{
  "administratorsGroup": null,
  "authorization": {
    "parameters": {
      "clusterContext": "${aks_cluster}",
      "kubeconfig": ${aks_config}
    },
    "scheme": "Kubernetes"
  },
  "createdBy": {},
  "data": {
    "acceptUntrustedCerts": "true",
    "authorizationType": "Kubeconfig"
  },
  "description": "${target} kubernetes cluster",
  "groupScopeId": null,
  "isReady": true,
  "isShared": false,
  "name": "${target}_${team}_${client}_${stage}_kubernetes",
  "operationStatus": null,
  "owner": "Library",
  "readersGroup": null,
  "serviceEndpointProjectReferences": null,
  "type": "kubernetes",
  "url": "${aks_url}"
}
