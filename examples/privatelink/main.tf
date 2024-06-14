terraform {
  required_version = "~> 1.5"
  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "~> 3.74"
    }
    random = {
      source  = "hashicorp/random"
      version = "~> 3.5"
    }
  }
}

provider "azurerm" {
  features {
    key_vault {
      purge_soft_delete_on_destroy = false
    }
  }
}

data "azurerm_client_config" "current" {}

## Section to provide a random Azure region for the resource group
# This allows us to randomize the region for the resource group.
module "regions" {
  source  = "Azure/regions/azurerm"
  version = "~> 0.3"
}

# This allows us to randomize the region for the resource group.
resource "random_integer" "region_index" {
  max = length(module.regions.regions) - 1
  min = 0
}
## End of section to provide a random Azure region for the resource group

# This ensures we have unique CAF compliant names for our resources.
module "naming" {
  source  = "Azure/naming/azurerm"
  version = "~> 0.3"
}

# This is required for resource modules
resource "azurerm_resource_group" "this" {
  location = "uksouth"
  name     = module.naming.resource_group.name_unique
}

locals {
  name = module.naming.machine_learning_workspace.name_unique
  core_services_vnet_subnets            = cidrsubnets("10.0.0.0/22", 6, 2, 4, 3)
  firewall_subnet_address_space         = local.core_services_vnet_subnets[1]
  bastion_subnet_address_prefix         = local.core_services_vnet_subnets[2]
  shared_services_subnet_address_prefix = local.core_services_vnet_subnets[3]
  dns_zones =  toset([
    "privatelink.api.azureml.ms",
    "privatelink.notebooks.azure.net",
  ])
}


resource "azurerm_storage_account" "this" {
  name                     = replace("${local.name}sa", "/[^a-zA-Z0-9]/", "")
  location                 = var.location
  resource_group_name      = azurerm_resource_group.this.name
  account_tier             = "Standard"
  account_replication_type = "GRS"
}


resource "azurerm_key_vault" "this" {
  name                     = replace("${local.name}kv", "/[^a-zA-Z0-9]/", "")
  location                 = var.location
  resource_group_name      = azurerm_resource_group.this.name
  tenant_id                = data.azurerm_client_config.current.tenant_id
  sku_name                 = "premium"
  purge_protection_enabled = true
}

resource "azurerm_virtual_network" "vnet" {
  address_space       = ["10.0.0.0/22"]
  location            = azurerm_resource_group.this.location
  name                = module.naming.virtual_network.name_unique
  resource_group_name = azurerm_resource_group.this.name
}

resource "azurerm_subnet" "shared" {
  name                 = "SharedSubnet"
  virtual_network_name = azurerm_virtual_network.vnet.name
  resource_group_name  = azurerm_resource_group.this.name
  address_prefixes     = [local.shared_services_subnet_address_prefix]
}

resource "azurerm_private_dns_zone" "this" {
  for_each = local.dns_zones

  name                = each.value
  resource_group_name = azurerm_resource_group.this.name
}

resource "azurerm_private_dns_zone_virtual_network_link" "private_links" {
  for_each = azurerm_private_dns_zone.this

  name                  = "${each.key}_${azurerm_virtual_network.vnet.name}-link"
  private_dns_zone_name = azurerm_private_dns_zone.this[each.key].name
  resource_group_name   = azurerm_resource_group.this.name
  virtual_network_id    = azurerm_virtual_network.vnet.id
}

# This is the module call
# Do not specify location here due to the randomization above.
# Leaving location as `null` will cause the module to use the resource group location
# with a data source.
module "azureml" {
  source = "../../"
  # source             = "Azure/avm-<res/ptn>-<name>/azurerm"
  # ...
  location            = azurerm_resource_group.this.location
  name                = module.naming.machine_learning_workspace.name_unique
  resource_group_name = azurerm_resource_group.this.name

  storage_account_id = azurerm_storage_account.this.id
  key_vault_id       = azurerm_key_vault.this.id
  
  private_endpoints = {
    for dns_zone in local.dns_zones :
    dns_zone => {
      name                          = "pe-${dns_zone}-${local.name}"
      subnet_resource_id            = azurerm_subnet.shared.id
      subresource_name              = dns_zone
      private_dns_zone_resource_ids = [azurerm_private_dns_zone.this[dns_zone].id]
      private_service_connection_name = "psc-${dns_zone}-${module.naming.machine_learning_workspace.name_unique}"
      network_interface_name          = "nic-pe-${dns_zone}-${module.naming.machine_learning_workspace.name_unique}"
      inherit_lock                    = false
    }
  }

  enable_telemetry = var.enable_telemetry 
}
