using 'sessionhost-config.bicep'
//Parameters for the deployment.
param updatedBy = 'yourname'
param subscriptionId = ''
param environmentType = 'prod' 
param location = 'westeurope' 
param locationShortCode = 'weu' 
param productType = 'avd'

//Parameters for the existing resource group.
param existingResourceGroupName = 'rg-${productType}-${environmentType}-${locationShortCode}'

//Parameters for the Key Vault 
param keyVaultName = 'kv-conf-${productType}-${environmentType}-${locationShortCode}'
param domainAdminPass = 'Ditis33nTest!'
param domainAdminUser = 'ladm_vmjoin'
param vmadminPass = 'kdkddk$$1222!!!D'
param vmAdminUser = 'ladm_admmm'


