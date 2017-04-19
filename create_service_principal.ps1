Param(
    [string] $sourceSubscriptionId,
    [string] $destinationSubscriptionId,
    [string] $resourceGroupName,
    [string] $servicePrincipalName,
    [string] $servicePrincipalPassword
)

# Create a new Azure AD application
$azureAdApplication = New-AzureRmADApplication `
                        -DisplayName "My Azure Image Copy Process" `
                        -HomePage $servicePrincipalName `
                        -IdentifierUris $servicePrincipalName `
                        -Password $servicePrincipalPassword

# Create a new service principal associated with the designated application
New-AzureRmADServicePrincipal -ApplicationId $azureAdApplication.ApplicationId

#wait wait . . . gives time for service principal creation to complete
Start-Sleep 15

# Assign Reader role to the newly created service principal. Both subscriptions below are associated with the same Azure AD tenant.
New-AzureRmRoleAssignment -RoleDefinitionName Reader `
                          -ServicePrincipalName $azureAdApplication.ApplicationId.Guid

New-AzureRmRoleAssignment -RoleDefinitionName Contributor `
                          -ServicePrincipalName $azureAdApplication.ApplicationId.Guid `
                          -Scope "/subscriptions/${sourceSubscriptionId}/resourceGroups/${resourceGroupName}"

New-AzureRmRoleAssignment -RoleDefinitionName Contributor `
                          -ServicePrincipalName $azureAdApplication.ApplicationId.Guid `
                          -Scope "/subscriptions/${destinationSubscriptionId}/resourceGroups/${resourceGroupName}"
