
provider "azurerm" {
  features {
    key_vault {
      purge_soft_delete_on_destroy = false
    }
  }
}

data "azurerm_client_config" "current" {}

resource "azurerm_storage_account" "this" {
  name                     = "${var.name}sa"
  location                 = var.location
  resource_group_name      = var.resource_group_name
  account_tier             = "Standard"
  account_replication_type = "GRS"

  count = var.storage_account_id != null ? 0 : 1
}


resource "azurerm_key_vault" "this" {
  name                     = "${var.name}kv"
  location                 = var.location
  resource_group_name      = var.resource_group_name
  tenant_id                = data.azurerm_client_config.current.tenant_id
  sku_name                 = "premium"
  count                    = var.key_vault_id != null ? 0 : 1
  purge_protection_enabled = true
}

resource "azurerm_user_assigned_identity" "this" {
  name                = "${var.name}-uai"
  location            = var.location
  resource_group_name = var.resource_group_name
}

resource "azurerm_key_vault_access_policy" "this" {
  key_vault_id = var.key_vault_id != null ? var.key_vault_id : azurerm_key_vault.this[0].id
  tenant_id    = data.azurerm_client_config.current.tenant_id
  object_id    = azurerm_user_assigned_identity.this.principal_id

  // default set by service
  key_permissions = [
    "WrapKey",
    "UnwrapKey",
    "Get",
    "Recover",
  ]

  secret_permissions = [
    "Get",
    "List",
    "Set",
    "Delete",
    "Recover",
    "Backup",
    "Restore"
  ]
}

resource "azurerm_key_vault_access_policy" "this-sp" {
  key_vault_id = var.key_vault_id != null ? var.key_vault_id : azurerm_key_vault.this[0].id
  tenant_id    = data.azurerm_client_config.current.tenant_id
  object_id    = data.azurerm_client_config.current.object_id

  key_permissions = [
    "Get",
    "Create",
    "Recover",
    "Delete",
    "Purge",
    "GetRotationPolicy",
  ]
}

resource "azurerm_key_vault_key" "this" {
  name         = "${var.name}-key"
  key_vault_id = var.key_vault_id != null ? var.key_vault_id : azurerm_key_vault.this[0].id
  key_type     = "RSA"
  key_size     = 2048

  key_opts = [
    "decrypt",
    "encrypt",
    "sign",
    "unwrapKey",
    "verify",
    "wrapKey",
  ]
  depends_on = [azurerm_key_vault.this, azurerm_key_vault_access_policy.this, azurerm_key_vault_access_policy.this-sp]
}

resource "azurerm_application_insights" "this" {
  name                = "${var.name}-ai"
  location            = var.location
  resource_group_name = var.resource_group_name
  application_type    = "web"
}

resource "azurerm_machine_learning_workspace" "this" {
  name                    = var.name
  location                = var.location
  resource_group_name     = var.resource_group_name
  application_insights_id = azurerm_application_insights.this.id
  key_vault_id            = var.key_vault_id != null ? var.key_vault_id : azurerm_key_vault.this[0].id
  storage_account_id      = var.storage_account_id != null ? var.storage_account_id : azurerm_storage_account.this[0].id

  high_business_impact = true

  primary_user_assigned_identity = azurerm_user_assigned_identity.this.id
  identity {
    type = "UserAssigned"
    identity_ids = [
      azurerm_user_assigned_identity.this.id,
    ]
  }

  encryption {
    user_assigned_identity_id = azurerm_user_assigned_identity.this.id
    key_vault_id              = var.key_vault_id != null ? var.key_vault_id : azurerm_key_vault.this[0].id
    key_id                    = azurerm_key_vault_key.this.id
  }

  depends_on = [azurerm_key_vault_access_policy.this, azurerm_key_vault_access_policy.this-sp]
}

resource "azurerm_management_lock" "this" {
  count = var.lock != null ? 1 : 0

  lock_level = var.lock.kind
  name       = coalesce(var.lock.name, "lock-${var.lock.kind}")
  scope      = azurerm_machine_learning_workspace.this.id
  notes      = var.lock.kind == "CanNotDelete" ? "Cannot delete the resource or its child resources." : "Cannot delete or modify the resource or its child resources."
}

resource "azurerm_role_assignment" "this" {
  for_each = var.role_assignments

  principal_id                           = each.value.principal_id
  scope                                  = var.resource_group_name
  condition                              = each.value.condition
  condition_version                      = each.value.condition_version
  delegated_managed_identity_resource_id = each.value.delegated_managed_identity_resource_id
  role_definition_id                     = strcontains(lower(each.value.role_definition_id_or_name), lower(local.role_definition_resource_substring)) ? each.value.role_definition_id_or_name : null
  role_definition_name                   = strcontains(lower(each.value.role_definition_id_or_name), lower(local.role_definition_resource_substring)) ? null : each.value.role_definition_id_or_name
  skip_service_principal_aad_check       = each.value.skip_service_principal_aad_check
}
