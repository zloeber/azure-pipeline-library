#!/bin/bash
# Tag all azure resource groups in an extremely inefficient manner.

groups=$(az group list --query [].name --output tsv)
for rg in $groups
do
  jsontag=$(az group show -n $rg --query tags) || true
  t=$(echo $jsontag | tr -d '"{},' | sed 's/: /=/g') || true
  r=$(az resource list -g $rg --query [].id --output tsv) || true
  for resid in $r
  do
    jsonrtag=$(az resource show --id $resid --query tags) || true
    rt=$(echo $jsonrtag | tr -d '"{},' | sed 's/: /=/g') || true
    az resource tag --tags $t$rt --id $resid || true
  done
done