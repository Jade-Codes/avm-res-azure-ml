resource "azurerm_private_dns_zone" "key_vault_dns_zones" {
  for_each = local.key_vault_endpoints

  name                = "privatelink.${each.value}.azure.net"
  resource_group_name = var.resource_group_name
}


module "avm_res_keyvault_vault" {
  source = "Azure/avm-res-keyvault-vault/azurerm"

  tenant_id                     = data.azurerm_client_config.current.tenant_id
  enable_telemetry              = var.enable_telemetry
  name                          = local.key_vault_name
  resource_group_name           = var.resource_group_name
  location                      = var.location
  public_network_access_enabled = var.is_private ? false : true

  private_endpoints = var.is_private ? {
    for endpoint in local.key_vault_endpoints :
    endpoint => {
      name                            = "pe-${endpoint}-${var.name}"
      subnet_resource_id              = var.shared_subnet_id
      subresource_name                = endpoint
      private_dns_zone_resource_ids   = [azurerm_private_dns_zone.key_vault_dns_zones[endpoint].id]
      private_service_connection_name = "psc-${endpoint}-${var.name}"
      network_interface_name          = "nic-pe-${endpoint}-${var.name}"
      inherit_lock                    = false
    }
  } : null
  
  
  count = var.key_vault == null ? 1 : 0
}
