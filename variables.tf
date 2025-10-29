# Azure Credentials
variable "azure_subscription_id" {
  description = "Azure Subscription ID"
  type        = string
  sensitive   = true
}

variable "azure_client_id" {
  description = "Azure Client ID"
  type        = string
  sensitive   = true
}

variable "azure_client_secret" {
  description = "Azure Client Secret"
  type        = string
  sensitive   = true
}

variable "azure_tenant_id" {
  description = "Azure Tenant ID"
  type        = string
  sensitive   = true
}

# Other variables
variable "location" {
  description = "The Azure region where resources will be created"
  type        = string
  default     = "Central US"
}

variable "environment" {
  description = "The deployment environment"
  type        = string
  default     = "production"
}

variable "vm_size_web" {
  description = "VM size for web tier"
  type        = string
  default     = "Standard_B1ms"
}

variable "vm_size_app" {
  description = "VM size for app tier"
  type        = string
  default     = "Standard_B1s"
}