output "private_endpoints" {
  description = <<DESCRIPTION
  A map of the private endpoints created.
  DESCRIPTION
  value       = azurerm_private_endpoint.this
}

# Module owners should include the full resource via a 'resource' output
# https://azure.github.io/Azure-Verified-Modules/specs/terraform/#id-tffr2---category-outputs---additional-terraform-outputs
output "resource" {
  description = "This is the full output for the resource."
  value       = azurerm_machine_learning_workspace.this.id
}

output "key_vault_id" {
  description = "The ID of the key vault."
  value       = var.key_vault_id != null ? var.key_vault_id : azurerm_key_vault.this[0].id
}

output "application_insights_id" {
  description = "The ID of the application insights."
  value       = azurerm_application_insights.this.id
}

output "storage_account_id" {
  description = "The ID of the storage account."
  value       = var.storage_account_id != null ? var.storage_account_id : azurerm_storage_account.this[0].id
}

output "user_assigned_identity_id" {
  description = "The ID of the user assigned identity."
  value       = azurerm_user_assigned_identity.this.id
}
