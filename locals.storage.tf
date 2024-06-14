locals {
  storage_account_name = replace("sa${var.name}", "/[^a-zA-Z0-9]/", "")
  storage_account_endpoints = var.is_private ? toset(["blob", "queue", "table", "file"]) : toset([])
}
