variable "location" {
  description = "Azure region for all resources. Confirm VM SKU availability first."
  type        = string
  default     = "centralus"
}

variable "vm_size" {
  description = "Azure VM size available to the active subscription and region."
  type        = string
  default     = "Standard_D2s_v7"
}

variable "admin_password" {
  description = "Temporary VM administrator password supplied at plan/apply time."
  type        = string
  sensitive   = true
  nullable    = false

  validation {
    condition     = length(var.admin_password) >= 12
    error_message = "admin_password must contain at least 12 characters."
  }
}

variable "ssh_source_address_prefix" {
  description = "CIDR allowed to access SSH. Replace the default with the team's public IP."
  type        = string
}
