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

