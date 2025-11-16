terraform {
  required_version = ">= 1.8.0"

  required_providers {
    catalystcenter = {
      source  = "CiscoDevNet/catalystcenter"
      version = ">= 0.4.3"
    }
    utils = {
      source  = "netascode/utils"
      version = ">= 1.0.0"
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
