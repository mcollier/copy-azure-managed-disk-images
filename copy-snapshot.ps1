Param(
    [string] $subscriptionId, #destination/target subscription
    [securestring] $servicePrincipalPassword,
    [string] $snapshotName,
    [string] $resourceGroupName,
    [string] $region, #destination - needs to be the same region as the source (currently). TODO: Fix this.
    [string] $sourceSnapshotId
)

# Azure Powershell modules do not yet have the capability to copy Managed Disk snapshots across subscriptions.
# Use the Azure management REST API instead.
# See https://docs.microsoft.com/en-us/rest/api/manageddisks/snapshots/snapshots-create-or-update


# Get credentials to an Azure AD service principal, which is used to get an authentication token for authenticating with the Azure management REST API
$result = Invoke-RestMethod -Uri "https://login.microsoftonline.com/${tenantId}/oauth2/token?api-version=1.0" `
                  -Method Post `
                  -Body @{
    "grant_type" = "client_credentials"; 
    "resource" = "https://management.core.windows.net/";
    "client_id" = "${servicePrincipalName}";
    "client_secret" = "${pwd}"
}

# Build an array of HTTP header values
$authHeader = @{
    'Content-Type' = 'application/json'
    'Accept' = 'application/json'
    'Authorization' = 'Bearer ' + $result.access_token
}

$apiVersion = "2016-04-30-preview"
$request = "https://management.azure.com/subscriptions/${subscriptionId}/resourceGroups/" + `
            "${resourceGroupName}/providers/Microsoft.Compute/snapshots/${snapshotName}?api-version=${apiVersion}"

$requestBody = @"
{ 
  "name": "${snapshotName}",
  "location": "$region",
  "properties": { 
    "creationData": { 
    "createOption": "Copy", 
    "sourceResourceId": "${sourceSnapshotId}" 
    }
  } 
}
"@

Invoke-RestMethod -Uri $request `
                  -Headers $authHeader `
                  -Method PUT `
                  -Body $requestBody `
                  -Verbose