Param(
    [string] $subscriptionId,
    [string] $resourceGroupName,
    [string] $region,
    [string] $vmName,
    [string] $vmAdminUsername,
    [securestring] $vmAdminPassword
)

# ARM template used to create the initial VM
$templateUri = 'https://raw.githubusercontent.com/Azure/azure-quickstart-templates/master/101-vm-with-rdp-port/azuredeploy.json'

$dnsPrefix = $vmName + "-" + -join ((97..122) | Get-Random -Count 7 | % {[char]$_})

$currentDate = Get-Date -Format yyyyMMdd.HHmmss
$deploymentLabel = "vmdeploy-$currentDate"

$templateParams = @{dnsLabelPrefix = $dnsPrefix; vmName = $vmName; adminUserName = $vmAdminUsername; adminPassword = $vmAdminPassword; rdpPort = 3389}
New-AzureRmResourceGroupDeployment -ResourceGroupName $resourceGroupName `
                                   -Name $deploymentLabel `
                                   -TemplateUri $templateUri `
                                   -TemplateParameterObject $templateParams `
                                   -Verbose
                                  
