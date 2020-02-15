{
  "description": "${target} container registry",
  "administratorsGroup": null,
  "authorization": {
    "parameters": {
      "username": "${acr_username}",
      "password": "${acr_password}",
      "email": "${acr_email}",
      "registry": "${acr_url}"
    },
    "scheme": "UsernamePassword"
  },
  "createdBy": null,
  "data": {
    "registrytype": "Others"
  },
  "name": "${stage}_registry",
  "type": "dockerregistry",
  "url": "${acr_url}",
  "readersGroup": null,
  "groupScopeId": null,
  "serviceEndpointProjectReferences": null,
  "operationStatus": null
}