resource "azurerm_private_dns_zone" "storage_dns_zones" {
  for_each = local.storage_account_endpoints

  name                = "privatelink.${each.value}.core.windows.net"
  resource_group_name = var.resource_group_name
}

module "avm_res_storage_storageaccount" {
  source = "Azure/avm-res-storage-storageaccount/azurerm"
  enable_telemetry              = var.enable_telemetry
  // regex to remove invalid characters from the name
  name                          = local.storage_account_name
  resource_group_name           = var.resource_group_name
  location                      = var.location
  account_replication_type      = "GRS"
  account_tier                  = "Standard"
  account_kind                  = "StorageV2"
  shared_access_key_enabled     = true
  public_network_access_enabled = var.is_private ? false : true

  managed_identities = {
    system_assigned            = true
  }

  private_endpoints = var.is_private ? {
    for endpoint in local.storage_account_endpoints :
    endpoint => {
      # the name must be set to avoid conflicting resources.
      name                          = "pe-${endpoint}-${var.name}"
      subnet_resource_id            = var.shared_subnet_id
      subresource_name              = endpoint
      private_dns_zone_resource_ids = [azurerm_private_dns_zone.storage_dns_zones[endpoint].id]
      # these are optional but illustrate making well-aligned service connection & NIC names.
      private_service_connection_name = "psc-${endpoint}-${var.name}"
      network_interface_name          = "nic-pe-${endpoint}-${var.name}"
      inherit_lock                    = false
    }
  } : null

  count = var.storage_account == null ? 1 : 0
}
