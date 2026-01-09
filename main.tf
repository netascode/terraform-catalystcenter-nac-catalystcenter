locals {
  catalyst_center = try(local.model.catalyst_center, {})

  # All sites defined in YAML configuration
  all_sites_in_yaml = concat(
    [for site in try(local.catalyst_center.sites.areas, []) : try("${site.parent_name}/${site.name}", "Global")],
    [for building in try(local.catalyst_center.sites.buildings, []) : try("${building.parent_name}/${building.name}", "Global")],
    [for floor in try(local.catalyst_center.sites.floors, []) : try("${floor.parent_name}/${floor.name}", "Global")]
  )

  # Sites that will be managed based on configuration
  sites = var.manage_specific_sites_only ? var.managed_sites : concat(
    [
      for site in try(local.catalyst_center.sites.areas, []) : try("${site.parent_name}/${site.name}", "Global")
      if length(var.managed_sites) == 0 && !var.manage_global_settings ||
      anytrue([
        for prefix in var.managed_sites :
        startswith(try("${site.parent_name}/${site.name}", "Global"), prefix)
      ])
    ],
    [
      for building in try(local.catalyst_center.sites.buildings, []) : try("${building.parent_name}/${building.name}", "Global")
      if length(var.managed_sites) == 0 && !var.manage_global_settings ||
      anytrue([
        for prefix in var.managed_sites :
        startswith(try("${building.parent_name}/${building.name}", "Global"), prefix)
      ])
    ],
    [
      for floor in try(local.catalyst_center.sites.floors, []) : try("${floor.parent_name}/${floor.name}", "Global")
      if length(var.managed_sites) == 0 && !var.manage_global_settings ||
      anytrue([
        for prefix in var.managed_sites :
        startswith(try("${floor.parent_name}/${floor.name}", "Global"), prefix)
      ])
    ]
  )

  # Sites in managed_sites that don't exist in YAML
  missing_managed_sites = [
    for site in var.managed_sites :
    site
    if !contains(local.all_sites_in_yaml, site) && length(var.managed_sites) > 0
  ]

  missing_sites_error = length(local.missing_managed_sites) > 0 ? "❌ The following sites specified in managed_sites are not found in YAML configuration:\n\n${join("\n", [for s in local.missing_managed_sites : "  • ${s}"])}\n\nAction required: Ensure all sites in managed_sites exist in your YAML files or remove them from managed_sites." : ""
}

resource "terraform_data" "managed_sites_validation" {
  lifecycle {
    precondition {
      condition     = length(local.missing_managed_sites) == 0
      error_message = local.missing_sites_error
    }
  }
}
