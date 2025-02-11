targetScope = 'subscription'

param updatedBy string 

@allowed([
  'test'
  'dev'
  'prod'
  'acc'
])
param environmentType string 

param subscriptionId string 

@description('Unique identifier for the deployment')
param deploymentGuid string = newGuid()

@description('Product Type: example avd.')
@allowed([
  'avd'
  ])
param productType string

@description('Azure Region to deploy the resources in.')
@allowed([
  'westeurope'
  'northeurope'
  
])
param location string = 'westeurope'
@description('Location shortcode. Used for end of resource names.')
param locationShortCode string 

@description('Add tags as required as Name:Value')
param tags object = {
  Environment: environmentType
  LastUpdatedOn: utcNow('d')
  LastDeployedBy: updatedBy
}

//parameters for the existing resource group.
param existingResourceGroupName string 

//parameters for the Key Vault.
param keyVaultName string

@description('The Entra Id App Secret of the Service Principal')
@secure()
param domainAdminUser string

@description('The Entra Id App Secret of the Service Principal')
@secure()
param domainAdminPass string

@description('The Entra Id App Secret of the Service Principal')
@secure()
param vmAdminUser string

@description('The Entra Id App Secret of the Service Principal')
@secure()
param vmadminPass string


module createKeyVault 'br/public:avm/res/key-vault/vault:0.11.2' = {
  scope: resourceGroup(existingResourceGroupName)
  name: 'kv-${deploymentGuid}'
  params:{
    name: keyVaultName
    secrets: [
      {
        name: 'DomainAdminUser'
        value: domainAdminUser
     
      }
      {
        name: 'DomainAdminPass'
        value: domainAdminPass
     
      }
      {
        name: 'VMAdminUser'
        value: vmAdminUser
     
      }
      {
        name: 'VMAdminPass'
        value: vmadminPass
     
      }
    ]
    enablePurgeProtection: false
    location: location
    tags: tags
  }

}

