metadata name = 'Deploy Azure Stack HCI Cluster in Azure with a 2 node switched configuration'
metadata description = 'This test deploys an Azure VM to host a 2 node switched Azure Stack HCI cluster, validates the cluster configuration, and then deploys the cluster.'

targetScope = 'subscription'
param name string = 'hcicluster'
param location string = 'eastus'
param resourceGroupName string = 'dep-azure-stack-hci.cluster-${serviceShort}-rg'
param serviceShort string = 'ashc3nsmin'
param namePrefix string = '#_namePrefix_#'
param deploymentPrefix string = take(namePrefix, 8)
// credentials for the deployment and ongoing lifecycle management
param deploymentUsername string = 'deployUser'
@secure()
param localAdminAndDeploymentUserPass string = newGuid()
param localAdminUsername string = 'admin-hci'
param arbDeploymentAppId string = '\${{secrets.AZURESTACKHCI_azureStackHCIAppId}}'
param arbDeploymentSPObjectId string = '\${{secrets.AZURESTACKHCI_azureStackHCISpObjectId}}'
@secure()
#disable-next-line secure-parameter-default
param arbDeploymentServicePrincipalSecret string = '\${{secrets.arbDeploymentServicePrincipalSecret}}'
param switchlessStorageConfig bool = true
param clusterNodeNames array = ['hcinode1', 'hcinode2', 'hcinode3']
param domainFqdn string = 'hci.local'
param domainOUPath string = 'OU=HCI,DC=hci,DC=local'
param subnetMask string = '255.255.255.0'
param defaultGateway string = '172.20.0.1'
param startingIPAddress string = '172.20.0.2'
param endingIPAddress string = '172.20.0.7'
param dnsServers array = ['172.20.0.1']
param customLocationName string = '${serviceShort}-location'
param vnetSubnetId string = ''
param hciISODownloadURL string = ''
param hciVHDXDownloadURL string = 'https://software-static.download.prss.microsoft.com/dbazure/888969d5-f34g-4e03-ac9d-1f9786c66749/25398.469.amd64fre.zn_release_svc_refresh.231004-1141_server_serverazurestackhcicor_en-us.vhdx'

param networkIntents networkIntent[] = [
  {
    adapter: ['mgmt']
    name: 'management'
    overrideAdapterProperty: true
    adapterPropertyOverrides: {
      jumboPacket: '9014'
      networkDirect: 'Disabled'
      networkDirectTechnology: 'iWARP'
    }
    overrideQosPolicy: false
    qosPolicyOverrides: {
      bandwidthPercentage_SMB: '50'
      priorityValue8021Action_Cluster: '7'
      priorityValue8021Action_SMB: '3'
    }
    overrideVirtualSwitchConfiguration: false
    virtualSwitchConfigurationOverrides: {
      enableIov: 'true'
      loadBalancingAlgorithm: 'Dynamic'
    }
    trafficType: ['Management']
  }
  {
    adapter: ['comp0', 'comp1']
    name: 'compute'
    overrideAdapterProperty: true
    adapterPropertyOverrides: {
      jumboPacket: '9014'
      networkDirect: 'Disabled'
      networkDirectTechnology: 'iWARP'
    }
    overrideQosPolicy: false
    qosPolicyOverrides: {
      bandwidthPercentage_SMB: '50'
      priorityValue8021Action_Cluster: '7'
      priorityValue8021Action_SMB: '3'
    }
    overrideVirtualSwitchConfiguration: false
    virtualSwitchConfigurationOverrides: {
      enableIov: 'true'
      loadBalancingAlgorithm: 'Dynamic'
    }
    trafficType: ['Compute']
  }
  {
    adapter: ['smb0', 'smb1']
    name: 'storage'
    overrideAdapterProperty: true
    adapterPropertyOverrides: {
      jumboPacket: '9014'
      networkDirect: 'Disabled'
      networkDirectTechnology: 'iWARP'
    }
    overrideQosPolicy: true
    qosPolicyOverrides: {
      bandwidthPercentage_SMB: '50'
      priorityValue8021Action_Cluster: '7'
      priorityValue8021Action_SMB: '3'
    }
    overrideVirtualSwitchConfiguration: false
    virtualSwitchConfigurationOverrides: {
      enableIov: 'true'
      loadBalancingAlgorithm: 'Dynamic'
    }
    trafficType: ['Storage']
  }
]

param enableStorageAutoIp bool = false
param storageNetworks storageNetworksArrayType = [
  {
    adapterName: 'smb0'
    vlan: '711'
    storageAdapterIPInfo: [
      {
        //switch A
        physicalNode: 'hcinode1'
        ipv4Address: '10.71.1.1'
        subnetMask: '255.255.255.0'
      }
      {
        //switch A
        physicalNode: 'hcinode2'
        ipv4Address: '10.71.1.2'
        subnetMask: '255.255.255.0'
      }
      {
        // switch B
        physicalNode: 'hcinode3'
        ipv4Address: '10.71.2.3'
        subnetMask: '255.255.255.0'
      }
    ]
  }
  {
    adapterName: 'smb1'
    vlan: '711'
    storageAdapterIPInfo: [
      {
        // switch B
        physicalNode: 'hcinode1'
        ipv4Address: '10.71.2.1'
        subnetMask: '255.255.255.0'
      }
      {
        // switch C
        physicalNode: 'hcinode2'
        ipv4Address: '10.71.3.2'
        subnetMask: '255.255.255.0'
      }
      {
        //switch C
        physicalNode: 'hcinode3'
        ipv4Address: '10.71.3.3'
        subnetMask: '255.255.255.0'
      }
    ]
  }
]

