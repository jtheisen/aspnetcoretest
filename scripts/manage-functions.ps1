
function Init-Boilerplate {
  Set-ExecutionPolicy -ExecutionPolicy RemoteSigned -Scope LocalMachine
  Import-Module Az
  Connect-AzAccount
}

function New-Node {
  param (
    [parameter(Mandatory=$true, HelpMessage="eg. westeurope")] [String] $Location,
    [parameter(Mandatory=$true, HelpMessage="eg. '1'")] [String] $GroupSuffix,
    [parameter(Mandatory=$true, HelpMessage="eg. '1'")] [String] $VmSuffix,
    [parameter(Mandatory=$true)] [String] $customDataFile,
    [parameter(HelpMessage="eg. who")] [String] $AdminUser = "who",
    [parameter(HelpMessage="eg. secret")] [String] $AdminPassword = "qwerty!42XYZioio",
    [parameter()] [String] $VMSize = "Basic_A1"
  )

  $groupName = "$location-$GroupSuffix"
  $grpName = "grp-$groupName"

  $vntName = "vnt-$groupName"
  $nsgName = "nsg-$groupName"

  $vmName = "vm-$groupName-$VmSuffix"
  $ifName = "if-$groupName-$VmSuffix"
  $ipName = "ip-$groupName-$VmSuffix"
  $osName = "os-$groupName-$VmSuffix"

  $customData = (Get-Content -Raw $customDataFile)
  
  $vn = Get-AzVirtualNetwork -Name $vntName -ResourceGroupName $grpName
  $sn = Get-AzVirtualNetworkSubnetConfig -VirtualNetwork $vn

  $ip = New-AzPublicIpAddress -Name $ipName  -ResourceGroupName $grpName -AllocationMethod Static -Location $location
  $if = New-AzNetworkInterface -Name $ifName -ResourceGroupName $grpName -Location $location -SubnetId $sn.id -PublicIpAddressId $ip.Id

  $VmLocalAdminUser = "jens"
  $VmLocalAdminSecurePassword = (ConvertTo-SecureString $AdminPassword -AsPlainText -Force)
  $Credential = New-Object System.Management.Automation.PSCredential ($AdminUser, $VmLocalAdminSecurePassword)
  $VirtualMachine = New-AzVMConfig -VMName $vmName -VMSize $VMSize
  $VirtualMachine = Set-AzVMOperatingSystem -VM $VirtualMachine -Linux -ComputerName $vmName -Credential $Credential -CustomData $customData
  $VirtualMachine = Add-AzVMNetworkInterface -VM $VirtualMachine -Id $if.Id
  $VirtualMachine = Set-AzVMOSDisk -VM $VirtualMachine -Name $osName -Caching ReadWrite -CreateOption FromImage -Linux
  $VirtualMachine = Set-AzVMSourceImage -VM $VirtualMachine -PublisherName Canonical -Offer UbuntuServer -Skus "18.04-LTS" -Version latest
  $VirtualMachine = Set-AzVMBootDiagnostic -VM $VirtualMachine -Disable # TODO
  New-AzVM -ResourceGroupName $grpName -Location $location -VM $VirtualMachine
}

function Remove-Node {
  param (
    [parameter(Mandatory=$true, HelpMessage="eg. westeurope")] [String] $Location,
    [parameter(Mandatory=$true, HelpMessage="eg. '1'")] [String] $GroupSuffix,
    [parameter(Mandatory=$true, HelpMessage="eg. '1'")] [String] $VmSuffix
  )
  
  $groupName = "$location-$GroupSuffix"
  $grpName = "grp-$groupName"

  $vntName = "vnt-$groupName"
  $nsgName = "nsg-$groupName"

  $vmName = "vm-$groupName-$VmSuffix"
  $ifName = "if-$groupName-$VmSuffix"
  $ipName = "ip-$groupName-$VmSuffix"
  $osName = "os-$groupName-$VmSuffix"

  Remove-AzVM -Name $vmName -ResourceGroupName $grpName -Force
  Remove-AzDisk -Name $osName -ResourceGroupName $grpName -Force

  Remove-AzNetworkInterface -Name $ifName -ResourceGroupName $grpName -Force
  Remove-AzPublicIpAddress -Name $ipName -ResourceGroupName $grpName -Force
}

function New-Group {
  param (
    [parameter(Mandatory=$true, HelpMessage="eg. westeurope")] [String] $Location,
    [parameter(Mandatory=$true, HelpMessage="eg. '1'")] [String] $Suffix = "1"
  )

  $ErrorActionPreference = "Stop"

  $groupName = "$location-$suffix"
  $grpName = "grp-$groupName"

  $vntName = "vnt-$groupName"
  $nsgName = "nsg-$groupName"

  New-AzResourceGroup -Name $grpName -Location $location

  $httpRule = New-AzNetworkSecurityRuleConfig -Name http-rule -Description "Allow HTTP" -Access Allow -Protocol Tcp -Direction Inbound -Priority 310 -SourceAddressPrefix Internet -SourcePortRange * -DestinationAddressPrefix * -DestinationPortRange 80
  $httpsRule = New-AzNetworkSecurityRuleConfig -Name https-rule -Description "Allow HTTPS" -Access Allow -Protocol Tcp -Direction Inbound -Priority 320 -SourceAddressPrefix Internet -SourcePortRange * -DestinationAddressPrefix * -DestinationPortRange 443
  $sshRule = New-AzNetworkSecurityRuleConfig -Name ssh-rule -Description "Allow SSH" -Access Allow -Protocol Tcp -Direction Inbound -Priority 300 -SourceAddressPrefix Internet -SourcePortRange * -DestinationAddressPrefix * -DestinationPortRange 22

  $sg = New-AzNetworkSecurityGroup -Name $nsgName -ResourceGroupName $grpName -Location $location -SecurityRules $httpRule,$httpsRule,$sshRule
  $sn = New-AzVirtualNetworkSubnetConfig -Name "default" -AddressPrefix "10.0.0.0/16" -NetworkSecurityGroup $sg
  $vn = New-AzVirtualNetwork -Name $vntName -ResourceGroupName $grpName -Location $location -AddressPrefix "10.0.0.0/16" -Subnet $sn
}

function Remove-Group {
  param (
    [parameter(Mandatory=$true, HelpMessage="eg. westeurope")] [String] $Location,
    [parameter(Mandatory=$true, HelpMessage="eg. '1'")] [String] $Suffix = "1"
  )

  $ErrorActionPreference = "Stop"

  $groupName = "$location-$suffix"
  $grpName = "grp-$groupName"

  $vntName = "vnt-$groupName"
  $nsgName = "nsg-$groupName"

  Remove-AzVirtualNetwork -Name $vntName -ResourceGroupName $grpName -Force
  Remove-AzNetworkSecurityGroup -Name $nsgName -ResourceGroupName $grpName -Force
  Remove-AzResourceGroup -Name $grpName -Force
}

