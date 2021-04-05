#Requires -Version 3
#Requires -Modules Az.Network, Az.Resources, Az.Accounts

<#
  Az Module Version Only
    Quick report of ARM based Azure networking that includes:

    - Location (region)
        - Virtual Networks (region based!)
            - Subnets
                - Associated NSGs
                - Associated Interfaces (VMs)
        - Network Security Groups (and rule counts)
                - Associated Subnets
        - Interfaces
        - Resource Groups
                - Associated Interfaces
                - Associated Availability Sets
                - Associated Gateways

    Note: Virtual Networks and interfaces may be associated with different resource groups!

    Author: Zachary Loeber
#>

## (Optional)
function Login-AZ($SubscriptionId)
{
    $context = Get-AzContext

    if (!$context -or ($context.Subscription.Id -ne $SubscriptionId)) 
    {
        Connect-AzAccount -Subscription $SubscriptionId
    } 
    else 
    {
        Write-Host "SubscriptionId '$SubscriptionId' already connected"
    }
}
if ([string]::IsNullOrEmpty($(Get-AzContext).Account)) {
    Login-AzAccount
}

if ($IsWindows) {
	$sub = Set-AzContext -SubscriptionId (Get-AzSubscription | Out-GridView -Title "Pick A Subscription" -PassThru).subscriptionid
}
else {
        $sub = Set-AzContext -SubscriptionId (Get-AzSubscription | Out-ConsoleGridView -Title "Pick A Subscription" -PassThru).subscriptionid
}

$AllNSGs = Get-AzNetworkSecurityGroup
$AllInts = Get-AzNetworkInterface
$AllLocations = Get-AzLocation
$SubnetIDToSubnetMap = @{}
$IntIDToIntMap = @{}
$VMIDToNameMap = @{}
$AllInts | ForEach-Object {
  $IntIDToIntMap.($_.Id) = "$($_.Name) ($(($_.IPConfigurations).PrivateIpAddress -join ','))"
}

