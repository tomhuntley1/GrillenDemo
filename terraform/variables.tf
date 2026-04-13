variable "location" {
  description = "Azure region. UK South recommended for a UK conference."
  type        = string
  default     = "uksouth"
}

variable "sql_admin_username" {
  description = "SQL Server admin username. Avoid 'admin', 'sa', 'root' — Azure rejects them."
  type        = string
  default     = "northroute_admin"
}

variable "sql_admin_password" {
  description = "SQL Server admin password. 8+ chars, upper, lower, number, symbol."
  type        = string
  sensitive   = true
}

variable "my_ip_address" {
  description = "Your public IP (https://whatismyip.com). Added to SQL firewall so your laptop can connect."
  type        = string
}
