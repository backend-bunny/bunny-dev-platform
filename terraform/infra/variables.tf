variable "compartment_id" {
  description = "OCI Compartment ID"
  type        = string
}

variable "fingerprint" {
  description = "The fingerprint of the key to use for signing"
  type        = string
}

variable "private_key_path" {
  description = "Private key to use for signing"
  type        = string
}


variable "region" {
  description = "The region to connect to."
  type        = string
}

variable "tenancy_ocid" {
  description = "The tenancy OCID."
  type        = string
}

variable "user_ocid" {
  description = "The user OCID."
  type        = string
}

variable "ssh_authorized_keys" {
  description = "List of authorized SSH keys"
  type        = list(any)
}

variable "ssh_ingress_allowed_network" {
  description = "Network specified in CIDR (eg: 0.0.0.0/32) for allowed"
  type        = string
}

variable "object_storage_namespace" {
  description = "object storage namespace"
  type        = string
}

variable "k3s_secrets_file_path" {
  description = "Filepath to sops encrypted file containg secrets for k3s nodes"
  type        = string
}