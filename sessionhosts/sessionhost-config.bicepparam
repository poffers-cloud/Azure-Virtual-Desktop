using 'sessionhost-config.bicep'
//Parameters for the deployment.
param updatedBy = 'yourname'
param subscriptionId = '6bc2a89b-8ffc-4c4a-8973-83d75a65f7c4'
param environmentType = 'prod' 
param location = 'westeurope' 
param locationShortCode = 'weu' 
param productType = 'avd'

//Parameters for the existing resource group.
param existingResourceGroupName = 'rg-${productType}-${environmentType}-${locationShortCode}'

//parameters for the existing subscription.
param existingSubscriptionId = '6bc2a89b-8ffc-4c4a-8973-83d75a65f7c4'

//Parameters for the Key Vault 
param keyVaultName = 'kv-sessionhost-${productType}-${environmentType}-${locationShortCode}'
param domainAdminPass = 'Ditis33nTest!'
param domainAdminUser = 'ladm_vmjoiner'
param vmadminPass = '222!!!GGGdkldkdcc'
param vmAdminUser = 'ladm_admpof'


