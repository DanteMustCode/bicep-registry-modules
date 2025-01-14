import { roleAssignmentType, lockType, managedIdentityAllType } from 'br/public:avm/utl/types/avm-common-types:0.4.1'
import * as types from 'types.bicep'

@minLength(1)
@description('''
Admin username
''')
param adminUsername string

@secure()
@minLength(1)
@description('''
Admin password
''')
param adminPassword string

@description('''
The full custom location Id for Azure Local.
''')
param customLocationId string

@description('''
The OS type of the VM.
''')
param osType types.osType

@description('''
The full Marketplace Gallery Image id already downloaded to Azure Local.
''')
param imageId string

@description('''
The Azure region where the resource should be deployed.
''')
param location string

@description('''
The Id of the logical network to use for the NIC.
''')
param logicalNetworkId string

@minLength(1)
@maxLength(15)
// TODO: @regex('^[a-zA-Z0-9-]*$')
@description('''
The name of the VM resource
''')
param name string

@description('''
The resource group where the resources will be deployed.
''')
param resourceGroupName string

@description('''
Whether to enable auto upgrade minor version
''')
param autoUpgradeMinorVersion bool = true

@description('''
The array description of the dataDisks to attach to the vm.
Provide an empty array for no additional disks,
or an array following the example below.
''')
// TODO: not equivalent to map
param dataDiskParams types.diskParam[] = []

@description('''
Optional tags of the domain join extension.
''')
// TODO: not equilavent to map(string)
param domainJoinExtensionTags object = {}

@description('''
Optional User Name with permissions to join the domain.
example: domain-joiner
Required if "domain_to_join" is specified.
''')
param domainJoinUserName string = ''

@secure()
@description('''
Optional Password of User with permissions to join the domain.
Required if "domain_to_join" is specified.
''')
param domainJoinPassword string = ''

@description('''Optional domain organizational unit to join.
example: ou=computers,dc=contoso,dc=com
Required if "domain_to_join" is specified.
''')
param domainTargetOu string = ''

@description('''
Optional Domain name to join join the VM to domain.
example: contoso.com
If left empty, ou, username and password parameters will not be evaluated in the deployment.
''')
param domainToJoin string = ''

@description('''
The number of vCPUs.
''')
param vCpuCount int = 2

@description('''
Memory in MB
''')
param memoryMb int = 8192

@description('''
Enable dynamic memory
''')
param dynamicMemory bool = true

@description('''
Buffer memory in MB when dynamic memory is enabled
''')
param dynamicMemoryMb int = 20

@description('''
Maximum memory in MB when dynamic memory is enabled
''')
param maxDynamicMemoryMb int = 8192

@description('''
Minimum memory in MB when dynamic memory is enabled
''')
param minDynamicMemoryMb int = 512

@description('''
This variable controls whether or not telemetry is enabled for the module.
For more information see <https://aka.ms/avm/telemetryinfo>.
If it is set to false, then no telemetry will be collected.
''')
param enableTelemetry bool = true

@secure()
@description('''
HTTP URL for proxy server.
example: http://proxy.example.com:3128
''')
param httpProxy string = ''

@secure()
@description('''
HTTPS URL for proxy server.
The server may still use an HTTP address.
example: http://proxy.example.com:3128
''')
param httpsProxy string = ''

@description('''
SSH configuration with public keys for Linux.
''')
param linuxSshConfig types.sshConfig?

@description('''
SSH configuration with public keys for Windows.
''')
param windowsSshConfig types.sshConfig?

@description('''
Controls the Resource Lock configuration for this resource.
Changing this forces the creation of a new resource.
''')
param lock lockType?

@description('''
Controls the Managed Identity configuration on this resource.
''')
param managedIdentities managedIdentityAllType = {}

@description('''
Optional tags of the nic.
''')
// TODO: not equilavent to map(string)
param nicTags object = {}

@description('''
URLs, which can bypass proxy.
Typical examples would be [localhost,127.0.0.1,.svc,10.0.0.0/8,172.16.0.0/12,192.168.0.0/16,100.0.0.0/8]
''')
param noProxy string[] = []

