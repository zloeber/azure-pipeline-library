#Requires -Version 3
#Requires -Modules Az.Accounts, Az.Automation, Az.Resources

# Define and validate parameters
[CmdletBinding()]
Param(
  [parameter()]
  [string]$SubscriptionId = "${sub_id}",

  [parameter()]
  [string]$TenantId = "${tenant_id}",

  [parameter()]
  [string]$AppId = "${app_id}",

  [parameter()]
  [string]$CredName = "${aa_name}",

  [parameter()]
  [string]$aaRG = "${aa_rg}",

  [parameter()]
  [string[]]$targetResourceGroups = @(${target_rgs}),

  [parameter()]
  [Hashtable]$Tags = @{
    "Tag1" = "Value1";
    "Tag2" = "Value2";
  }
)

## List of Resource Type that doesn't support Tags
$IgnoreTypes = @(
  "microsoft.insights/alertrules",
  "microsoft.insights/activityLogAlerts",
  "Microsoft.OperationsManagement/solutions",
  "Microsoft.Network/localNetworkGateways",
  "Microsoft.Web/certificates",
  "Microsoft.Sql/servers/databases"
)

try {
  $cred = Get-AutomationPSCredential -Name $CredName
  Write-Output ("Azure login credential: {0}" -f $CredName)
  Connect-AzAccount -ServicePrincipal -Tenant $TenantId -Credential $cred
}
catch {
  Write-Output ("Login failure")
  Write-Error -Message $_.Exception
  throw $_.Exception
}

$rgList = $targetResourceGroups | Foreach-Object { Get-AzResourceGroup $_ -ErrorAction:SilentlyContinue }
Write-Output ("Resource Group Count: {0}" -f $rgList.count)

foreach ($rg in $rgList) {
  Write-Output ("Resource Group: {0}" -f $rg)
  Write-Output ("Resource Group Tags: {0}" -f $rg.Tags.count)
  $rgTags = $rg.Tags
  $Tags.Keys | ForEach-Object { $rgTags[$_] = $Tags[$_] }
  Write-Output ("Resource Group '{0}' - Updating Tags" -f $rg.ResourceGroupName)
  Set-AzResource -Tags $rgTags -ResourceId $rg.ResourceId -WhatIf -Force

  foreach ( $resource in @(Get-AzResource -ResourceGroupName $rg.ResourceGroupName) ) {
    if ( $resourceType -notin $IgnoreTypes ) {
      Write-Output ("ResourceGroup '{0}' and child Resource '{1}' of type '{2}' is scanning" -f $rg.ResourceGroupName, $resource.Name, $resource.Type)
      $resTags = $resource.Tags
      $Tags.Keys | ForEach-Object {
        $resTags[$_] = $Tags[$_]
      }
      Write-Output ("Resource '{0}' - Updating Tags" -f $resource.Name)
      Set-AzResource -Tags $resTags -ResourceId $resource.ResourceId -Force -WhatIf
    }
    else {
      Write-Output ("[SKIP-TAGS] ResourceGroup '{0}' and child Resource '{1}' of type '{2}' is configured to skip. Nothing todo!" -f $rg.ResourceGroupName, $resource.Name, $resource.Type)
    }
  }
}

