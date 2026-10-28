
output "default_values" {
  description = "All default values."
  value       = local.defaults
}

output "model" {
  description = "Full model with write-only Day-N template parameter values omitted."
  value       = local.exported_model
}

output "sites" {
  description = "List of sites to be managed"
  value       = local.sites
}
