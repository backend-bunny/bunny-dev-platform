# Terraform for bootstraping k3s cluster on OCI (Oracle Cloud Infrastructure)

  backend "s3" {
    bucket = "terraform_state"
    key    = "bunny-dev-platform/infra/terraform.tfstate"
    region = "eu-stockholm-1"
    endpoints = {
        s3 = "https://axp6rc9euftn.compat.objectstorage.eu-stockholm-1.oraclecloud.com"
    }
    use_lockfile = true
    skip_region_validation      = true
    skip_credentials_validation = true
    skip_metadata_api_check     = true
    use_path_style              = true
  }