terraform {
  required_providers {
    oci = {
      source  = "oracle/oci"
      version = "~> 6.0"
    }
  }
}

resource "oci_kms_vault" "vault" {
  compartment_id = var.compartment_id
  display_name   = "${var.vault_name}-vault"
  vault_type     = "DEFAULT"
}

resource "oci_kms_key" "vault_master_key" {
  compartment_id      = var.compartment_id
  display_name        = "${var.vault_name}-key"
  management_endpoint = oci_kms_vault.vault.management_endpoint
  key_shape {
    algorithm = "AES"
    length    = 32
  }
}