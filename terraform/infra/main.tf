module "main_vault" {
  source = "../modules/oci_vault"

  compartment_id = var.compartment_id
  vault_name     = "main"
}

module "terraform_state_bucket" {
  source = "git::https://github.com/backend-bunny/tf-s3-oracle-cloud.git//terraform?ref=v1.0.0"

  compartment_id           = var.compartment_id
  bucket_namespace         = var.object_storage_namespace
  bucket_name              = "terraform_state"
  service_account_email    = "terraform.oci@erenius.io"
  vault_id                 = module.main_vault.vault_ocid
  vault_managment_endpoint = module.main_vault.vault_management_endpoint
  vault_master_key_id      = module.main_vault.vault_master_key_id
}

#module "mgmt_cluster" {
#  source = "git::https://github.com/backend-bunny/tf-k3s-oracle-cloud.git//terraform?ref=v0.1.0"
#
#  compartment_id              = var.compartment_id
#  fingerprint                 = var.fingerprint
#  private_key_path            = var.private_key_path
#  region                      = var.region
#  ssh_authorized_keys         = var.ssh_authorized_keys
#  ssh_ingress_allowed_network = var.ssh_ingress_allowed_network
#  tenancy_ocid                = var.tenancy_ocid
#  user_ocid                   = var.user_ocid
#  #k3s_secrets_file_path       = var.k3s_secrets_file_path
#}