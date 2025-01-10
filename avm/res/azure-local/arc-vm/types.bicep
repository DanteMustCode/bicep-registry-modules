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
type osType = 'Windows' | 'Linux'
