variable "vault_state_store_bucket" {
  description = "Terraform Remote State Store"
  type        = string
  default     = ""
}

variable "vault_state_store_file" {
  description = "Terraform Remote State Store Location"
  type        = string
  default     = "terraform.tfstate"
}

variable "vault_state_store_region" {
  description = "Terraform Remote State Store Region"
  type        = string
  default     = "us-east-1"
}

variable "vault_addr" {
  description = "Vault Address"
  type        = string
  default     = ""
}

variable "vault_token" {
  description = "Vault Token"
  type        = string
  default     = ""
}

variable "vault_data_json" {
  description = "Default Vault DataJson"
  type        = string
  default     = <<EOT
{
  "username":   "user",
  "password":   "pass"
}
EOT
}

variable "app_name" {
  description = "Application"
  type        = string
  default     = "app"
}

variable "env" {
  description = "Environment"
  type        = string
  default     = ""
}

variable "path" {
  description = "Path Prefix"
  type        = string
  default     = ""
}