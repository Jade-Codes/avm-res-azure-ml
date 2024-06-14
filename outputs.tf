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

output "application_insights_id" {
  description = "The ID of the application insights."
  value       = azurerm_application_insights.this.id
}
