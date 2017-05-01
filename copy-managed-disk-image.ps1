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





