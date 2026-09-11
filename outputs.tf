
output "default_values" {
  description = "All default values."
  value       = local.defaults
}

output "model" {
  description = "Full model."
  value       = local.model
}

output "sites" {
  description = "List of sites to be managed"
  value       = local.sites
}

# ---- Debug outputs: flattened site model ----

output "debug_flat_areas" {
  description = "All areas flattened, as full hierarchy strings"
  value       = [for a in local.flat_areas : "${a.parent_name}/${a.name}"]
}

output "debug_flat_areas_full" {
  description = "Flattened areas with name + computed parent_name"
  value       = local.flat_areas
}

output "debug_flat_buildings" {
  description = "Flattened buildings with computed parent hierarchy"
  value       = local.flat_buildings
}

output "debug_flat_floors" {
  description = "Flattened floors with computed parent hierarchy"
  value       = local.flat_floors
}

output "debug_sites" {
  description = "Final list of managed site hierarchies (drives contains() filters)"
  value       = local.sites
}

output "debug_area_tiers" {
  description = "Which area_N tier each area maps to (depth of parent_name)"
  value = {
    for a in local.flat_areas :
    "${a.parent_name}/${a.name}" => length(regexall("/", a.parent_name))
  }
}

output "debug_bulk_area_map" {
  description = "The areas map that would be sent to the bulk API"
  value = {
    for area in local.flat_areas :
    "${try(area.parent_name, "Global")}/${area.name}" => {
      parent_name_hierarchy = try(area.parent_name, "Global")
      name                  = area.name
    }
    if contains(local.sites, "${try(area.parent_name, "Global")}/${area.name}")
  }
}