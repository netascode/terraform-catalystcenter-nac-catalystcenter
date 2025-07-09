
output "default_values" {
  description = "All default values."
  value       = local.defaults
}

output "model" {
  description = "Full model."
  value       = local.model
}


output "sites" {
  description = "List of sites managed by the module."
  value       = local.sites
}