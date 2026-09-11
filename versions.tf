terraform {
  required_version = ">= 1.15.0"

  # Must be bumped together with the module release tag.
  provider_meta "catalystcenter" {
    module_name = "NAC/0.4.7"
  }

  required_providers {
    catalystcenter = {
      source  = "CiscoDevNet/catalystcenter"
      version = "~> 0.6.1"
    }
    utils = {
      source  = "netascode/utils"
      version = ">= 2.0.0"
    }
    local = {
      source  = "hashicorp/local"
      version = ">= 2.3.0"
    }
    time = {
      source  = "hashicorp/time"
      version = ">= 0.12.1"
    }
  }
}
