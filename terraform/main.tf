terraform {
  required_version = ">= 1.3.0"
  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "~> 3.90"
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
      purge_soft_delete_on_destroy    = true
      recover_soft_deleted_key_vaults = false
    }
    resource_group {
      prevent_deletion_if_contains_resources = false
    }
  }
}

data "azurerm_client_config" "current" {}

resource "random_string" "suffix" {
  length  = 6
  upper   = false
  special = false
}

locals {
  suffix    = random_string.suffix.result
  base_name = "northroute-${local.suffix}"
}

# =============================================================================
# RESOURCE GROUP
# =============================================================================
resource "azurerm_resource_group" "demo" {
  name     = "rg-${local.base_name}-demo"
  location = var.location
  tags = {
    project     = "DataGrillenDemo"
    environment = "demo"
    created_by  = "terraform"
  }
}

# =============================================================================
# KEY VAULT
# =============================================================================
resource "azurerm_key_vault" "demo" {
  name                        = "kv-${local.suffix}"
  location                    = azurerm_resource_group.demo.location
  resource_group_name         = azurerm_resource_group.demo.name
  tenant_id                   = data.azurerm_client_config.current.tenant_id
  sku_name                    = "standard"
  soft_delete_retention_days  = 7
  purge_protection_enabled    = false
  tags                        = azurerm_resource_group.demo.tags
}

resource "azurerm_key_vault_access_policy" "current_user" {
  key_vault_id = azurerm_key_vault.demo.id
  tenant_id    = data.azurerm_client_config.current.tenant_id
  object_id    = data.azurerm_client_config.current.object_id
  secret_permissions = ["Get", "List", "Set", "Delete", "Purge", "Recover"]
}

resource "azurerm_key_vault_access_policy" "adf" {
  key_vault_id = azurerm_key_vault.demo.id
  tenant_id    = data.azurerm_client_config.current.tenant_id
  object_id    = azurerm_data_factory.demo.identity[0].principal_id
  secret_permissions = ["Get", "List"]
  depends_on   = [azurerm_data_factory.demo]
}

resource "azurerm_key_vault_secret" "sql_password" {
  name         = "sqlserver-admin-password"
  value        = var.sql_admin_password
  key_vault_id = azurerm_key_vault.demo.id
  depends_on   = [azurerm_key_vault_access_policy.current_user]
}

# =============================================================================
# AZURE SQL SERVER + DATABASE
# =============================================================================
resource "azurerm_mssql_server" "demo" {
  name                         = "sql-${local.base_name}"
  resource_group_name          = azurerm_resource_group.demo.name
  location                     = azurerm_resource_group.demo.location
  version                      = "12.0"
  administrator_login          = var.sql_admin_username
  administrator_login_password = var.sql_admin_password
  public_network_access_enabled = true
  tags                         = azurerm_resource_group.demo.tags
}

resource "azurerm_mssql_firewall_rule" "allow_azure_services" {
  name             = "AllowAzureServices"
  server_id        = azurerm_mssql_server.demo.id
  start_ip_address = "0.0.0.0"
  end_ip_address   = "0.0.0.0"
}

resource "azurerm_mssql_firewall_rule" "allow_my_ip" {
  name             = "AllowMyIP"
  server_id        = azurerm_mssql_server.demo.id
  start_ip_address = var.my_ip_address
  end_ip_address   = var.my_ip_address
}

resource "azurerm_mssql_database" "demo" {
  name      = "northroute-demo"
  server_id = azurerm_mssql_server.demo.id
  collation = "SQL_Latin1_General_CP1_CI_AS"
  sku_name  = "S2"
  tags      = azurerm_resource_group.demo.tags
}

# =============================================================================
# AZURE DATA FACTORY
# =============================================================================
resource "azurerm_data_factory" "demo" {
  name                = "adf-${local.base_name}"
  location            = azurerm_resource_group.demo.location
  resource_group_name = azurerm_resource_group.demo.name
  identity { type = "SystemAssigned" }
  tags                = azurerm_resource_group.demo.tags
}

resource "azurerm_role_assignment" "adf_sql_contributor" {
  scope                = azurerm_mssql_server.demo.id
  role_definition_name = "Contributor"
  principal_id         = azurerm_data_factory.demo.identity[0].principal_id
}

# =============================================================================
# STORAGE ACCOUNT
# =============================================================================
resource "azurerm_storage_account" "demo" {
  name                     = "st${local.suffix}"
  resource_group_name      = azurerm_resource_group.demo.name
  location                 = azurerm_resource_group.demo.location
  account_tier             = "Standard"
  account_replication_type = "LRS"
  tags                     = azurerm_resource_group.demo.tags
}

resource "azurerm_storage_container" "staging" {
  name                  = "adf-staging"
  storage_account_name  = azurerm_storage_account.demo.name
  container_access_type = "private"
}
