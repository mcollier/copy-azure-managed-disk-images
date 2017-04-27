#!/bin/bash

#Azure Subscription variables
ClientID="{your-client-id}" #ApplicationID
ClientSecret="{your-client-secret}"  #key from Application
TennantID="{your-azuread-tenantid}"
SubscriptionID="{your-azure-subscription-id}"
ResourceGroupName="myimages"
ResourceGroupName="my-vm-temp"
TargetSubscriptionID="{your-other-azure-subscription-id}"

imageName="my-vm-image-1"
location="northcentralus"
snapshotName="my-vm-image-1-$location-snap"

#az login --service-principal \
#	-u $ClientID \
#	--password $ClientSecret \
#	--tenant $TennantID

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