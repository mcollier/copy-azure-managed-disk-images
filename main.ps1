<#  -----Starting from an Azure platform provided image. -----
1.	Deploy a VM
2.	Configure the VM
3.	Sysprep/generalize the VM
4.	Create an Image in the same subscription
5.	Create a snapshot of the OS disk from the generalized VM. 
6.	Copy the snapshot to the second subscription
7.	In the second subscription, create a new Image from the copied snapshot
8.	In the second subscription, create a new VM from the new Image
9.	Delete the snapshot in the original and second subscription
10.	Delete the VM 
    (This VM is temporary. It is create only to force/trigger all the data related to the disks
     to be copied to the target. Until then, the copy process (related to snapshotting) is
     “lazy” / copy-on-read.)

Notes:
- Assumes the user running the subscription has access to both the source and destination/target Azure subscriptions.
- Assumption that the resource group name is the same for both subscriptions (source and target).
- Steps 1 and 2 are expected to already be completed.
- For step 3, use Remote Desktop (RDP) to access the VM and Sysprep /generalize the VM. Then proceed with step 3 below.
#>

$sourceSubscriptionId = '{YOUR-SOURCE-AZURE-SUBSCRIPTION-ID}'
$destinationSubscriptionId = '{YOUR-DESTINATION-AZURE-SUBSCRIPTION-ID}'
$tenantId = '{YOUR-AZURE-AD-TENANT-ID}'
$resourceGroup = 'mcollier-myimages'
$region = 'northcentralus'
$servicePrincipalName = 'https://localhost/azure-image-copy'

$vmName = 'mcolliervm1'
$imageName = "mcollierimage001"

<# -- OPTIONAL - Create a new Service Principal -- #>
<#
# Login with interactive authentication to create the Service Principal
Login-AzureRmAccount -SubscriptionId $sourceSubscriptionId

# Ensure resource group is created in both subscriptions
$myTags = @{}
$myTags.Add("alias", "mcollier")
$myTags.Add("deleteAfter", "04/30/2017")
New-AzureRmResourceGroup -Name $resourceGroup -Location $region -Tag $myTags -Force

Select-AzureRmSubscription -SubscriptionId $destinationSubscriptionId
New-AzureRmResourceGroup -Name $resourceGroup -Location $region -Tag $myTags -Force

Select-AzureRmSubscription -SubscriptionId $sourceSubscriptionId

$sp_pwd = Read-Host -Prompt "Enter password for service principal."
.\create_service_principal.ps1 -sourceSubscriptionId $sourceSubscriptionId `
                               -destinationSubscriptionId $destinationSubscriptionId `
                               -resourceGroupName $resourceGroup `
                               -servicePrincipalName $servicePrincipalName `
                               -servicePrincipalPassword $sp_pwd
#>

<# -- OPTIONAL - Create a new VM --#>
<#
# Login with interactive authentication to create the Service Principal
Login-AzureRmAccount -SubscriptionId $sourceSubscriptionId

$vmPwd = Read-Host -Prompt "Enter password for VM." -AsSecureString
.\create-new-vm.ps1 -subscriptionId $sourceSubscriptionId `
                    -resourceGroupName $resourceGroup `
                    -region $region `
                    -vmName $vmName`
                    -vmAdminUsername 'mcollier' `
                    -vmAdminPassword $vmPwd 

# TODO: RDP into the VM and make it your own.
# TODO: From within VM, run Sysprep, generalize and shut down the VM.

# Sysprep / generalize the VM.
Stop-AzureRmVM -Name $vmName -ResourceGroupName $resourceGroupName -Force
Set-AzureRmVM -ResourceGroupName $resourceGroupName -Name $vmName -Generalized

#>

<# -- OPTIONAL - Create a Managed Disk Image if necessary --#>
<#
$vm = Get-AzureRmVM -ResourceGroupName $resourceGroupName -Name $vmName
$image = New-AzureRmImageConfig -Location $region -SourceVirtualMachineId $vm.Id
New-AzureRmImage -Image $image -ImageName $imageName -ResourceGroupName $resourceGroupName
#>

<# -- Run under the context of a Service Principal -- #>
#$sp_pwd = Read-Host -Prompt "Enter password for service principal." -AsSecureString
$pwd = "test!123"
$sp_pwd = ConvertTo-SecureString $pwd -AsPlainText -Force
$secureCredential = New-Object System.Management.Automation.PSCredential($servicePrincipalName, $sp_pwd)
Login-AzureRmAccount -Credential $secureCredential -SubscriptionId $sourceSubscriptionId -TenantId $tenantId -ServicePrincipal

& '.\copy-managed-disk-image.ps1' -sourceSubscriptionId $sourceSubscriptionId `
                                  -destinationSubscriptionId $destinationSubscriptionId `
                                  -resourceGroupName $resourceGroup `
                                  -sourceRegion $region `
                                  -destinationRegion $region `
                                  -imageName $imageName `
                                  -vmName $vmName `
                                  -servicePrincipalName $servicePrincipalName `
                                  -servicePrincipalPassword $sp_pwd
