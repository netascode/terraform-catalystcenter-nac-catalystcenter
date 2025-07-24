locals {
  catalyst_center = try(local.model.catalyst_center, {})

  sites = var.manage_specific_sites_only ? var.managed_sites : concat(
    [
      for site in try(local.catalyst_center.sites.areas, []) : try("${site.parent_name}/${site.name}", "Global")
      if length(var.managed_sites) == 0 ||
      anytrue([
        for prefix in var.managed_sites :
        startswith(try("${site.parent_name}/${site.name}", "Global"), prefix)
      ])
    ],
    [
      for building in try(local.catalyst_center.sites.buildings, []) : try("${building.parent_name}/${building.name}", "Global")
      if length(var.managed_sites) == 0 ||
      anytrue([
        for prefix in var.managed_sites :
        startswith(try("${building.parent_name}/${building.name}", "Global"), prefix)
      ])
    ],
    [
      for floor in try(local.catalyst_center.sites.floors, []) : try("${floor.parent_name}/${floor.name}", "Global")
      if length(var.managed_sites) == 0 ||
      anytrue([
        for prefix in var.managed_sites :
        startswith(try("${floor.parent_name}/${floor.name}", "Global"), prefix)
      ])
    ]
  )
}