@description('''
The private IP address of the NIC.
''')
param privateIpAddress string = ''

@description('''
The role assignments to create on this resource.
''')
// TODO: skipServicePrincipalEntraCheck
param roleAssignments roleAssignmentType[] = []

@description('''
Enable secure boot.
''')
param secureBootEnabled bool = true

@description('''
Optional tags of the arc vm.
''')
// TODO: not equilavent to map(string)
param tags string[] = []

@description('''
Alternative CA cert to use for connecting to proxy servers.
''')
param trustedCa string = ''

@description('''
The version of the type handler to use.
''')
param typeHandlerVersion string = '1.3'

@description('The user storage ID to store images.')
param userStorageId string = ''

/*
var builtInRoleNames = {
  Contributor: subscriptionResourceId('Microsoft.Authorization/roleDefinitions', 'b24988ac-6180-42a0-ab88-20f7382dd24c')
  Owner: subscriptionResourceId('Microsoft.Authorization/roleDefinitions', '8e3af657-a8ff-443c-a75c-2fe8c4bcb635')
  Reader: subscriptionResourceId('Microsoft.Authorization/roleDefinitions', 'acdd72a7-3385-48ef-bd42-f606fba81ae7')
  'Role Based Access Control Administrator': subscriptionResourceId(
    'Microsoft.Authorization/roleDefinitions',
    'f58310d9-a9f6-439a-9e8d-f62e7b41a168'
  )
  'User Access Administrator': subscriptionResourceId(
    'Microsoft.Authorization/roleDefinitions',
    '18d7d88d-d35e-4fb5-a5c3-7773c20a72d9'
  )
}
*/

resource l 'Microsoft.Authorization/locks@2020-05-01' = if (!empty(lock)) {
  name: lock!.name ?? guid(name) // TODO
  properties: {
    level: lock!.kind ?? 'None'
  }
}

resource r 'Microsoft.Authorization/roleAssignments@2022-04-01' = [
  for roleAssignment in roleAssignments: {
    name: roleAssignment.name ?? guid(roleAssignment.roleDefinitionIdOrName)
    properties: {
      // TODO: complete list
      principalId: roleAssignment.principalId
      principalType: roleAssignment.principalType
      roleDefinitionId: (contains(
          roleAssignment.roleDefinitionIdOrName,
          '/providers/Microsoft.Authorization/roleDefinitions/'
        )
        ? roleAssignment.roleDefinitionIdOrName
        : subscriptionResourceId('Microsoft.Authorization/roleDefinitions', roleAssignment.roleDefinitionIdOrName))
    }
  }
]

resource h 'Microsoft.HybridCompute/machines@2024-07-10' = {
  name: name
  location: location
  kind: 'HCI'
  identity: {
    type: 'SystemAssigned'
  }
}

resource n 'Microsoft.AzureStackHCI/networkInterfaces@2024-01-01' = {
  name: name
  location: location
  extendedLocation: {
    type: 'CustomLocation'
    name: customLocationId
  }
  properties: {
    ipConfigurations: [
      {
        name: 'ipconfig1'
        properties: {
          subnet: logicalNetworkId // TODO: warning
        }
      }
    ]
  }
}

resource v 'Microsoft.AzureStackHCI/virtualMachineInstances@2024-01-01' = {
  name: 'default'
  scope: h
  extendedLocation: {
    type: 'CustomLocation'
    name: customLocationId
  }
  properties: {
    hardwareProfile: {
      vmSize: 'Custom'
      processors: vCpuCount
      memoryMB: memoryMb
      dynamicMemoryConfig: dynamicMemory
        ? {
            targetMemoryBuffer: dynamicMemoryMb
            maximumMemoryMB: maxDynamicMemoryMb
            minimumMemoryMB: minDynamicMemoryMb
          }
        : null
    }
    osProfile: {
      adminUsername: adminUsername
      adminPassword: adminPassword
      computerName: name
    }
    storageProfile: {
      imageReference: imageId
      dataDisks: dataDiskParams
    }
    networkProfile: {
      networkInterfaces: {
        id: n.id
      }
    }
  }
}
