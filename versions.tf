terraform {
  required_version = ">= 1.8.0"

  required_providers {
    catalystcenter = {
      source  = "CiscoDevNet/catalystcenter"
      version = ">= 0.1.19"
    }
    utils = {
      source  = "netascode/utils"
      version = ">= 0.2.6"
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
