#!/bin/bash

#Azure Subscription variables
SubscriptionID="{your-azure-subscription-id}"
ResourceGroupName="myimages"
ResourceGroupNameTemp="my-vm-temp"
TargetSubscriptionID="{your-other-azure-subscription-id}"

imageName="my-vm-image-1"
location="northcentralus"
snapshotName="$imageName-$location-snap"
imageStorageContainerName="images"
targetStorageAccountName="myimageswestcentus"
targetLocation="westcentralus"

az login

echo "Changing subscription to $SubscriptionID"
az account set --subscription $SubscriptionID
#az account show

# ------ Create an image ------
# Get the ID for the VM.
#vmid=$(az vm show -g $ResourceGroupName -n vm --query "id" -o tsv)

#VMID=$(az vm list -g mcollier-managed-image --query "[?contains(name, 'vm')].{ VMID:id }" -o tsv)

#echo "The VM ID is $vmid"

# Create the image.
#az image create -g $ResourceGroupName \
#	--name $imageName \
#	--location $location \
#	--os-type Windows \
#	--source $vmid


# ------ Create an snapshot ------
#diskName=$(az vm show -g $ResourceGroupName -n vm --query "storageProfile.osDisk.name" -o tsv)
#az snapshot create -g $ResourceGroupName -n $snapshotName --location $location --source	$diskName


# ------ Copy the snapshot to another Azure subscription ------
#set the source subscription (to be sure)
#az account set --subscription $SubscriptionID
#snapshotId=$(az snapshot show -g $ResourceGroupName -n $snapshotName --query "id" -o tsv )

#echo "SnapshotId is $snapshotId"

# change to the target subscription
#az account set --subscription $TargetSubscriptionID
#az snapshot create -g $ResourceGroupName -n $snapshotName --source $snapshotId



# ----- Copy the snapshot to another region, same subscription
#set the source subscription (to be sure)
#az account set --subscription $SubscriptionID
#snapshotId=$(az snapshot show -g $ResourceGroupName -n $snapshotName --query "id" -o tsv )

#echo "SnapshotId is $snapshotId"

# Get the SAS for the snapshotId
#snapshotSasUrl=$(az snapshot grant-access -g $ResourceGroupName -n $snapshotName --duration-in-seconds 3600 -o tsv)
#echo "Snapshot SAS URL is $snapshotSasUrl"

# Setup the target storage account in another region
#targetStorageAccountKey=$(az storage account keys list -g $ResourceGroupName --account-name $targetStorageAccountName --query "[:1].value" -o tsv)
#echo "Target storage account key is $targetStorageAccountKey"

#storageSasToken=$(az storage account generate-sas --expiry 2017-05-02'T'12:00'Z' --permissions aclrpuw --resource-types sco --services b --https-only --account-name $targetStorageAccountName --account-key $targetStorageAccountKey -o tsv)
#echo "Target storage SAS URL is $storageSasToken"

#az storage container create -n $imageStorageContainerName --account-name $targetStorageAccountName --sas-token $storageSasToken

# Copy the snapshot to the target region using the SAS URL
#imageBlobName = "$imageName-osdisk.vhd"
#copyId=$(az storage blob copy start --source-uri $snapshotSasUrl --destination-blob $imageBlobName --destination-container $imageStorageContainerName --sas-token $storageSasToken --account-name $targetStorageAccountName)

# Figure out when the copy is destination-container
# TODO: Put this in a loop until status is 'success'
#az storage blob show --container-name $imageStorageContainerName -n $imageBlobName --account-name $targetStorageAccountName --sas-token $storageSasToken --query "properties.copy.status"

# Get the URI to the blob

#blobEndpoint=$(az storage account show -g $ResourceGroupName -n $targetStorageAccountName --query "primaryEndpoints.blob" -o tsv)
#osDiskVhdUri="$blobEndpoint$imageStorageContainerName/$imageBlobName"

#echo "VHD OS Disk Url is $osDiskVhdUri"

