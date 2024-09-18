
variable "app" { default = "" }
variable "bucket" { default = "" }
variable "env" { default = "" }
variable "prefix" { default = ""}
variable "region_name" { default = "us-east-1" }
variable "hostname" { default = "" }
variable "host" { default = "%" }
variable "DBUSERNAME" { type = string }
variable "DBPASSWORD" { type = string  }


variable "privileges" { 
  type    = list(string) 
  default = ["ALL"]
}
variable "dbs" { 
  type    = list(string) 
  default = [""]
}

terraform {
  backend "s3" {
    bucket = ""
    key    = ""
    region = "us-east-1"
  }
}

resource "null_resource" "mysql" {
  provisioner "local-exec" {
    command = "mysql -u $DBUSERNAME -p$DBPASSWORD -h $HOSTNAME -e \"DROP USER $USERNAME@'%'\" || echo \"IgnoreAboveError\";"
    
    environment = {
      DBUSERNAME = "${var.DBUSERNAME}"
      DBPASSWORD = "${var.DBPASSWORD}"
      HOSTNAME   = "${var.hostname}"
      USERNAME   = "'${var.app}'"
    }
  }
}

module "account_manager_service_rds" {
  source     = "../rds-user-creation/"
  dbendpoint = "${var.hostname}"
  dbusername = "${var.DBUSERNAME}"
  dbpassword = "${var.DBPASSWORD}"
  username   = "${var.app}"
  host       = "${var.host}"
  privileges = "${var.privileges}"
  dbs        = "${var.dbs}"
}

output "account_manager_service_rds" {
  value = module.account_manager_service_rds.password
}

module "account_manager_service" {
  source      = "../modules/"
  app_name    = "${var.app}"
  path        = "${var.prefix}/${var.app}/${var.env}"

  vault_data_json = templatefile("${path.module}/data.json", {
    mysqluser                  = "${var.app}"
    mysqlpassword              = "${module.account_manager_service_rds.password}"
    }
  )
}

resource "null_resource" "mysql_flush_privileges" {
  provisioner "local-exec" {
    command = "mysql -u $DBUSERNAME -p$DBPASSWORD -h $HOSTNAME -e \"FLUSH PRIVILEGES;\" || echo \"IgnoreAboveError\";"

    environment = {
      DBUSERNAME = "${var.DBUSERNAME}"
      DBPASSWORD = "${var.DBPASSWORD}"
      HOSTNAME   = "${var.hostname}"
    }
  }
}