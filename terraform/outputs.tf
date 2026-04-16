output "resource_group_name" {
  value = azurerm_resource_group.demo.name
}

output "sql_server_name" {
  value = azurerm_mssql_server.demo.fully_qualified_domain_name
}

output "sql_database_name" {
  value = azurerm_mssql_database.demo.name
}

output "sql_admin_username" {
  value = var.sql_admin_username
}

output "adf_backup_name" {
  description = "Backup ADF (complete, working — never touch on demo day)"
  value       = azurerm_data_factory.demo.name
}

output "adf_backup_url" {
  value = "https://adf.azure.com/en/authoring/${azurerm_data_factory.demo.name}?factory=%2Fsubscriptions%2F${data.azurerm_client_config.current.subscription_id}%2FresourceGroups%2F${azurerm_resource_group.demo.name}%2Fproviders%2FMicrosoft.DataFactory%2Ffactories%2F${azurerm_data_factory.demo.name}"
}

output "adf_live_name" {
  description = "Live demo ADF — this is what you build in front of the audience"
  value       = azurerm_data_factory.demo_live.name
}

output "adf_live_url" {
  value = "https://adf.azure.com/en/authoring/${azurerm_data_factory.demo_live.name}?factory=%2Fsubscriptions%2F${data.azurerm_client_config.current.subscription_id}%2FresourceGroups%2F${azurerm_resource_group.demo.name}%2Fproviders%2FMicrosoft.DataFactory%2Ffactories%2F${azurerm_data_factory.demo_live.name}"
}

output "key_vault_name" {
  value = azurerm_key_vault.demo.name
}

output "storage_account_name" {
  value = azurerm_storage_account.demo.name
}

output "next_steps" {
  value = <<EOT

=== TERRAFORM APPLY COMPLETE ===

SQL Server:  ${azurerm_mssql_server.demo.fully_qualified_domain_name}
Database:    ${azurerm_mssql_database.demo.name}
ADF:         ${azurerm_data_factory.demo.name}

Next steps:
1. Connect SSMS to the SQL server above
2. Run sql/sink/02_azuresql_setup.sql
3. Run sql/sink/03_sp_brz_to_slv.sql
4. Run sql/sink/04_sp_slv_to_gld.sql
5. cd sql/source && docker-compose up -d
6. Set up SHIR + linked services + datasets + pipeline in ADF (see README)

To destroy everything:  terraform destroy
EOT
}
