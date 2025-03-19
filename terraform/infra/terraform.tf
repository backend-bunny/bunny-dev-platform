terraform {
  required_version = ">= 1.0.0"
  required_providers {
    oci = {
      source  = "oracle/oci"
      version = "~> 6.0"
      source  = "oracle/oci"
    }
    time = {
      source  = "hashicorp/time"
      version = "~> 0.12"
    }
  }
  backend "s3" {
    bucket    = "terraform_state"
    key       = "infra/terraform.tfstate"
    region    = "eu-stockholm-1"
    endpoints = { s3 = "https://axp6rc9euftn.compat.objectstorage.eu-stockholm-1.oci.customer-oci.com" }

    profile                     = "default"
    skip_region_validation      = true
    skip_credentials_validation = true
    skip_requesting_account_id  = true
    skip_metadata_api_check     = true
    skip_s3_checksum            = true
    use_path_style              = true
    use_lockfile                = true
  }

}
