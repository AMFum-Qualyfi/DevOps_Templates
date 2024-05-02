targetScope = 'resourceGroup'

@description('The environment to deploy')
@allowed([
  'dev'
  'pre'
  'prod'
])
param environmentType string

// @description('Location.')
// param location string = 'uksouth'

// Load the staticConfig.json file
// Unable to have a dedicated environmentType config
// Path has to be a string literal and not a variable
var staticConfig = loadJsonContent('./staticConfig.json')
var environmentMap = staticConfig[environmentType]
var serverRolesList = [ for entity in items(environmentMap.servers):entity.key]


module virtualMachine './modules/virtualMachines/virtualMachines.bicep' = [for serverRole in serverRolesList: {
  name: '${serverRole}-virtualMachines-Deploy'
  params: {
    environmentType: environmentType
    applicationName: applicationName
    appSubnet: subnetApp.id
    avModeEnabled: false
    avSetName: ''
    dataDiskSize: serverRole == 'sql' || serverRole == '' ? environmentMap.servers[serverRole].dataDiskSize : environmentMap.servers[serverRole].dataDiskSize
    dataSubnet: subnetData.id
    domainJoined: domainJoined
    domainName: environmentMap.domainName
    ouPath: environmentMap.ouPath
    domainPasswd: domainPasswd
    domainUser: domainUser
    envName: envName
    kvName: kvName
    applicationSecurityGroup: environmentMap.applicationSecurityGroup
    location: location
    osDiskSize: osDiskSize
    lbModeEnabled: lbModeEnabled
    loadbalancing: loadbalancing
    loadbalancerIP: environmentMap.servers[serverRole].loadBalancerIP
    loadbalancerName: ''
    proximityGroupName: ''
    sqlImageId: sqlImageId
    secureImageId: secureImage.id
    sqlIpRange: environmentMap.servers[serverRole].ipAddresses
    appIpRange: environmentMap.servers[serverRole].ipAddresses
    vmAdminPassword: adminPassword
    vmAdminUser: adminUsername
    vmCount: (serverRole == 'sql' || serverRole == '') && environmentType == 'dev' || environmentType != 'dev' ? 2 : 1
    vmType: any(serverRole)
    vmSize: environmentMap.servers[serverRole].vmSize
  }
}]
