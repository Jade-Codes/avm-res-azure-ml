locals {
  key_vault_name = replace("kv${var.name}", "/[^a-zA-Z0-9-]/", "")
  key_vault_endpoints = var.is_private ? toset(["vaultcore"]) : toset([])
}
