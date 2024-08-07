//Parameters
param location string = resourceGroup().location
param desEnabled bool = false
param domainJoin bool = true
param staticIpAllocation bool = false
@description('The Resource id of the disk encryption set')
param desID string = ''
param vmName string = 'testVM'
param adminUsername string = 
@minLength(12)
@secure()
param adminP string 
param vmSize string = 'Standard_D2s_v3'
param privateIP string = 
param subnetId string 
param secureImageId string 
@description('Name of the domain to which Virtual Machines should be joined.')
param domainName string = 
@description('Path to OU to which Virtual Machine should be added.')
param ouPath string = 
@description('Username for account which should be used for domain joining.')
param domainUser string
@description('Password for account which should be used for domain joining.')
param domainPasswd string


//Virtual Machine
resource virtualMachine 'Microsoft.Compute/virtualMachines@2021-03-01' = {
  name: vmName
  tags:{
    owner: 'Owner'
  }
  location: location
  properties: {
    securityProfile: {
      encryptionAtHost: true
    }
    hardwareProfile: {
      vmSize: vmSize
    }
    osProfile: {
      computerName: vmName
      adminUsername: adminUsername
      adminPassword: adminP
    }
    licenseType: 'Windows_Server'
    storageProfile: {
      imageReference: {
        id: secureImageId
      }
      osDisk: {
        createOption: 'FromImage'
        caching: 'ReadWrite'
        managedDisk: {
          diskEncryptionSet: {
            id: desEnabled == true ? desID : null 
          }
          storageAccountType: 'StandardSSD_LRS'
        }
      }
      dataDisks: [
        {
          managedDisk: {
            diskEncryptionSet: {
              id: desEnabled == true ? desID : null
            }
          }
          diskSizeGB: 1023
          lun: 0
          createOption: 'Empty'
          caching: 'None'
        }
      ]
    }
    networkProfile: {
      networkInterfaces: [
        {
          id: nic.id
        }
      ]
    }
  }
  zones: [
    '1'
  ]
}

resource windowsAgent 'Microsoft.Compute/virtualMachines/extensions@2022-08-01' = {
  parent: virtualMachine
  name: 'AzureMonitorWindowsAgent'
  location: location
  properties: {
    publisher: 'Microsoft.Azure.Monitor'
    type: 'AzureMonitorWindowsAgent'
    typeHandlerVersion: '1.0'
    autoUpgradeMinorVersion: true
    enableAutomaticUpgrade: true
  }
}

resource windowsVMGuestConfigExtension 'Microsoft.Compute/virtualMachines/extensions@2022-03-01' = {
  parent: virtualMachine
  name: 'AzurePolicyforWindows'
  location: location
  properties: {
    publisher: 'Microsoft.GuestConfiguration'
    type: 'ConfigurationforWindows'
    typeHandlerVersion: '1.1'
    autoUpgradeMinorVersion: true
    enableAutomaticUpgrade: true
    settings: {}
    protectedSettings: {}
  }
}


//NIC attached to VM
resource nic 'Microsoft.Network/networkInterfaces@2021-02-01' = {
  name: 'nic-${vmName}'
  tags:{
    owner: 'Owner'
  }
  location: location
  properties: {
    ipConfigurations: [
      {
        name: 'nic-ip-config'
        properties: {
          privateIPAddress: staticIpAllocation == true ? privateIP : null
          privateIPAllocationMethod: staticIpAllocation == true ? 'Static' : 'Dynamic'
          subnet:{
            id:subnetId
          }
        }
      }
    ]
  }
}

resource domainJoinExtension 'Microsoft.Compute/virtualMachines/extensions@2015-06-15' =  if (domainJoin == true) {
  parent: virtualMachine
  name: 'JoinDomain-${domainName}'
  location: location
  tags: {
    owner: 'Owner'
  }
  properties: {
    publisher: 'Microsoft.Compute'
    type: 'JsonADDomainExtension'
    typeHandlerVersion: '1.3'
    autoUpgradeMinorVersion: true
    settings: {
      Name: domainName
      OUPath: ouPath
      User: '${domainName}\\${domainUser}'
      Restart: 'true'
      Options: '3'
    }
    protectedSettings: {
      Password: domainPasswd
    }
  }
}

resource iaasAntimalwareExtension 'Microsoft.Compute/virtualMachines/extensions@2022-03-01' = {
  parent: virtualMachine
  name: 'IaaSAntimalware'
  location: location
  tags: {
    owner: 'Owner'
  }
  properties: {
    autoUpgradeMinorVersion: true
    publisher: 'Microsoft.Azure.Security'
    type: 'IaaSAntimalware'
    typeHandlerVersion: '1.3'
    settings: {
      AntimalwareEnabled: true
      RealtimeProtectionEnabled: 'true'
      ScheduledScanSettings: {
        isEnabled: 'false'
        day: '7'
        time: '120'
        scanType: 'Quick'
      }
      Exclusions: {
        Paths: ''
        Extensions: ''
        Processes: ''
      }
    }
  }
}

//Optional - script to automatically initialise disks, would need tweaking to specify drive letter
resource initialiseDisks 'Microsoft.Compute/virtualMachines/runCommands@2023-03-01' = {
  name: 'runDiskInitialiseScript'
  location: location
  parent: virtualMachine
  tags: {
    owner: 'Owner'
  }
  properties: {
    source: {
      script: '''Get-Disk | Where-Object partitionstyle -eq "raw" | Initialize-Disk -PartitionStyle GPT -PassThru | New-Partition -AssignDriveLetter -UseMaximumSize | Format-Volume -FileSystem NTFS -Confirm:$false -Force'''
    }
  }
  dependsOn: [
    domainJoinExtension
    iaasAntimalwareExtension
    windowsVMGuestConfigExtension
    windowsAgent
  ]
}

