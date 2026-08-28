locals {
  _raw = try(local.catalyst_center.sites, {})

  # Areas nest arbitrarily deep via a child `areas` list. Terraform has no
  # recursion, so the tree is descended one local per level (l0..l10, matching
  # catalystcenter_area.area_0..area_10 below). Top-level areas have no
  # parent_name and get "Global"; each deeper level derives parent_name from its
  # parent's computed _self path. Buildings/floors nest under their parent area.
  _area_l0 = [
    for a in try(local._raw.areas, []) : {
      name                  = a.name
      parent_name           = "Global"
      _self                 = "Global/${a.name}"
      _children             = try(a.areas, [])
      _buildings            = try(a.buildings, [])
      network_settings      = try(a.network_settings, null)
      ip_pools_reservations = try(a.network_settings.ip_pools_reservations, a.ip_pools_reservations, null)
    }
  ]

  _area_l1  = flatten([for p in local._area_l0 : [for a in p._children : { name = a.name, parent_name = p._self, _self = "${p._self}/${a.name}", _children = try(a.areas, []), _buildings = try(a.buildings, []), network_settings = try(a.network_settings, null), ip_pools_reservations = try(a.network_settings.ip_pools_reservations, a.ip_pools_reservations, null) }]])
  _area_l2  = flatten([for p in local._area_l1 : [for a in p._children : { name = a.name, parent_name = p._self, _self = "${p._self}/${a.name}", _children = try(a.areas, []), _buildings = try(a.buildings, []), network_settings = try(a.network_settings, null), ip_pools_reservations = try(a.network_settings.ip_pools_reservations, a.ip_pools_reservations, null) }]])
  _area_l3  = flatten([for p in local._area_l2 : [for a in p._children : { name = a.name, parent_name = p._self, _self = "${p._self}/${a.name}", _children = try(a.areas, []), _buildings = try(a.buildings, []), network_settings = try(a.network_settings, null), ip_pools_reservations = try(a.network_settings.ip_pools_reservations, a.ip_pools_reservations, null) }]])
  _area_l4  = flatten([for p in local._area_l3 : [for a in p._children : { name = a.name, parent_name = p._self, _self = "${p._self}/${a.name}", _children = try(a.areas, []), _buildings = try(a.buildings, []), network_settings = try(a.network_settings, null), ip_pools_reservations = try(a.network_settings.ip_pools_reservations, a.ip_pools_reservations, null) }]])
  _area_l5  = flatten([for p in local._area_l4 : [for a in p._children : { name = a.name, parent_name = p._self, _self = "${p._self}/${a.name}", _children = try(a.areas, []), _buildings = try(a.buildings, []), network_settings = try(a.network_settings, null), ip_pools_reservations = try(a.network_settings.ip_pools_reservations, a.ip_pools_reservations, null) }]])
  _area_l6  = flatten([for p in local._area_l5 : [for a in p._children : { name = a.name, parent_name = p._self, _self = "${p._self}/${a.name}", _children = try(a.areas, []), _buildings = try(a.buildings, []), network_settings = try(a.network_settings, null), ip_pools_reservations = try(a.network_settings.ip_pools_reservations, a.ip_pools_reservations, null) }]])
  _area_l7  = flatten([for p in local._area_l6 : [for a in p._children : { name = a.name, parent_name = p._self, _self = "${p._self}/${a.name}", _children = try(a.areas, []), _buildings = try(a.buildings, []), network_settings = try(a.network_settings, null), ip_pools_reservations = try(a.network_settings.ip_pools_reservations, a.ip_pools_reservations, null) }]])
  _area_l8  = flatten([for p in local._area_l7 : [for a in p._children : { name = a.name, parent_name = p._self, _self = "${p._self}/${a.name}", _children = try(a.areas, []), _buildings = try(a.buildings, []), network_settings = try(a.network_settings, null), ip_pools_reservations = try(a.network_settings.ip_pools_reservations, a.ip_pools_reservations, null) }]])
  _area_l9  = flatten([for p in local._area_l8 : [for a in p._children : { name = a.name, parent_name = p._self, _self = "${p._self}/${a.name}", _children = try(a.areas, []), _buildings = try(a.buildings, []), network_settings = try(a.network_settings, null), ip_pools_reservations = try(a.network_settings.ip_pools_reservations, a.ip_pools_reservations, null) }]])
  _area_l10 = flatten([for p in local._area_l9 : [for a in p._children : { name = a.name, parent_name = p._self, _self = "${p._self}/${a.name}", _children = try(a.areas, []), _buildings = try(a.buildings, []), network_settings = try(a.network_settings, null), ip_pools_reservations = try(a.network_settings.ip_pools_reservations, a.ip_pools_reservations, null) }]])

  _all_area_levels = concat(
    local._area_l0, local._area_l1, local._area_l2, local._area_l3,
    local._area_l4, local._area_l5, local._area_l6, local._area_l7,
    local._area_l8, local._area_l9, local._area_l10,
  )

  # Flat areas — kept lean (name + parent_name only) to avoid object-type
  # inconsistency errors from variable-shaped network_settings.
  flat_areas = [
    for a in local._all_area_levels : {
      name        = a.name
      parent_name = a.parent_name
    }
  ]

  # Network settings keyed by full hierarchy (map values need not share a type),
  # consumed by cc_network_settings.tf. Only areas that actually define settings.
  area_network_settings = {
    for a in local._all_area_levels :
    a._self => a.network_settings
    if try(a.network_settings, null) != null
  }

  # IP pool reservations keyed by full hierarchy, consumed by cc_network_settings.tf.
  area_ip_pool_reservations = {
    for a in local._all_area_levels :
    a._self => a.ip_pools_reservations
    if try(a.ip_pools_reservations, null) != null
  }

  # Global-level network settings (dedicated top-level `global:` key, not part of
  # the area tree).
  global_network_settings = try(local._raw.global.network_settings, null)

  # Flat buildings with computed parent hierarchy
  flat_buildings = flatten([
    for a in local._all_area_levels : [
      for b in a._buildings : merge(b, { parent_name = a._self })
    ]
  ])

  # Flat floors with computed parent hierarchy
  flat_floors = flatten([
    for b in local.flat_buildings : [
      for f in try(b.floors, []) : merge(f, {
        parent_name = "${b.parent_name}/${b.name}"
      })
    ]
  ])
}

