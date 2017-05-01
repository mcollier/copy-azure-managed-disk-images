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

$vmName = 'mcolliervm1'
$imageName = "mcollierimage001"

<# -- Login with an interactive session. - #>
# Login-AzureRmAccount -SubscriptionId $sourceSubscriptionId

<# -- OPTIONAL - Create the source and target resource groups in both subscriptions. -- #>
$myTags = @{}
$myTags.Add("alias", "mcollier")
$myTags.Add("deleteAfter", "04/30/2017")
New-AzureRmResourceGroup -Name $resourceGroup -Location $region -Tag $myTags -Force

Select-AzureRmSubscription -SubscriptionId $destinationSubscriptionId
New-AzureRmResourceGroup -Name $resourceGroup -Location $region -Tag $myTags -Force


<# -- OPTIONAL - Create a new VM --#>
<#
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


$snapshotName = $imageName + $sourceRegion + "-snap"


# ----- 5. Create a snapshot of the OS (and optionally data disks) from the generalized VM -----
# TODO - SUPPORT DATA DISKS
$vm = Get-AzureRmVM -ResourceGroupName $resourceGroupName -Name $vmName
$disk = Get-AzureRmDisk -ResourceGroupName $resourceGroupName -DiskName $vm.StorageProfile.OsDisk.Name
$snapshot = New-AzureRmSnapshotConfig -SourceUri $disk.Id -CreateOption Copy -Location $sourceRegion

New-AzureRmSnapshot -ResourceGroupName $resourceGroupName -Snapshot $snapshot -SnapshotName $snapshotName


# ----- 6. Copy the snapshot to the second subscription -----
$snap = Get-AzureRmSnapshot -ResourceGroupName $resourceGroupName -SnapshotName $snapshotName

Select-AzureRmSubscription -SubscriptionId $targetSubscriptionId
$snapshotConfig = New-AzureRmSnapshotConfig -OsType Windows `
                                            -Location $region `
                                            -CreateOption Copy `
                                            -SourceResourceId $snap.Id

$snap = New-AzureRmSnapshot -ResourceGroupName $resourceGroupName `
                            -SnapshotName $snapshotName `
                            -Snapshot $snapshotConfig    


# ----- 7. In the second subscription, create a new Image from the copied snapshot -----
Select-AzureRmSubscription -SubscriptionId $destinationSubscriptionId

$snap = Get-AzureRmSnapshot -ResourceGroupName $resourceGroupName -SnapshotName $snapshotName

$imageConfig = New-AzureRmImageConfig -Location $destinationRegion
 
Set-AzureRmImageOsDisk -Image $imageConfig `
                        -OsType Windows `
                        -OsState Generalized `
                        -SnapshotId $snap.Id
 
New-AzureRmImage -ResourceGroupName $resourceGroupName `
                 -ImageName $imageName `
                 -Image $imageConfig

(Get-AzureRmImage -ResourceGroupName $resourceGroupName) | Select-Object Name, Location, ProvisioningState


# ----- 8. In the second subscription, create a new VM from the new Image. -----
$currentDate = Get-Date -Format yyyyMMdd.HHmmss
$deploymentLabel = "vmimage-$currentDate"

$image = Get-AzureRmImage -ResourceGroupName $resourceGroupName -ImageName $imageName

$dnsPrefix = "myvm-" + -join ((97..122) | Get-Random -Count 7 | ForEach-Object {[char]$_})

$creds = Get-Credential -Message "Enter username and password for new VM."

$templateParams = @{
    vmName = $vmName; 
    adminUserName = $creds.UserName; 
    adminPassword = $creds.Password; 
    dnsLabelPrefix = $dnsPrefix
    managedImageResourceId = $image.Id
}

# Put the dummy VM in a separate resource group as it makes it super easy to clean up all the extra stuff that goes with a VM (NIC, IP, VNet, etc.)
$rgNameTemp = $resourceGroupName + "-temp"
New-AzureRmResourceGroup -Location $region `
                         -Name $rgNameTemp

New-AzureRmResourceGroupDeployment  -Name $deploymentLabel `
                                    -ResourceGroupName $rgNameTemp `
                                    -TemplateParameterObject $templateParams `
                                    -TemplateUri 'https://raw.githubusercontent.com/mcollier/copy-azure-managed-disk-images/master/azuredeploy.json' `
                                    -Verbose
                                    

# ----- 9. Delete the snapshot in the second subscription -----
Remove-AzureRmSnapshot -ResourceGroupName $resourceGroupName -SnapshotName $snapshotName -Force


# ----- 10. Delete the VM created in step 8. -----
Remove-AzureRmResourceGroup -Name $rgNameTemp -Force


# ----- 11. Switch back to the source (original) subscription and delete the original snapshot. -----
Select-AzureRmSubscription -SubscriptionId $sourceSubscriptionId
Remove-AzureRmSnapshot -ResourceGroupName $resourceGroupName -SnapshotName $snapshotName