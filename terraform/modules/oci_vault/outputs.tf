output "vault_name" {
  value = oci_kms_vault.vault.display_name
}

output "vault_ocid" {
  value = oci_kms_vault.vault.id
}
output "vault_management_endpoint" {
  value = oci_kms_vault.vault.management_endpoint
}

output "vault_crypto_endpoint" {
  value = oci_kms_vault.vault.crypto_endpoint
}

output "vault_master_key_id" {
  value = oci_kms_key.vault_master_key.id
}