var clusterWitnessStorageAccountName = '${deploymentPrefix}${serviceShort}${take(uniqueString(resourceGroup.id,resourceGroup.location),6)}wit'
var keyVaultDiagnosticStorageAccountName = '${deploymentPrefix}${serviceShort}${take(uniqueString(resourceGroup.id,resourceGroup.location),6)}kvd'
var keyVaultName = 'kvhci-${deploymentPrefix}${take(uniqueString(resourceGroup.id,resourceGroup.location),6)}'

resource resourceGroup 'Microsoft.Resources/resourceGroups@2024-03-01' = {
  name: resourceGroupName
  location: location
}

module hciDependencies './dependencies.bicep' = {
  name: '${uniqueString(deployment().name, location)}-test-hcidependencies-${serviceShort}'
  scope: resourceGroup
  params: {
    clusterNodeNames: clusterNodeNames
    clusterWitnessStorageAccountName: clusterWitnessStorageAccountName
    deploymentPrefix: deploymentPrefix
    deploymentUsername: deploymentUsername
    deploymentUserPassword: localAdminAndDeploymentUserPass
    keyVaultName: keyVaultName
    keyVaultDiagnosticStorageAccountName: keyVaultDiagnosticStorageAccountName
    localAdminPassword: localAdminAndDeploymentUserPass
    localAdminUsername: localAdminUsername
    location: location
    arbDeploymentAppId: arbDeploymentAppId
    arbDeploymentSPObjectId: arbDeploymentSPObjectId
    arbDeploymentServicePrincipalSecret: arbDeploymentServicePrincipalSecret
    vnetSubnetId: vnetSubnetId
    hciNodeCount: length(clusterNodeNames)
    switchlessStorageConfig: switchlessStorageConfig
    hciISODownloadURL: hciISODownloadURL
    hciVHDXDownloadURL: hciVHDXDownloadURL
  }
}

module cluster_validate '../../../main.bicep' = {
  dependsOn: [
    hciDependencies
  ]
  name: '${uniqueString(deployment().name, location)}-test-clustervalidate-${serviceShort}'
  scope: resourceGroup
  params: {
    name: name
    customLocationName: customLocationName
    clusterNodeNames: clusterNodeNames
    clusterWitnessStorageAccountName: clusterWitnessStorageAccountName
    defaultGateway: defaultGateway
    deploymentMode: 'Validate'
    deploymentPrefix: deploymentPrefix
    dnsServers: dnsServers
    domainFqdn: domainFqdn
    domainOUPath: domainOUPath
    endingIPAddress: endingIPAddress
    enableStorageAutoIp: enableStorageAutoIp
    keyVaultName: keyVaultName
    networkIntents: networkIntents
    startingIPAddress: startingIPAddress
    storageConnectivitySwitchless: switchlessStorageConfig
    storageNetworks: storageNetworks
    subnetMask: subnetMask
  }
}

module testDeployment '../../../main.bicep' = {
  dependsOn: [
    hciDependencies
    cluster_validate
  ]
  name: '${uniqueString(deployment().name, location)}-test-clusterdeploy-${serviceShort}'
  scope: resourceGroup
  params: {
    name: name
    clusterNodeNames: clusterNodeNames
    clusterWitnessStorageAccountName: clusterWitnessStorageAccountName
    customLocationName: customLocationName
    defaultGateway: defaultGateway
    deploymentMode: 'Deploy'
    deploymentPrefix: deploymentPrefix
    dnsServers: dnsServers
    domainFqdn: domainFqdn
    domainOUPath: domainOUPath
    endingIPAddress: endingIPAddress
    enableStorageAutoIp: enableStorageAutoIp
    keyVaultName: keyVaultName
    networkIntents: networkIntents
    startingIPAddress: startingIPAddress
    storageConnectivitySwitchless: switchlessStorageConfig
    storageNetworks: storageNetworks
    subnetMask: subnetMask
  }
}

type networkIntent = {
  adapter: string[]
  name: string
  overrideAdapterProperty: bool
  adapterPropertyOverrides: {
    jumboPacket: string
    networkDirect: string
    networkDirectTechnology: string
  }
  overrideQosPolicy: bool
  qosPolicyOverrides: {
    bandwidthPercentage_SMB: string
    priorityValue8021Action_Cluster: string
    priorityValue8021Action_SMB: string
  }
  overrideVirtualSwitchConfiguration: bool
  virtualSwitchConfigurationOverrides: {
    enableIov: string
    loadBalancingAlgorithm: string
  }
  trafficType: string[]
}

// define custom type for storage adapter IP info for 3-node switchless deployments
type storageAdapterIPInfoType = {
  physicalNode: string
  ipv4Address: string
  subnetMask: string
}

// define custom type for storage network objects
type storageNetworksType = {
  adapterName: string
  vlan: string
  storageAdapterIPInfo: storageAdapterIPInfoType[]? // optional for non-switchless deployments
}
type storageNetworksArrayType = storageNetworksType[]

// cluster security configuration settings
type securityConfigurationType = {
  hvciProtection: bool
  drtmProtection: bool
  driftControlEnforced: bool
  credentialGuardEnforced: bool
  smbSigningEnforced: bool
  smbClusterEncryption: bool
  sideChannelMitigationEnforced: bool
  bitlockerBootVolume: bool
  bitlockerDataVolumes: bool
  wdacEnforced: bool
}