Get-AzVM | Foreach-Object {
  $VMIDToNameMap.($_.Id) = $_.Name
}
$Indent = 1
Write-Output "Subscription: $($Sub.Subscription.SubscriptionName)"
Write-Output ''
Foreach ($Location in $AllLocations) {
  $AllNSGInLocation = @($AllNSGs | Where-Object {$_.Location -eq $Location.Location})
  $AllVNsInLocation = @(Get-AzVirtualNetwork | Where-Object {$_.Location -eq $Location.Location})
  $RGsInLocation = @(Get-AzResourceGroup -Location $Location.Location)
    
  # Start Region Report
  if ( ($AllNSGInLocation.Count -gt 0) -or 
    ($RGsInLocation.Count -gt 0) -or 
    ($AllVNsInLocation.Count -gt 0) ) {
    Write-Output "Azure Region: $($Location.DisplayName)"

    # Virtual Network Report
    if ($AllVNsInLocation.Count -gt 0) {
      Foreach ($VN in $AllVNsInLocation) {
        Write-Output "$(' ' * ($Indent * 0))Virtual Network: $($VN.Name) ($(($VN.AddressSpace).AddressPrefixes -join ', '))"

        # Subnet Report
        if (($VN.Subnets).Count -gt 0) {
          Write-Output "$(' ' * ($Indent * 1))Virtual Network Subnets:"
          Foreach ($Subnet in ($VN.Subnets)) {
            $SubnetIDToSubnetMap.($Subnet.ID) = $Subnet.AddressPrefix
            Write-Output "$(' ' * ($Indent * 2))$($Subnet.Name) ($($Subnet.AddressPrefix))"
            $NSGsInSubnet = $AllNSGs | Where-Object {@($_.Subnets.Id) -contains $Subnet.Id}

            # NSGs Linked to Subnet
            if ($NSGsInSubnet.Count -gt 0) {
              Write-Output "$(' ' * ($Indent * 3))Associated NSGs:"
              Foreach ($NSGInSubnet in $NSGsInSubnet) {
                Write-Output "$(' ' * ($Indent * 3))- $($NSGInSubnet.Name)"
              }
            }

            # Interfaces (VMs) Connected to Subnet
            $IntsInSubnet = $AllInts | Where-Object {(($_.IpConfigurations).Subnet.Id -join '|') -match $Subnet.ID}
            if ($IntsInSubnet.Count -gt 0) {
              Write-Output "$(' ' * ($Indent * 3))Interfaces Linked to Subnet:"
              $IntsInSubnet | Foreach-Object {
                Write-Output "$(' ' * ($Indent * 3))- $($_.Name) ($(($_.Ipconfigurations.PrivateIpAddress) -join ', '))"
              }
            }
          }
        }

        Write-Output ''
      }
    }

    # NSG Report
    if ($AllNSGInLocation.Count -gt 0) {
      Write-Output "$(' ' * ($Indent * 0))Network Security Groups in Region:"
      Foreach ($NSG in $AllNSGInLocation) {
        $NSGRuleCount = ($NSG.SecurityRules).Count
        Write-Output "$(' ' * ($Indent * 1))$($NSG.Name) (Rule Count = $($NSGRuleCount))"
        # NSG Subnets
        if (($NSG.Subnets).Count -gt 0) {
          Write-Output "$(' ' * ($Indent * 2))Associated Subnets:"
          Foreach ($SubnetID in ($NSG.Subnets).ID) {
            Write-Output "$(' ' * ($Indent * 3))- $($SubnetIDToSubnetMap.$SubnetID)"
          }
        }
        # NSG Interfaces
        if (($NSG.NetworkInterfaces).Count -gt 0) {
          Write-Output "$(' ' * ($Indent * 2))Associated Interfaces:"
          Foreach ($NSGInt in ($NSG.NetworkInterfaces).ID) {
            Write-Output "$(' ' * ($Indent * 3))- $($IntIDToIntMap.$NSGInt)"
          }
        }
      }
      Write-Output ''
    }

    # Resource Groups In Location
    if ($RGsInLocation.Count -gt 0) {
      Write-Output "$(' ' * ($Indent * 1))Resource Groups in Region:"
      Foreach ($RG in $RGsInLocation) {
        Write-Output "$(' ' * ($Indent * 2))$($RG.ResourceGroupName)"
        $AllIntsInRG = @(Get-AzNetworkInterface -ResourceGroupName $RG.ResourceGroupName)
        $AllASsInRG = @(Get-AzAvailabilitySet -ResourceGroupName $RG.ResourceGroupName)
        $AllGWsInRG = @(Get-AzVirtualNetworkGateway -ResourceGroupName $RG.ResourceGroupName)
        # Interfaces in RG
        if ($AllIntsInRG.count -gt 0) {
          Write-Output "$(' ' * ($Indent * 3))Interfaces in this Group:"
          Foreach ($Int in $AllIntsInRG) {
            $IntIP = $Int[0].IpConfigurations[0].PrivateIpAddress
            Write-Output "$(' ' * ($Indent * 4))$($Int.Name) ($($IntIP))"
          }
        }

        # Gateways in RG
        if ($AllGWsInRG.count -gt 0) {
          Write-Output "$(' ' * ($Indent * 3))Gateways in this Group:"
          Foreach ($GW in $AllGWsInRG) {
            Write-Output "$(' ' * ($Indent * 4))$($GW.Name)"
            if (($GW.IPConfigurations.Subnet).Count -gt 0) {
              Write-Output "$(' ' * ($Indent * 5))Associated Subnets:"
              Foreach ($SubnetID in ($GW.IPConfigurations.Subnet).ID) {
                Write-Output "$(' ' * ($Indent * 6))- $($SubnetIDToSubnetMap.$SubnetID)"
              }
            }
          }
        }

        # Availability Sets in RG
        if ($AllASsInRG.count -gt 0) {
          Write-Output "$(' ' * ($Indent * 3))Availability Sets in this Group:"
          Foreach ($AS in $AllASsInRG) {
            Write-Output "$(' ' * ($Indent * 4))$($AS.Name)"
            if (($AS.VirtualMachinesReferences).Count -gt 0) {
              Write-Output "$(' ' * ($Indent * 5))VMs in this Availability Set:"
              $AS.VirtualMachinesReferences | ForEach-Object {
                Write-Output "$(' ' * ($Indent * 6))$($VMIDToNameMap[$_.Id])"
              }
            }
          }
        }
      }
    }
    Write-Output ''
  }
}
