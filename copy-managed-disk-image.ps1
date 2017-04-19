Param(
    [string] $sourceSubscriptionId,
    [string] $destinationSubscriptionId,
    [string] $resourceGroupName,
    [string] $imageName,
    [string] $sourceRegion,
    [string] $destinationRegion,
    [string] $vmName,
    [string] $servicePrincipalName,
    [securestring] $servicePrincipalPassword
)

$snapshotName = $imageName + $sourceRegion + "-snap"


# ----- 5. Create a snapshot of the OS (and optionally data disks) from the generalized VM -----
# TODO - SUPPORT DATA DISKS
$vm = Get-AzureRmVM -ResourceGroupName $resourceGroupName -Name $vmName
$disk = Get-AzureRmDisk -ResourceGroupName $resourceGroupName -DiskName $vm.StorageProfile.OsDisk.Name
$snapshot = New-AzureRmSnapshotConfig -SourceUri $disk.Id -CreateOption Copy -Location $sourceRegion

New-AzureRmSnapshot -ResourceGroupName $resourceGroupName -Snapshot $snapshot -SnapshotName $snapshotName


# ----- 6. Copy the snapshot to the second subscription -----
# Azure Powershell modules do not yet have the capability to copy Managed Disk snapshots across subscriptions.
# Use the Azure management REST API instead.
# See https://docs.microsoft.com/en-us/rest/api/manageddisks/snapshots/snapshots-create-or-update

$snap = Get-AzureRmSnapshot -ResourceGroupName $resourceGroupName -SnapshotName $snapshotName
.\copy-snapshot.ps1 -subscriptionId $destinationSubscriptionId `
                    -servicePrincipalIdentifierUri $servicePrincipalName `
                    -servicePrincipalPassword $servicePrincipalPassword `
                    -snapshotName $snapshotName `
                    -resourceGroupName $resourceGroupName `
                    -region $destinationRegion `
                    -sourceSnapshotId $snap.Id


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

$dnsPrefix = "myvm-" + -join ((97..122) | Get-Random -Count 7 | % {[char]$_})

$creds = Get-Credential -Message "Enter username and password for new VM."

$templateParams = @{
    vmName = $vmName; 
    adminUserName = $creds.UserName; 
    adminPassword = $creds.Password; 
    dnsLabelPrefix = $dnsPrefix
    managedImageResourceId = $image.Id
}

# Put the dummy VM in a seperate resource group as it makes it super easy to clean up all the extra stuff that goes with a VM (NIC, IP, VNet, etc.)
$rgNameTemp = $resourceGroupName + "-temp"
New-AzureRmResourceGroup -Location $region `
                         -Name $rgNameTemp

New-AzureRmResourceGroupDeployment  -Name $deploymentLabel `
                                    -ResourceGroupName $rgNameTemp `
                                    -TemplateParameterObject $templateParams `
                                    -TemplateUri 'https://raw.githubusercontent.com/mcollier/copy-azure-managed-disk-images/master/azuredeploy.json' `
                                    -Verbose
                                    
# TODO: Submit template to Azure QuickStart Template gallery? Create a Managed Disk VM from a Managed Disk Image. 

# ----- 9. Delete the snapshot in the second subscription -----
Remove-AzureRmSnapshot -ResourceGroupName $resourceGroupName -SnapshotName $snapshotName -Force

# ----- 10. Delete the VM created in step 8. -----
Remove-AzureRmResourceGroup -Name $rgNameTemp -Force

# ----- 11. Switch back to the source (original) subscription and delete the original snapshot. -----
Select-AzureRmSubscription -SubscriptionId $sourceSubscriptionId
Remove-AzureRmSnapshot -ResourceGroupName $resourceGroupName -SnapshotName $snapshotName





