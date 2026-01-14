variable "yaml_directories" {
  description = "List of paths to YAML directories."
  type        = list(string)
  default     = []
}

variable "yaml_files" {
  description = "List of paths to YAML files."
  type        = list(string)
  default     = []
}

variable "templates_directories" {
  description = "List of paths to templates directories."
  type        = list(string)
  default     = []
}

variable "model" {
  description = "As an alternative to YAML files, a native Terraform data structure can be provided as well."
  type        = map(any)
  default     = {}
}

variable "managed_sites" {
  description = "List of sites to be managed. By default all sites will be managed."
  type        = list(string)
  default     = []
}

variable "manage_global_settings" {
  description = "Flag indicating whether global settings should be managed, used in combination with managed_sites."
  type        = bool
  default     = false
}

variable "manage_specific_sites_only" {
  description = "If true, manage only the specified site listed in managed_sites. If false, also manage all child sites under each managed site."
  type        = bool
  default     = false

  validation {
    condition     = !var.manage_specific_sites_only || length(var.managed_sites) > 0
    error_message = "The manage_specific_sites_only variable can only be set to true when managed_sites is not empty."
  }
}

variable "use_bulk_api" {
  description = "Flag indicating whether to use the bulk API for faster operations."
  type        = bool
  default     = false
}

variable "bulk_site_provisioning" {
  description = "Site path for bulk device provisioning. When set with use_bulk_api=true, provisions all devices from this site and all child sites in a single bulk operation. Example: 'Global/Poland' will provision all devices under Poland hierarchy."
  type        = string
  default     = null

  validation {
    condition     = var.bulk_site_provisioning == null || var.use_bulk_api == true
    error_message = "The bulk_site_provisioning variable can only be used when use_bulk_api is set to true."
  }

  validation {
    condition = (
      var.bulk_site_provisioning == null ||
      (
        var.use_bulk_api == true &&
        can(regex("^Global(\\/[^/]+)*$", var.bulk_site_provisioning)) &&
        can(length(regexall("/", var.bulk_site_provisioning)) <= 4)
      )
    )
    error_message = "The bulk_site_provisioning must be a valid site hierarchy path starting with 'Global' (e.g., 'Global/Poland' or 'Global/Area1/Area2') with a maximum of 5 levels."
  }
}

variable "write_default_values_file" {
  description = "Write all default values to a YAML file. Value is a path pointing to the file to be created."
  type        = string
  default     = ""
}