# Create the snapshot in the target region
#snapshotName="$imageName-$targetLocation-snap"
#az snapshot create -g $ResourceGroupName -n $snapshotName -l $targetLocation --source $osDiskVhdUri




# ----- Copy the snapshot to another region, DIFFERENT subscription
#set the source subscription (to be sure)
#targetStorageAccountName="myimageswestcentus3"
#az account set --subscription $SubscriptionID
#snapshotId=$(az snapshot show -g $ResourceGroupName -n $snapshotName --query "id" -o tsv )

#echo "SnapshotId is $snapshotId"

# Get the SAS for the snapshotId
#snapshotSasUrl=$(az snapshot grant-access -g $ResourceGroupName -n $snapshotName --duration-in-seconds 3600 -o tsv)
#echo "Snapshot SAS URL is $snapshotSasUrl"

# Switch to the DIFFERENT subscription
#az account set --subscription $TargetSubscriptionID

# Setup the target storage account in another region
#targetStorageAccountKey=$(az storage account keys list -g $ResourceGroupName --account-name $targetStorageAccountName --query "[:1].value" -o tsv)
#echo "Target storage account key is $targetStorageAccountKey"

#storageSasToken=$(az storage account generate-sas --expiry 2017-05-02'T'12:00'Z' --permissions aclrpuw --resource-types sco --services b --https-only --account-name $targetStorageAccountName --account-key $targetStorageAccountKey -o tsv)
#echo "Target storage SAS URL is $storageSasToken"

#az storage container create -n $imageStorageContainerName --account-name $targetStorageAccountName --sas-token $storageSasToken

# Copy the snapshot to the target region using the SAS URL
#imageBlobName = "$imageName-osdisk.vhd"
#copyId=$(az storage blob copy start --source-uri $snapshotSasUrl --destination-blob $imageBlobName --destination-container $imageStorageContainerName --sas-token $storageSasToken --account-name $targetStorageAccountName)

# Figure out when the copy is destination-container
# TODO: Put this in a loop until status is 'success'
#az storage blob show --container-name $imageStorageContainerName -n $imageBlobName --account-name $targetStorageAccountName --sas-token $storageSasToken --query "properties.copy.status"

# Get the URI to the blob
#blobEndpoint=$(az storage account show -g $ResourceGroupName -n $targetStorageAccountName --query "primaryEndpoints.blob" -o tsv)
#osDiskVhdUri="$blobEndpoint$imageStorageContainerName/$imageBlobName"

#echo "VHD OS Disk Url is $osDiskVhdUri"

# Create the snapshot in the target region
#snapshotName="$imageName-$targetLocation-snap"
#az snapshot create -g $ResourceGroupName -n $snapshotName -l $targetLocation --source $osDiskVhdUri


# ------ Create an image from the snapshot ------
#az account set --subscription $TargetSubscriptionID
#snapshotId=$(az snapshot show -g $ResourceGroupName -n $snapshotName --query "id" -o tsv )
#az image create -g $ResourceGroupName -n $imageName -l $location --os-type Windows --source $snapshotId


# ------ Create a temporary VM ------
#vmName="myvm"
#user="mcollier"
#pwd="test!123456789"
#dnsPrefix="myvm04272017"

#az group create -l $location -n $ResourceGroupTempName
#imageId=$(az image show -g mcollier-managed-image -n image2 --query "id")
#az group deployment create -g resourceGroupTempName \
#	--template-uri https://raw.githubusercontent.com/mcollier/copy-azure-managed-disk-images/master/azuredeploy.json \
#	--parameters "{\"vmName\":{\"value\": \"$vmName\"}, \"adminUsername\":{\"value\": \"$user\"}, \"adminPassword\":{\"value\": \"$pwd\"}, \"dnsLabelPrefix\":{\"value\": \"$dnsPrefix\"}, \"managedImageResourceId\":{\"value\": \"$imageId\"}}"


# ------ Delete the snapshot ------
#az snapshot delete -g $ResourceGroupName -n $snapshotName


# ------ Delete the resource group ------
#az group delete -n $ResourceGroupName
