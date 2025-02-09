param(
    [Parameter(Mandatory = $true)][string] $subscriptionID = "",
    [Parameter(Mandatory = $true)][ValidateSet("northeurope", "westeurope")][string] $location = "", 
    [ValidateSet("avd")][string][Parameter(Mandatory = $true, ParameterSetName = 'Default')] $productType = "",
    [Parameter(Mandatory = $true, Position = 3)] [validateSet("prod", "acc", "dev", "test")] [string] $environmentType = "",
    [switch] $deploy
)

# Ensure parameters are captured
Write-Host "Subscription ID: $subscriptionID"
Write-Host "Location: $location"
Write-Host "Product Type: $productType"
Write-Host "Environment Type: $environmentType"

$deploymentID = (New-Guid).Guid

<# Set Variables #>
az account set --subscription $subscriptionID --output none
if (!$?) {
    Write-Host "Something went wrong while setting the correct subscription. Please check and try again." -ForegroundColor Red
}


$updatedBy = (az account show | ConvertFrom-Json).user.name 
$location = $location.ToLower() -replace " ", ""

$LocationShortCodeMap = @{
    "westeurope"  = "weu";
    "northeurope" = "neu";
}

$locationShortCode = $LocationShortCodeMap.$location

if ($deploy) {
    Write-Host "Running a Bicep deployment with ID: '$deploymentID' for Environment: '$environmentType' with a 'WhatIf' check." -ForegroundColor Green
    az deployment sub create `
    --name $deploymentID `
    --location $location `
    --template-file ./sessionhost-config.bicep `
    --parameters ./sessionhost-config.bicepparam `
    --parameters updatedBy=$updatedBy location=$location locationShortCode=$LocationShortCode productType=$productType environmentType=$environmentType `
    --confirm-with-what-if `

    if ($?) {
        Write-Host "Bicep deployment completed successfully. Proceeding with WVD Host Pool creation..." -ForegroundColor Green

        $resourceGroupName = "rg-$productType-$environmentType-$locationShortCode"
        $hostPoolName = "vdpool-conf-$productType-$environmentType-$locationShortCode"
        $workspaceName = "vdws-conf-$productType-$environmentType-$locationShortCode"
        $applicationGroupName = "vdag-conf-$productType-$environmentType-$locationShortCode"
        
        $vaultName = "kv-conf-$productType-$environmentType-$locationShortCode"
        $vnetName = "vnet-$productType-$environmentType-$locationShortCode"
        $subnetName = "snet-$productType"

        # Create Host Pool  
        $parameters = @{
            Name                  = $hostPoolName
            ResourceGroupName     = $resourceGroupName
            ManagementType        = "Automated"
            StartVMOnConnect      = $true
            HostPoolType          = "Pooled"
            PreferredAppGroupType = "Desktop"
            LoadBalancerType      = "BreadthFirst"
            MaxSessionLimit       = 10
            Location              = $location
        }

        Write-Host "Creating AVD Host Pool..." -ForegroundColor Green        
        New-AzWvdHostPool @parameters

        # Retrieve Host Pool ARM Path  
        $hostPoolArmPath = (Get-AzWvdHostPool -Name $hostPoolName -ResourceGroupName $resourceGroupName).Id  

        # Create Workspace  
        $parameters = @{
            Name              = $workspaceName
            ResourceGroupName = $resourceGroupName
            Location         = $location
        }

        Write-Host "Creating AVD Workspace..." -ForegroundColor Green
        New-AzWvdWorkspace @parameters

        # Create Application Group  
        $parameters = @{
            Name                = $applicationGroupName
            ResourceGroupName   = $resourceGroupName
            ApplicationGroupType = 'Desktop'
            HostPoolArmPath     = $hostPoolArmPath
            Location           = $location
        }

        Write-Host "Creating AVD Application Group..." -ForegroundColor Green
        New-AzWvdApplicationGroup @parameters
        if ($?) {
            Write-Host "AVD Host Pool with workspace and applicationgroup created successfully!" -ForegroundColor Green
            
            # Define App Registration Object ID
            $appObjectId = "d730c208-a053-4e89-bcac-9e3ad29764f1"
        
            # Get the deployer's Object ID
            $deployerObjectId = (Get-AzADUser -SignedIn).Id  # For user account  
            Write-Host "Deployer Object ID: $deployerObjectId"
                
            # Define scope for the Contributor role assignment (Resource Group)
            $rgScope = "/subscriptions/$subscriptionID/resourceGroups/$resourceGroupName"
            Write-Host "Resource Group Scope: $rgScope"
        
            # Define scope for the Key Vault Secrets Officer role assignment (Key Vault)
            $keyVaultScope = "/subscriptions/$subscriptionID/resourceGroups/$resourceGroupName/providers/Microsoft.KeyVault/vaults/$vaultName"
            Write-Host "Key Vault Scope: $keyVaultScope"
        
            # Assign Contributor Role to the App Registration if not already assigned
            $existingContributor = Get-AzRoleAssignment -ObjectId $appObjectId -RoleDefinitionName "Contributor" -Scope $rgScope
            if ($existingContributor) {
                Write-Host "Contributor role is already assigned to the App Registration. No action needed." -ForegroundColor Green
            } else {
                Write-Host "Assigning Contributor role to the App Registration on Resource Group: $resourceGroupName" -ForegroundColor Yellow
                
                New-AzRoleAssignment -ObjectId $appObjectId -RoleDefinitionName "Contributor" -Scope $rgScope
                
                if ($?) {
                    Write-Host "Contributor role assignment completed successfully!" -ForegroundColor Green
                } else {
                    Write-Host "Failed to assign Contributor role." -ForegroundColor Red
                }
            }
        
            # Assign Key Vault Secrets User to App Registration if not already assigned
            $existingKVRole = Get-AzRoleAssignment -ObjectId $appObjectId -RoleDefinitionName "Key Vault Secrets User" -Scope $keyVaultScope
            if ($existingKVRole) {
                Write-Host "Key Vault Secrets User role is already assigned to the App Registration. No action needed." -ForegroundColor Green
            } else {
                Write-Host "Assigning Key Vault Secrets Officer role to App Registration on Key Vault: $vaultName" -ForegroundColor Yellow
                
                New-AzRoleAssignment -ObjectId $appObjectId -RoleDefinitionName "Key Vault Secrets User" -Scope $keyVaultScope
                
                if ($?) {
                    Write-Host "Key Vault Secrets User role assignment completed successfully!" -ForegroundColor Green
                } else {
                    Write-Host "Failed to assign Key Vault Secrets User role." -ForegroundColor Red
                }
            }
        
            # Assign Key Vault Secrets User to the Deployer (Current User)
            $existingDeployerKVRole = Get-AzRoleAssignment -ObjectId $deployerObjectId -RoleDefinitionName "Key Vault Secrets User" -Scope $keyVaultScope
            if ($existingDeployerKVRole) {
                Write-Host "Key Vault Secrets User role is already assigned to the deployer. No action needed." -ForegroundColor Green
            } else {
                Write-Host "Assigning Key Vault Secrets User role to the Deployer on Key Vault: $vaultName" -ForegroundColor Yellow
                
                New-AzRoleAssignment -ObjectId $deployerObjectId -RoleDefinitionName "Key Vault Secrets User" -Scope $keyVaultScope
                
                if ($?) {
                    Write-Host "Key Vault Secrets User role assignment for deployer completed successfully!" -ForegroundColor Green
                } else {
                    Write-Host "Failed to assign Key Vault Secrets User role to deployer." -ForegroundColor Red
                }
            }
        }
        
                # Deploy Session Hosts
                $parameters = @{
                    FriendlyName                                = "avd-$environmentType"
                    HostPoolName                               = $hostPoolName
                    ResourceGroupName                          = $resourceGroupName
                    VMNamePrefix                               = "avd-$environmentType"
                    VMLocation                                 = $location
                    SecurityInfoType                           = "TrustedLaunch"	
                    ImageInfoImageType                         = "Custom"
                    CustomInfoResourceID                       = "/subscriptions/$subscriptionID/resourceGroups/$resourceGroupName/providers/Microsoft.Compute/galleries/galavdprodweu/images/img-avd-prod-weu/versions/2025.01.18"
                    VMSizeId                                   = "Standard_D2s_v5"
                    DiskInfoType                               = "Premium_LRS"
                    NetworkInfoSubnetId                        = "/subscriptions/$subscriptionID/resourceGroups/$resourceGroupName/providers/Microsoft.Network/virtualNetworks/$vnetName/subnets/$subnetName"
                    DomainInfoJoinType                         = "ActiveDirectory"
                    ActiveDirectoryInfoDomainName              = "poffers.cloud"
                    DomainCredentialsUsernameKeyVaultSecretUri = "https://$vaultName.vault.azure.net/secrets/DomainAdminUser"
                    DomainCredentialsPasswordKeyVaultSecretUri = "https://$vaultName.vault.azure.net/secrets/DomainAdminPass"
                    VMAdminCredentialsUsernameKeyVaultSecretUri = "https://$vaultName.vault.azure.net/secrets/VMAdminUser"
                    VMAdminCredentialsPasswordKeyVaultSecretUri = "https://$vaultName.vault.azure.net/secrets/VMAdminPass"
                }

                Write-Host "Deploying session host configuration" -ForegroundColor Green
                New-AzWvdSessionHostConfiguration @parameters

                if ($?) {
                    Write-Host "Session host configuration deployed successfully!" -ForegroundColor Green
                } else {
                    Write-Host "Failed to deploy session host configuration." -ForegroundColor Red
                }

            } else {
                Write-Host "Failed to assign role." -ForegroundColor Red
            }

        } else {
            Write-Host "Failed to create AVD Host Pool." -ForegroundColor Red
        }
        