locals {
  # All sites defined in YAML configuration.
  # flat_areas/flat_buildings/flat_floors are the flattened result of descending
  # the nested area tree; each carries a computed full-hierarchy parent_name, so
  # full paths are just "${parent_name}/${name}".
  all_sites_in_yaml = concat(
    [for site in local.flat_areas : "${site.parent_name}/${site.name}"],
    [for building in local.flat_buildings : "${building.parent_name}/${building.name}"],
    [for floor in local.flat_floors : "${floor.parent_name}/${floor.name}"]
  )

  # Sites that will be managed based on configuration
  sites = var.manage_specific_sites_only ? var.managed_sites : concat(
    [
      for site in local.flat_areas : "${site.parent_name}/${site.name}"
      if length(var.managed_sites) == 0 && !var.manage_global_settings ||
      anytrue([
        for prefix in var.managed_sites :
        startswith("${site.parent_name}/${site.name}", prefix)
      ])
    ],
    [
      for building in local.flat_buildings : "${building.parent_name}/${building.name}"
      if length(var.managed_sites) == 0 && !var.manage_global_settings ||
      anytrue([
        for prefix in var.managed_sites :
        startswith("${building.parent_name}/${building.name}", prefix)
      ])
    ],
    [
      for floor in local.flat_floors : "${floor.parent_name}/${floor.name}"
      if length(var.managed_sites) == 0 && !var.manage_global_settings ||
      anytrue([
        for prefix in var.managed_sites :
        startswith("${floor.parent_name}/${floor.name}", prefix)
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

# ============================================================================
# DATA SOURCES
# ============================================================================

data "catalystcenter_site" "global" {
  name_hierarchy = "Global"
}

data "catalystcenter_sites" "all_sites" {
}

# ============================================================================
# BULK API RESOURCES (when use_bulk_api = true)
# ============================================================================

resource "catalystcenter_areas" "bulk_areas" {
  count = var.use_bulk_api && length([for area in local.flat_areas : area if contains(local.sites, "${try(area.parent_name, "Global")}/${area.name}")]) > 0 ? 1 : 0

  areas = {
    for area in local.flat_areas :
    "${try(area.parent_name, "Global")}/${area.name}" => {
      parent_name_hierarchy = try(area.parent_name, "Global")
      name                  = area.name
    }
    if contains(local.sites, "${try(area.parent_name, "Global")}/${area.name}")
  }

  depends_on = [catalystcenter_discovery.discovery, catalystcenter_credentials_cli.cli_credentials, catalystcenter_credentials_https_read.https_read_credentials, catalystcenter_credentials_https_write.https_write_credentials, catalystcenter_credentials_snmpv3.snmpv3_credentials, catalystcenter_credentials_snmpv2_read.snmpv2_read_credentials, catalystcenter_credentials_snmpv2_write.snmpv2_write_credentials]
}

resource "catalystcenter_buildings" "bulk_buildings" {
  count = var.use_bulk_api && length([for building in local.flat_buildings : building if contains(local.sites, "${building.parent_name}/${building.name}")]) > 0 ? 1 : 0

  buildings = {
    for building in local.flat_buildings :
    "${building.parent_name}/${building.name}" => {
      parent_name_hierarchy = building.parent_name
      name                  = building.name
      country               = try(building.country, local.defaults.catalyst_center.sites.buildings.country, null)
      address               = try(building.address, local.defaults.catalyst_center.sites.buildings.address, null)
      latitude              = try(floor(building.latitude * 100000 + 0.5) / 100000, local.defaults.catalyst_center.sites.buildings.latitude, null)
      longitude             = try(floor(building.longitude * 100000 + 0.5) / 100000, local.defaults.catalyst_center.sites.buildings.longitude, null)
    }
    if contains(local.sites, "${building.parent_name}/${building.name}")
  }

  depends_on = [catalystcenter_areas.bulk_areas, catalystcenter_credentials_cli.cli_credentials, catalystcenter_credentials_https_read.https_read_credentials, catalystcenter_credentials_https_write.https_write_credentials, catalystcenter_credentials_snmpv3.snmpv3_credentials, catalystcenter_credentials_snmpv2_read.snmpv2_read_credentials, catalystcenter_credentials_snmpv2_write.snmpv2_write_credentials]
}

resource "catalystcenter_floors" "bulk_floors" {
  count = var.use_bulk_api && length([for floor in local.flat_floors : floor if contains(local.sites, "${floor.parent_name}/${floor.name}")]) > 0 ? 1 : 0

  floors = {
    for floor in local.flat_floors :
    "${floor.parent_name}/${floor.name}" => {
      parent_name_hierarchy = floor.parent_name
      name                  = floor.name
      floor_number          = try(floor.floor_number, local.defaults.catalyst_center.sites.floors.floor_number, null)
      rf_model              = try(floor.rf_model, local.defaults.catalyst_center.sites.floors.rf_model, null)
      width                 = try(floor(floor.width * 1000 + 0.5) / 1000, local.defaults.catalyst_center.sites.floors.width, null)
      length                = try(floor(floor.length * 1000 + 0.5) / 1000, local.defaults.catalyst_center.sites.floors.length, null)
      height                = try(floor(floor.height * 1000 + 0.5) / 1000, local.defaults.catalyst_center.sites.floors.height, null)
      units_of_measure      = try(floor.units_of_measure, local.defaults.catalyst_center.sites.floors.units_of_measure, null)
    }
    if contains(local.sites, "${floor.parent_name}/${floor.name}")
  }

  depends_on = [catalystcenter_building.building, catalystcenter_buildings.bulk_buildings, catalystcenter_credentials_cli.cli_credentials, catalystcenter_credentials_https_read.https_read_credentials, catalystcenter_credentials_https_write.https_write_credentials, catalystcenter_credentials_snmpv3.snmpv3_credentials, catalystcenter_credentials_snmpv2_read.snmpv2_read_credentials, catalystcenter_credentials_snmpv2_write.snmpv2_write_credentials]
}

# ============================================================================
# INDIVIDUAL API RESOURCES (when use_bulk_api = false)
# ============================================================================

## 1st level area Global/area
resource "catalystcenter_area" "area_0" {
  for_each = { for area in local.flat_areas : "${area.parent_name}/${area.name}" => area if !var.use_bulk_api && try(area.parent_name, "") == "Global" && contains(local.sites, "Global/${area.name}") }

  name      = each.value.name
  parent_id = try(data.catalystcenter_site.global.id, null)

  depends_on = [catalystcenter_discovery.discovery, catalystcenter_credentials_cli.cli_credentials, catalystcenter_credentials_https_read.https_read_credentials, catalystcenter_credentials_https_write.https_write_credentials, catalystcenter_credentials_snmpv3.snmpv3_credentials, catalystcenter_credentials_snmpv2_read.snmpv2_read_credentials, catalystcenter_credentials_snmpv2_write.snmpv2_write_credentials]
}

# 2nd level area
resource "catalystcenter_area" "area_1" {
  for_each = { for area in local.flat_areas : "${area.parent_name}/${area.name}" => area if !var.use_bulk_api && length(regexall("/", try(area.parent_name, ""))) == 1 && contains(local.sites, try("${area.parent_name}/${area.name}", "")) }

  name      = each.value.name
  parent_id = try(catalystcenter_area.area_0[each.value.parent_name].id, local.data_source_site_list[each.value.parent_name], data.catalystcenter_site.global.id, null)

  depends_on = [catalystcenter_area.area_0, catalystcenter_credentials_cli.cli_credentials, catalystcenter_credentials_https_read.https_read_credentials, catalystcenter_credentials_https_write.https_write_credentials, catalystcenter_credentials_snmpv3.snmpv3_credentials, catalystcenter_credentials_snmpv2_read.snmpv2_read_credentials, catalystcenter_credentials_snmpv2_write.snmpv2_write_credentials]
}

# 3rd level area
resource "catalystcenter_area" "area_2" {
  for_each = { for area in local.flat_areas : "${area.parent_name}/${area.name}" => area if !var.use_bulk_api && length(regexall("/", try(area.parent_name, ""))) == 2 && contains(local.sites, try("${area.parent_name}/${area.name}", "")) }

  name      = each.value.name
  parent_id = try(catalystcenter_area.area_1[each.value.parent_name].id, local.data_source_site_list[each.value.parent_name], data.catalystcenter_site.global.id, null)

  depends_on = [catalystcenter_area.area_1, catalystcenter_credentials_cli.cli_credentials, catalystcenter_credentials_https_read.https_read_credentials, catalystcenter_credentials_https_write.https_write_credentials, catalystcenter_credentials_snmpv3.snmpv3_credentials, catalystcenter_credentials_snmpv2_read.snmpv2_read_credentials, catalystcenter_credentials_snmpv2_write.snmpv2_write_credentials]
}

# 4th level area
resource "catalystcenter_area" "area_3" {
  for_each = { for area in local.flat_areas : "${area.parent_name}/${area.name}" => area if !var.use_bulk_api && length(regexall("/", try(area.parent_name, ""))) == 3 && contains(local.sites, try("${area.parent_name}/${area.name}", "")) }

  name      = each.value.name
  parent_id = try(catalystcenter_area.area_2[each.value.parent_name].id, local.data_source_site_list[each.value.parent_name], data.catalystcenter_site.global.id, null)

  depends_on = [catalystcenter_area.area_2, catalystcenter_credentials_cli.cli_credentials, catalystcenter_credentials_https_read.https_read_credentials, catalystcenter_credentials_https_write.https_write_credentials, catalystcenter_credentials_snmpv3.snmpv3_credentials, catalystcenter_credentials_snmpv2_read.snmpv2_read_credentials, catalystcenter_credentials_snmpv2_write.snmpv2_write_credentials]
}

# 5th level area
resource "catalystcenter_area" "area_4" {
  for_each = { for area in local.flat_areas : "${area.parent_name}/${area.name}" => area if !var.use_bulk_api && length(regexall("/", try(area.parent_name, ""))) == 4 && contains(local.sites, try("${area.parent_name}/${area.name}", "")) }

  name      = each.value.name
  parent_id = try(catalystcenter_area.area_3[each.value.parent_name].id, local.data_source_site_list[each.value.parent_name], data.catalystcenter_site.global.id, null)

  depends_on = [catalystcenter_area.area_3, catalystcenter_credentials_cli.cli_credentials, catalystcenter_credentials_https_read.https_read_credentials, catalystcenter_credentials_https_write.https_write_credentials, catalystcenter_credentials_snmpv3.snmpv3_credentials, catalystcenter_credentials_snmpv2_read.snmpv2_read_credentials, catalystcenter_credentials_snmpv2_write.snmpv2_write_credentials]
}

# 6th level area
resource "catalystcenter_area" "area_5" {
  for_each = { for area in local.flat_areas : "${area.parent_name}/${area.name}" => area if !var.use_bulk_api && length(regexall("/", try(area.parent_name, ""))) == 5 && contains(local.sites, try("${area.parent_name}/${area.name}", "")) }

  name       = each.value.name
  parent_id  = try(catalystcenter_area.area_4[each.value.parent_name].id, local.data_source_site_list[each.value.parent_name], data.catalystcenter_site.global.id, null)
  depends_on = [catalystcenter_area.area_4, catalystcenter_credentials_cli.cli_credentials, catalystcenter_credentials_https_read.https_read_credentials, catalystcenter_credentials_https_write.https_write_credentials, catalystcenter_credentials_snmpv3.snmpv3_credentials, catalystcenter_credentials_snmpv2_read.snmpv2_read_credentials, catalystcenter_credentials_snmpv2_write.snmpv2_write_credentials]
}

# 7th level area
resource "catalystcenter_area" "area_6" {
  for_each = { for area in local.flat_areas : "${area.parent_name}/${area.name}" => area if !var.use_bulk_api && length(regexall("/", try(area.parent_name, ""))) == 6 && contains(local.sites, try("${area.parent_name}/${area.name}", "")) }

  name      = each.value.name
  parent_id = try(catalystcenter_area.area_5[each.value.parent_name].id, local.data_source_site_list[each.value.parent_name], data.catalystcenter_site.global.id, null)

  depends_on = [catalystcenter_area.area_5, catalystcenter_credentials_cli.cli_credentials, catalystcenter_credentials_https_read.https_read_credentials, catalystcenter_credentials_https_write.https_write_credentials, catalystcenter_credentials_snmpv3.snmpv3_credentials, catalystcenter_credentials_snmpv2_read.snmpv2_read_credentials, catalystcenter_credentials_snmpv2_write.snmpv2_write_credentials]
}

# 8th level area
resource "catalystcenter_area" "area_7" {
  for_each = { for area in local.flat_areas : "${area.parent_name}/${area.name}" => area if !var.use_bulk_api && length(regexall("/", try(area.parent_name, ""))) == 7 && contains(local.sites, try("${area.parent_name}/${area.name}", "")) }

  name       = each.value.name
  parent_id  = try(catalystcenter_area.area_6[each.value.parent_name].id, local.data_source_site_list[each.value.parent_name], data.catalystcenter_site.global.id, null)
  depends_on = [catalystcenter_area.area_6, catalystcenter_credentials_cli.cli_credentials, catalystcenter_credentials_https_read.https_read_credentials, catalystcenter_credentials_https_write.https_write_credentials, catalystcenter_credentials_snmpv3.snmpv3_credentials, catalystcenter_credentials_snmpv2_read.snmpv2_read_credentials, catalystcenter_credentials_snmpv2_write.snmpv2_write_credentials]
}

# 9th level area
resource "catalystcenter_area" "area_8" {
  for_each = { for area in local.flat_areas : "${area.parent_name}/${area.name}" => area if !var.use_bulk_api && length(regexall("/", try(area.parent_name, ""))) == 8 && contains(local.sites, try("${area.parent_name}/${area.name}", "")) }

  name      = each.value.name
  parent_id = try(catalystcenter_area.area_7[each.value.parent_name].id, local.data_source_site_list[each.value.parent_name], data.catalystcenter_site.global.id, null)

  depends_on = [catalystcenter_area.area_7, catalystcenter_credentials_cli.cli_credentials, catalystcenter_credentials_https_read.https_read_credentials, catalystcenter_credentials_https_write.https_write_credentials, catalystcenter_credentials_snmpv3.snmpv3_credentials, catalystcenter_credentials_snmpv2_read.snmpv2_read_credentials, catalystcenter_credentials_snmpv2_write.snmpv2_write_credentials]
}

# 10th level area
resource "catalystcenter_area" "area_9" {
  for_each = { for area in local.flat_areas : "${area.parent_name}/${area.name}" => area if !var.use_bulk_api && length(regexall("/", try(area.parent_name, ""))) == 9 && contains(local.sites, try("${area.parent_name}/${area.name}", "")) }

  name      = each.value.name
  parent_id = try(catalystcenter_area.area_8[each.value.parent_name].id, local.data_source_site_list[each.value.parent_name], data.catalystcenter_site.global.id, null)

  depends_on = [catalystcenter_area.area_8, catalystcenter_credentials_cli.cli_credentials, catalystcenter_credentials_https_read.https_read_credentials, catalystcenter_credentials_https_write.https_write_credentials, catalystcenter_credentials_snmpv3.snmpv3_credentials, catalystcenter_credentials_snmpv2_read.snmpv2_read_credentials, catalystcenter_credentials_snmpv2_write.snmpv2_write_credentials]
}

# 11th level area 
resource "catalystcenter_area" "area_10" {
  for_each = { for area in local.flat_areas : "${area.parent_name}/${area.name}" => area if !var.use_bulk_api && length(regexall("/", try(area.parent_name, ""))) == 10 && contains(local.sites, try("${area.parent_name}/${area.name}", "")) }

  name      = each.value.name
  parent_id = try(catalystcenter_area.area_9[each.value.parent_name].id, local.data_source_site_list[each.value.parent_name], data.catalystcenter_site.global.id, null)

  depends_on = [catalystcenter_area.area_9, catalystcenter_credentials_cli.cli_credentials, catalystcenter_credentials_https_read.https_read_credentials, catalystcenter_credentials_https_write.https_write_credentials, catalystcenter_credentials_snmpv3.snmpv3_credentials, catalystcenter_credentials_snmpv2_read.snmpv2_read_credentials, catalystcenter_credentials_snmpv2_write.snmpv2_write_credentials]
}

resource "catalystcenter_building" "building" {
  for_each = { for building in local.flat_buildings : "${building.parent_name}/${building.name}" => building if !var.use_bulk_api && contains(local.sites, try("${building.parent_name}/${building.name}", "")) }

  name      = each.value.name
  parent_id = try(catalystcenter_area.area_10[each.value.parent_name].id, catalystcenter_area.area_9[each.value.parent_name].id, catalystcenter_area.area_8[each.value.parent_name].id, catalystcenter_area.area_7[each.value.parent_name].id, catalystcenter_area.area_6[each.value.parent_name].id, catalystcenter_area.area_5[each.value.parent_name].id, catalystcenter_area.area_4[each.value.parent_name].id, catalystcenter_area.area_3[each.value.parent_name].id, catalystcenter_area.area_2[each.value.parent_name].id, catalystcenter_area.area_1[each.value.parent_name].id, catalystcenter_area.area_0[each.value.parent_name].id, local.data_source_site_list[each.value.parent_name], data.catalystcenter_site.global.id, null)
  country   = try(each.value.country, local.defaults.catalyst_center.sites.buildings.country, null)
  address   = try(each.value.address, local.defaults.catalyst_center.sites.buildings.address, null)
  latitude  = try(floor(each.value.latitude * 100000 + 0.5) / 100000, local.defaults.catalyst_center.sites.buildings.latitude, null)
  longitude = try(floor(each.value.longitude * 100000 + 0.5) / 100000, local.defaults.catalyst_center.sites.buildings.longitude, null)

  depends_on = [catalystcenter_area.area_0, catalystcenter_area.area_1, catalystcenter_area.area_2, catalystcenter_area.area_3, catalystcenter_area.area_4, catalystcenter_area.area_5, catalystcenter_area.area_6, catalystcenter_area.area_7, catalystcenter_area.area_8, catalystcenter_area.area_9, catalystcenter_area.area_10, catalystcenter_credentials_cli.cli_credentials, catalystcenter_credentials_https_read.https_read_credentials, catalystcenter_credentials_https_write.https_write_credentials, catalystcenter_credentials_snmpv3.snmpv3_credentials, catalystcenter_credentials_snmpv2_read.snmpv2_read_credentials, catalystcenter_credentials_snmpv2_write.snmpv2_write_credentials]
}

resource "catalystcenter_floor" "floor" {
  for_each = { for floor in local.flat_floors : "${floor.parent_name}/${floor.name}" => floor if !var.use_bulk_api && contains(local.sites, try("${floor.parent_name}/${floor.name}", "")) }

  name             = each.value.name
  parent_id        = try(catalystcenter_building.building[each.value.parent_name].id, local.data_source_site_list[each.value.parent_name], data.catalystcenter_site.global.id, null)
  floor_number     = try(each.value.floor_number, local.defaults.catalyst_center.sites.floors.floor_number, null)
  rf_model         = try(each.value.rf_model, local.defaults.catalyst_center.sites.floors.rf_model, null)
  width            = try(floor(each.value.width * 1000 + 0.5) / 1000, local.defaults.catalyst_center.sites.floors.width, null)
  length           = try(floor(each.value.length * 1000 + 0.5) / 1000, local.defaults.catalyst_center.sites.floors.length, null)
  height           = try(floor(each.value.height * 1000 + 0.5) / 1000, local.defaults.catalyst_center.sites.floors.height, null)
  units_of_measure = try(each.value.units_of_measure, local.defaults.catalyst_center.sites.floors.units_of_measure, null)

  depends_on = [catalystcenter_building.building, catalystcenter_credentials_cli.cli_credentials, catalystcenter_credentials_https_read.https_read_credentials, catalystcenter_credentials_https_write.https_write_credentials, catalystcenter_credentials_snmpv3.snmpv3_credentials, catalystcenter_credentials_snmpv2_read.snmpv2_read_credentials, catalystcenter_credentials_snmpv2_write.snmpv2_write_credentials]
}

resource "catalystcenter_floor_image" "floor_image" {
  for_each = {
    for floor in local.flat_floors :
    "${floor.parent_name}/${floor.name}" => floor
    if try(floor.image_path, null) != null && contains(local.sites, try("${floor.parent_name}/${floor.name}", ""))
  }

  floor_id    = var.use_bulk_api ? coalesce(try(local.site_id_list_bulk["${each.value.parent_name}/${each.value.name}"], null), local.data_source_created_sites_list["${each.value.parent_name}/${each.value.name}"]) : catalystcenter_floor.floor[each.key].id
  source_path = each.value.image_path

  depends_on = [catalystcenter_floor.floor, catalystcenter_floors.bulk_floors]
}

resource "catalystcenter_planned_access_point_position" "planned_ap" {
  for_each = {
    for ap in flatten([
      for floor in local.flat_floors : [
        for planned_ap in try(floor.planned_access_points, []) : merge(planned_ap, {
          floor_key = "${floor.parent_name}/${floor.name}"
        })
      ]
      if contains(local.sites, try("${floor.parent_name}/${floor.name}", ""))
    ]) : "${ap.floor_key}/${ap.name}" => ap
  }

  floor_id    = var.use_bulk_api ? coalesce(try(local.site_id_list_bulk[each.value.floor_key], null), local.data_source_created_sites_list[each.value.floor_key]) : catalystcenter_floor.floor[each.value.floor_key].id
  name        = each.value.name
  ap_type     = each.value.ap_type
  position_x  = each.value.position_x
  position_y  = each.value.position_y
  position_z  = try(each.value.position_z, null)
  mac_address = try(each.value.mac_address, null)
  radios = [for radio in try(each.value.radios, []) : {
    bands             = try([radio.band], null)
    channel           = try(radio.channel, null)
    tx_power          = try(radio.tx_power, null)
    antenna_name      = try(radio.antenna_name, null)
    antenna_azimuth   = try(radio.antenna_azimuth, null)
    antenna_elevation = try(radio.antenna_elevation, null)
  }]

  depends_on = [catalystcenter_floor.floor, catalystcenter_floors.bulk_floors, catalystcenter_floor_image.floor_image]
}

locals {
  site_id_list = merge(
    { for k, v in catalystcenter_area.area_0 : k => v.id },
    { for k, v in catalystcenter_area.area_1 : k => v.id },
    { for k, v in catalystcenter_area.area_2 : k => v.id },
    { for k, v in catalystcenter_area.area_3 : k => v.id },
    { for k, v in catalystcenter_area.area_4 : k => v.id },
    { for k, v in catalystcenter_area.area_5 : k => v.id },
    { for k, v in catalystcenter_area.area_6 : k => v.id },
    { for k, v in catalystcenter_area.area_7 : k => v.id },
    { for k, v in catalystcenter_area.area_8 : k => v.id },
    { for k, v in catalystcenter_area.area_9 : k => v.id },
    { for k, v in catalystcenter_area.area_10 : k => v.id },
    { for k, v in catalystcenter_building.building : k => v.id },
    { for k, v in catalystcenter_floor.floor : k => v.id }
  )

  data_source_site_list = { for site in data.catalystcenter_sites.all_sites.sites : coalesce(site.name_hierarchy, site.name) => site.id }
}

data "catalystcenter_sites" "created_sites" {
  depends_on = [catalystcenter_areas.bulk_areas, catalystcenter_buildings.bulk_buildings, catalystcenter_floors.bulk_floors, catalystcenter_area.area_0, catalystcenter_area.area_1, catalystcenter_area.area_2, catalystcenter_area.area_3, catalystcenter_area.area_4, catalystcenter_area.area_5, catalystcenter_area.area_6, catalystcenter_area.area_7, catalystcenter_area.area_8, catalystcenter_area.area_9, catalystcenter_area.area_10, catalystcenter_building.building, catalystcenter_floor.floor]
}

locals {
  data_source_created_sites_list = { for site in data.catalystcenter_sites.created_sites.sites : coalesce(site.name_hierarchy, site.name) => site.id }

  site_id_list_bulk = merge(
    var.use_bulk_api && length(catalystcenter_areas.bulk_areas) > 0 ?
    {
      for s in catalystcenter_areas.bulk_areas[0].areas :
      "${s.parent_name_hierarchy}/${s.name}" => s.id
    } : {},

    var.use_bulk_api && length(catalystcenter_buildings.bulk_buildings) > 0 ?
    {
      for b in catalystcenter_buildings.bulk_buildings[0].buildings :
      "${b.parent_name_hierarchy}/${b.name}" => b.id
    } : {},

    var.use_bulk_api && length(catalystcenter_floors.bulk_floors) > 0 ?
    {
      for f in catalystcenter_floors.bulk_floors[0].floors :
      "${f.parent_name_hierarchy}/${f.name}" => f.id
    } : {}
  )
}