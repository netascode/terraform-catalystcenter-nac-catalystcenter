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
}

variable "use_bulk_api" {
  description = "Flag indicating whether to use the bulk API for faster operations."
  type        = bool
  default     = false
}

variable "write_default_values_file" {
  description = "Write all default values to a YAML file. Value is a path pointing to the file to be created."
  type        = string
  default     = ""
}
