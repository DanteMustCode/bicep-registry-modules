@export()
type diskParam = {
  name: string
  diskSizeGB: int
  dynamic: bool
  // TODO: not equivalent to map(string)
  tags: object?
  containerId: string?
}

type publicKey = {
  keyData: string
  path: string
}

@export()
type sshConfig = {
  publicKeys: publicKey[]
}

@export()
type lock = {
  kind: 'CanNotDelete' | 'ReadOnly'
  // TODO: bicep has no state, may have problem
  name: string?
}

@export()
type managedIdentities = {
  systemAssigned: bool
  userAssignedResourceIds: string[]
}

@export()
type osType = 'Windows' | 'Linux'

@export()
type roleAssignment = {
  roleDefinitionIdOrName: string
  principalId: string
  description: string?
  skipServicePrincipalEntraCheck: bool?
  condition: string?
  conditionVersion: string?
  delegatedManagedIdentityResourceId: string?
  principalType: string?
}
