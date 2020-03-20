#!/bin/bash

# Mostly taken from the following source:
# https://github.com/azurecitadel/azurecitadel.github.io/tree/master/automation/terraform/createTerraformServicePrincipal.sh


projectpath=${1?"Usage: $0 ./ spn1"}
sname=${2?"Usage: $0 ./ spn1"}
#sname=${3:-"${outpath##*/}"}
name="http://${sname}"
tfprovider=${3:-"${projectpath}/provider.tf"}
azconfig=${4:-"${projectpath}/.azconfig"}

yellow() { tput setaf 3; cat - ; tput sgr0; return; }
cyan()   { tput setaf 6; cat - ; tput sgr0; return; }
error()  {
  if [[ -n "$@" ]]
  then
    tput setaf 1
    echo "ERROR: $@" >&2
    tput sgr0
  fi

  exit 1
}

# Grab the Azure subscription ID
subId=$(az account show --output tsv --query id)
[[ -z "$subId" ]] && error "Not logged into Azure as expected."

# Check for existing provider.tf
if [[ -f $tfprovider ]]
then
  echo -n "$tfprovider file exists.  Do you want to overwrite? [Y/n]: "
  read ans
  [[ "${ans:-Y}" != [Yy] ]] && exit 0
fi

echo ''
echo "Path: $projectpath"
echo "SPN: $sname"
echo "SPN FQDN: $name"
echo "Terraform provider file: $tfprovider"
echo "Subscription Id: $subId"
echo "Azure config file: $azconfig"
echo ''

# Create the service principal
echo "az ad sp create-for-rbac --name \"$name\"" | yellow
spout=$(az ad sp create-for-rbac --skip-assignment --name "$sname" --output json)

# If the service principal has been created then offer to reset credentials
if [[ "$?" -ne 0 ]]
then
  echo -n "Service Principal already exists. Do you want to reset credentials? [Y/n]: "
  read ans
  if [[ "${ans:-Y}" = [Yy] ]]
  then 
    spout=$(az ad sp credential reset --name "$name" --output json)
    [[ -z "$spout" ]] && error "Failed to create / reset the service principal $name"
  else
    spout=`cat $azconfig`
    [[ -z "$spout" ]] && error "Failed to load the json file: $azconfig"
  fi
else
  echo "Created new SPN, saving output to $azconfig"
  echo $spout > $azconfig
fi

# json output to screen
echo "$spout" | yellow

# Derive the required variables
clientId=$(jq -r .appId <<< $spout)
clientSecret=$(jq -r .password <<< $spout)
tenantId=$(jq -r .tenant <<< $spout)

echo 'SPN Info'
echo "clientId: $clientId"
echo "clientSecret: $clientSecret"
echo "tenantId: $tenantId"
echo ''

[[ -z "$clientId" ]] && error "Without a clientId we are unable to proceed! Try validating $azconfig exists and is accurate (or force reset the password)"

echo Updating $projectpath/$sname
echo $clientSecret > $projectpath/$sname

echo -e "\nWill now create $tfprovider. Choose output type."
PS3='Choose provider block type: '
options=("Populated azurerm block" "Empty azurerm block with environment variables" "Quit")
select opt in "${options[@]}"
do
  case $opt in
    "Populated azurerm block")
      cat > $tfprovider <<-END-OF-STANZA
	provider azurerm {
	  subscription_id = "$subId"
	  client_id       = "$clientId"
	  client_secret   = "$clientSecret"
	  tenant_id       = "$tenantId"
	  version         = ">1.30.0"
    features {}
	}
	END-OF-STANZA

      echo -e "\nPopulated $tfprovider:"
      cat $tfprovider | yellow
      echo
      break
      ;;
    "Empty azurerm block with environment variables")
      echo "provider \"azurerm\" {}" > $tfprovider
      echo -e "\nEmpty $tfprovider:"
      cat $tfprovider | yellow
      echo >&2

      export ARM_SUBSCRIPTION_ID="$subId"
      export ARM_CLIENT_ID="$clientId"
      export ARM_CLIENT_SECRET="$clientSecret"
      export ARM_TENANT_ID="$tenantId"

      echo "Copy the following environment variable exports and paste into your .bashrc file:"
      cat <<-END-OF-ENVVARS | cyan
	export ARM_SUBSCRIPTION_ID="$subId"
	export ARM_CLIENT_ID="$clientId"
	export ARM_CLIENT_SECRET="$clientSecret"
	export ARM_TENANT_ID="$tenantId"

	END-OF-ENVVARS
      break
      ;;
    "Quit")
      exit 0
      ;;
    *) echo "invalid option $REPLY";;
  esac
done

echo "To log in as the Service Principal then run the following command:"
echo "az login --service-principal --username \"$clientId\" --password \"$clientSecret\" --tenant \"$tenantId\"" | cyan

exit 0
