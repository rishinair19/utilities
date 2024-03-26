# Creates MySQL user and grant, also generates a random password and uploads it to vault


variable "mysql_username" { default = "sample"}

terraform {
  backend "s3" {
    bucket = ""
    key    = "
    region = ""
  }
}

variable "dbs" { 
  type    = list(string) 
  default = [""]
}

##################################################################################################################################################

variable "dbusername" { default = "" }
variable "dbendpoint" { default = "" }
variable "prefix" { default = ""}

variable "vault_addr" {
  description = "Vault Address"
  type        = string
  default     = ""
}

##################################################################################################################################################

variable "dbpassword" {
  type        = string
}

variable "vault_token" {
  type        = string
}

provider "mysql" {
  endpoint = var.dbendpoint
  username = var.dbusername
  password = var.dbpassword
}

provider vault {
    address = "${var.vault_addr}"
    token = "${var.vault_token}"
}

resource "random_string" "password" {
  length           = 16
  special          = false
  override_special = "-"
}

resource "vault_generic_secret" "example" {
  path = "${var.prefix}/${mysql_user.user.user}"
  data_json = jsonencode({
    mysql_password = random_string.password.result
    })
}


# mysql_grant.user_grant:
resource "mysql_grant" "user_grant" {
    database   = "*"
    grant      = false
    host       = "%"
    privileges = [
        "USAGE",
    ]
    table      = "*"
    tls_option = "NONE"
    user       = "${var.mysql_username}"
    depends_on = [mysql_user.user]
}

# mysql_grant.user_grant-1:
resource "mysql_grant" "user_grant-1" {
    for_each = toset(var.dbs)
    database   = each.value
    grant      = false
    host       = "%"
    privileges = [
        "ALL PRIVILEGES",
    ]
    table      = "*"
    tls_option = "NONE"
    user       = "${var.mysql_username}"
    depends_on = [mysql_user.user]
}

# mysql_user.user:
resource "mysql_user" "user" {
    host       = "%"
    tls_option = "NONE"
    user       = "${var.mysql_username}"
    plaintext_password = random_string.password.result
}

