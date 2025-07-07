locals {
  catalyst_center = try(local.model.catalyst_center, {})

  sites = [
    for site in try(local.catalyst_center.sites.areas, []) : try("${site.parent_name}/${site.name}", "Global")
    if length(var.managed_sites) == 0 ||
    anytrue([
      for prefix in var.managed_sites :
      startswith(try("${site.parent_name}/${site.name}", "Global"), prefix)
    ])
  ]
}
