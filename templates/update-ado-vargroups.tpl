#!/bin/bash
echo "Creating $${ENVRCPATH} if possible"

cat <<FILEOUT > "$${ENVRCPATH}"
$${ENVRC}
FILEOUT

echo "***"
echo "Updating env var array for ADO insertion"
echo "***"

local myvalues=()
while IFS= read -r line; do
    var=`echo $line | tr -d '"'`
    myvalues+=("$var")
done < "$${ENVRCPATH}"

set -a
. "$${ENVRCPATH}"
set +a

# export AZURE_DEVOPS_EXT_AZURE_RM_SERVICE_PRINCIPAL_KEY="$(az keyvault secret show --name SPNSECRET --vault-name $KEYVAULTNAME --subscription "$AZ_SUBSCRIPTION" --query value -o tsv)"
# if [ -z "$AZURE_DEVOPS_EXT_AZURE_RM_SERVICE_PRINCIPAL_KEY" ]; then
#     echo "Without the AZURE_DEVOPS_EXT_AZURE_RM_SERVICE_PRINCIPAL_KEY the az commands will not work"
#     exit 1
# fi

get_ado_vargroup () {
  group=`az pipelines variable-group list \
    --detect false \
    --subscription "$AZ_SUBSCRIPTION_ID" \
    --organization "$ADO_ORG" \
    --project "$ADO_PROJECT" \
    -o table | grep $1 | head -n1 | awk '{print $1;}'`
  echo "$group"
}

remove_ado_vargroup () {
  echo "Attempting to remove vargroup id $1"
  if [ ! -z "$1" ]; then
    az pipelines variable-group delete \
      --group-id "$1" \
      --detect false \
      --subscription "$AZ_SUBSCRIPTION_ID" \
      --organization "$ADO_ORG" \
      --project "$ADO_PROJECT" \
      -y 2> /dev/null
  fi;
}

add_ado_vargroup () {
  if [ ! -z "$1" ]; then
    local name="$1"
    shift
    local arr=("$@")
    echo "Attempting to add vargroup - $name"
    echo "  Variables = $arr"
    az pipelines variable-group create \
      --name "$name" \
      --authorize true \
      --detect false \
      --subscription "$AZ_SUBSCRIPTION_ID" \
      --organization "$ADO_ORG" \
      --project "$ADO_PROJECT" \
      --variables "$${arr[@]}"
  fi;
}

## Global Params if not exists
globalvars=()
globalvars+="ADO_ORG=$ADO_ORG"
globalvars+="ADO_PROJECT=$ADO_PROJECT"
globalvars+="AZ_TENANT_ID=$AZ_TENANT_ID"

vargroup=`get_ado_vargroup global_parameters`
if [[ -z "$vargroup" ]]; then 
  add_ado_vargroup global_parameters "$${globalvars[@]}"
fi

## Stage Params if not exists
vargroup=`get_ado_vargroup $${STAGE}_parameters`
if [[ -z "$vargroup" ]]; then
  add_ado_vargroup $${STAGE}_parameters "STAGE=$${STAGE}"
fi

## Stage/Team Params (always to update)
vargroup=`get_ado_vargroup $${STAGE}_$${TEAM}_parameters`
remove_ado_vargroup $vargroup
add_ado_vargroup $${STAGE}_$${TEAM}_parameters "$${myvalues[@]}"
