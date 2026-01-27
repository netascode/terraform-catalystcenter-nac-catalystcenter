data "catalystcenter_site" "global" {
  name_hierarchy = "Global"
}

data "catalystcenter_sites" "all_sites" {
}

# ============================================================================
# BULK API RESOURCES (when use_bulk_api = true)
# ============================================================================

resource "catalystcenter_areas" "bulk_areas" {
  count = var.use_bulk_api && length([for area in try(local.catalyst_center.sites.areas, []) : area if contains(local.sites, "${try(area.parent_name, local.defaults.catalyst_center.sites.areas.parent_name)}/${area.name}")]) > 0 ? 1 : 0

  # Optional: set scope to limit which sites are managed
  scope = length(var.managed_sites) > 0 ? var.managed_sites[0] : null

  areas = {
    for area in try(local.catalyst_center.sites.areas, []) :
    "${try(area.parent_name, "Global")}/${area.name}" => {
      parent_name_hierarchy = try(area.parent_name, "Global")
      name                  = area.name
    }
    if contains(local.sites, "${try(area.parent_name, "Global")}/${area.name}")
  }

  depends_on = [catalystcenter_discovery.discovery, catalystcenter_credentials_cli.cli_credentials, catalystcenter_credentials_https_read.https_read_credentials, catalystcenter_credentials_https_write.https_write_credentials, catalystcenter_credentials_snmpv3.snmpv3_credentials, catalystcenter_credentials_snmpv2_read.snmpv2_read_credentials, catalystcenter_credentials_snmpv2_write.snmpv2_write_credentials]
}

resource "catalystcenter_buildings" "bulk_buildings" {
  count = var.use_bulk_api && length([for building in try(local.catalyst_center.sites.buildings, []) : building if contains(local.sites, "${building.parent_name}/${building.name}")]) > 0 ? 1 : 0

  scope = length(var.managed_sites) > 0 ? var.managed_sites[0] : null

  buildings = {
    for building in try(local.catalyst_center.sites.buildings, []) :
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
  count = var.use_bulk_api && length([for floor in try(local.catalyst_center.sites.floors, []) : floor if contains(local.sites, "${floor.parent_name}/${floor.name}")]) > 0 ? 1 : 0

  scope = length(var.managed_sites) > 0 ? var.managed_sites[0] : null

  floors = {
    for floor in try(local.catalyst_center.sites.floors, []) :
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
  for_each = var.use_bulk_api ? {} : { for area in try(local.catalyst_center.sites.areas, []) : "${area.parent_name}/${area.name}" => area if try(area.parent_name, "") == "Global" && contains(local.sites, "Global/${area.name}") }

  name      = each.value.name
  parent_id = try(data.catalystcenter_site.global.id, null)

  depends_on = [catalystcenter_discovery.discovery, catalystcenter_credentials_cli.cli_credentials, catalystcenter_credentials_https_read.https_read_credentials, catalystcenter_credentials_https_write.https_write_credentials, catalystcenter_credentials_snmpv3.snmpv3_credentials, catalystcenter_credentials_snmpv2_read.snmpv2_read_credentials, catalystcenter_credentials_snmpv2_write.snmpv2_write_credentials]
}

# 2nd level area Global/area/area
resource "catalystcenter_area" "area_1" {
  for_each = var.use_bulk_api ? {} : { for area in try(local.catalyst_center.sites.areas, []) : "${area.parent_name}/${area.name}" => area if length(regexall("\\/", try(area.parent_name, ""))) == 1 && contains(local.sites, try("${area.parent_name}/${area.name}", "")) }

  name      = each.value.name
  parent_id = try(catalystcenter_area.area_0[each.value.parent_name].id, local.data_source_site_list[each.value.parent_name], data.catalystcenter_site.global.id, null)

  depends_on = [catalystcenter_area.area_0, catalystcenter_credentials_cli.cli_credentials, catalystcenter_credentials_https_read.https_read_credentials, catalystcenter_credentials_https_write.https_write_credentials, catalystcenter_credentials_snmpv3.snmpv3_credentials, catalystcenter_credentials_snmpv2_read.snmpv2_read_credentials, catalystcenter_credentials_snmpv2_write.snmpv2_write_credentials]
}

# 3rd level area Global/area/area/area
resource "catalystcenter_area" "area_2" {
  for_each = var.use_bulk_api ? {} : { for area in try(local.catalyst_center.sites.areas, []) : "${area.parent_name}/${area.name}" => area if length(regexall("\\/", try(area.parent_name, ""))) == 2 && contains(local.sites, try("${area.parent_name}/${area.name}", "")) }

  name      = each.value.name
  parent_id = try(catalystcenter_area.area_1[each.value.parent_name].id, local.data_source_site_list[each.value.parent_name], data.catalystcenter_site.global.id, null)

  depends_on = [catalystcenter_area.area_1, catalystcenter_credentials_cli.cli_credentials, catalystcenter_credentials_https_read.https_read_credentials, catalystcenter_credentials_https_write.https_write_credentials, catalystcenter_credentials_snmpv3.snmpv3_credentials, catalystcenter_credentials_snmpv2_read.snmpv2_read_credentials, catalystcenter_credentials_snmpv2_write.snmpv2_write_credentials]
}

# 4th level area Global/area/area/area/area
resource "catalystcenter_area" "area_3" {
  for_each = var.use_bulk_api ? {} : { for area in try(local.catalyst_center.sites.areas, []) : "${area.parent_name}/${area.name}" => area if length(regexall("\\/", try(area.parent_name, ""))) == 3 && contains(local.sites, try("${area.parent_name}/${area.name}", "")) }

  name      = each.value.name
  parent_id = try(catalystcenter_area.area_2[each.value.parent_name].id, local.data_source_site_list[each.value.parent_name], data.catalystcenter_site.global.id, null)

  depends_on = [catalystcenter_area.area_2, catalystcenter_credentials_cli.cli_credentials, catalystcenter_credentials_https_read.https_read_credentials, catalystcenter_credentials_https_write.https_write_credentials, catalystcenter_credentials_snmpv3.snmpv3_credentials, catalystcenter_credentials_snmpv2_read.snmpv2_read_credentials, catalystcenter_credentials_snmpv2_write.snmpv2_write_credentials]
}

resource "catalystcenter_area" "area_4" {
  for_each = var.use_bulk_api ? {} : { for area in try(local.catalyst_center.sites.areas, []) : "${area.parent_name}/${area.name}" => area if length(regexall("\\/", try(area.parent_name, ""))) == 4 && contains(local.sites, try("${area.parent_name}/${area.name}", "")) }

  name      = each.value.name
  parent_id = try(catalystcenter_area.area_3[each.value.parent_name].id, local.data_source_site_list[each.value.parent_name], data.catalystcenter_site.global.id, null)

  depends_on = [catalystcenter_area.area_3, catalystcenter_credentials_cli.cli_credentials, catalystcenter_credentials_https_read.https_read_credentials, catalystcenter_credentials_https_write.https_write_credentials, catalystcenter_credentials_snmpv3.snmpv3_credentials, catalystcenter_credentials_snmpv2_read.snmpv2_read_credentials, catalystcenter_credentials_snmpv2_write.snmpv2_write_credentials]
}

resource "catalystcenter_area" "area_5" {
  for_each = var.use_bulk_api ? {} : { for area in try(local.catalyst_center.sites.areas, []) : "${area.parent_name}/${area.name}" => area if length(regexall("\\/", try(area.parent_name, ""))) == 5 && contains(local.sites, try("${area.parent_name}/${area.name}", "")) }

  name       = each.value.name
  parent_id  = try(catalystcenter_area.area_4[each.value.parent_name].id, local.data_source_site_list[each.value.parent_name], data.catalystcenter_site.global.id, null)
  depends_on = [catalystcenter_area.area_4, catalystcenter_credentials_cli.cli_credentials, catalystcenter_credentials_https_read.https_read_credentials, catalystcenter_credentials_https_write.https_write_credentials, catalystcenter_credentials_snmpv3.snmpv3_credentials, catalystcenter_credentials_snmpv2_read.snmpv2_read_credentials, catalystcenter_credentials_snmpv2_write.snmpv2_write_credentials]
}

resource "catalystcenter_area" "area_6" {
  for_each = var.use_bulk_api ? {} : { for area in try(local.catalyst_center.sites.areas, []) : "${area.parent_name}/${area.name}" => area if length(regexall("\\/", try(area.parent_name, ""))) == 6 && contains(local.sites, try("${area.parent_name}/${area.name}", "")) }

  name      = each.value.name
  parent_id = try(catalystcenter_area.area_5[each.value.parent_name].id, local.data_source_site_list[each.value.parent_name], data.catalystcenter_site.global.id, null)

  depends_on = [catalystcenter_area.area_5, catalystcenter_credentials_cli.cli_credentials, catalystcenter_credentials_https_read.https_read_credentials, catalystcenter_credentials_https_write.https_write_credentials, catalystcenter_credentials_snmpv3.snmpv3_credentials, catalystcenter_credentials_snmpv2_read.snmpv2_read_credentials, catalystcenter_credentials_snmpv2_write.snmpv2_write_credentials]
}


resource "catalystcenter_area" "area_7" {
  for_each = var.use_bulk_api ? {} : { for area in try(local.catalyst_center.sites.areas, []) : "${area.parent_name}/${area.name}" => area if length(regexall("\\/", try(area.parent_name, ""))) == 7 && contains(local.sites, try("${area.parent_name}/${area.name}", "")) }

  name       = each.value.name
  parent_id  = try(catalystcenter_area.area_6[each.value.parent_name].id, local.data_source_site_list[each.value.parent_name], data.catalystcenter_site.global.id, null)
  depends_on = [catalystcenter_area.area_6, catalystcenter_credentials_cli.cli_credentials, catalystcenter_credentials_https_read.https_read_credentials, catalystcenter_credentials_https_write.https_write_credentials, catalystcenter_credentials_snmpv3.snmpv3_credentials, catalystcenter_credentials_snmpv2_read.snmpv2_read_credentials, catalystcenter_credentials_snmpv2_write.snmpv2_write_credentials]
}
resource "catalystcenter_area" "area_8" {
  for_each = var.use_bulk_api ? {} : { for area in try(local.catalyst_center.sites.areas, []) : "${area.parent_name}/${area.name}" => area if length(regexall("\\/", try(area.parent_name, ""))) == 8 && contains(local.sites, try("${area.parent_name}/${area.name}", "")) }

  name      = each.value.name
  parent_id = try(catalystcenter_area.area_7[each.value.parent_name].id, local.data_source_site_list[each.value.parent_name], data.catalystcenter_site.global.id, null)

  depends_on = [catalystcenter_area.area_7, catalystcenter_credentials_cli.cli_credentials, catalystcenter_credentials_https_read.https_read_credentials, catalystcenter_credentials_https_write.https_write_credentials, catalystcenter_credentials_snmpv3.snmpv3_credentials, catalystcenter_credentials_snmpv2_read.snmpv2_read_credentials, catalystcenter_credentials_snmpv2_write.snmpv2_write_credentials]
}

resource "catalystcenter_area" "area_9" {
  for_each = var.use_bulk_api ? {} : { for area in try(local.catalyst_center.sites.areas, []) : "${area.parent_name}/${area.name}" => area if length(regexall("\\/", try(area.parent_name, ""))) == 9 && contains(local.sites, try("${area.parent_name}/${area.name}", "")) }

  name      = each.value.name
  parent_id = try(catalystcenter_area.area_8[each.value.parent_name].id, local.data_source_site_list[each.value.parent_name], data.catalystcenter_site.global.id, null)

  depends_on = [catalystcenter_area.area_8, catalystcenter_credentials_cli.cli_credentials, catalystcenter_credentials_https_read.https_read_credentials, catalystcenter_credentials_https_write.https_write_credentials, catalystcenter_credentials_snmpv3.snmpv3_credentials, catalystcenter_credentials_snmpv2_read.snmpv2_read_credentials, catalystcenter_credentials_snmpv2_write.snmpv2_write_credentials]
}
resource "catalystcenter_building" "building" {
  for_each = var.use_bulk_api ? {} : { for building in try(local.catalyst_center.sites.buildings, []) : "${building.parent_name}/${building.name}" => building if contains(local.sites, try("${building.parent_name}/${building.name}", "")) }

  name      = each.value.name
  parent_id = try(catalystcenter_area.area_9[each.value.parent_name].id, catalystcenter_area.area_8[each.value.parent_name].id, catalystcenter_area.area_7[each.value.parent_name].id, catalystcenter_area.area_6[each.value.parent_name].id, catalystcenter_area.area_5[each.value.parent_name].id, catalystcenter_area.area_4[each.value.parent_name].id, catalystcenter_area.area_3[each.value.parent_name].id, catalystcenter_area.area_2[each.value.parent_name].id, catalystcenter_area.area_1[each.value.parent_name].id, catalystcenter_area.area_0[each.value.parent_name].id, local.data_source_site_list[each.value.parent_name], data.catalystcenter_site.global.id, null)
  country   = try(each.value.country, local.defaults.catalyst_center.sites.buildings.country, null)
  address   = try(each.value.address, local.defaults.catalyst_center.sites.buildings.address, null)
  latitude  = try(floor(each.value.latitude * 100000 + 0.5) / 100000, local.defaults.catalyst_center.sites.buildings.latitude, null)
  longitude = try(floor(each.value.longitude * 100000 + 0.5) / 100000, local.defaults.catalyst_center.sites.buildings.longitude, null)

  depends_on = [catalystcenter_area.area_0, catalystcenter_area.area_1, catalystcenter_area.area_2, catalystcenter_area.area_3, catalystcenter_area.area_4, catalystcenter_area.area_5, catalystcenter_area.area_6, catalystcenter_area.area_7, catalystcenter_area.area_8, catalystcenter_area.area_9, catalystcenter_credentials_cli.cli_credentials, catalystcenter_credentials_https_read.https_read_credentials, catalystcenter_credentials_https_write.https_write_credentials, catalystcenter_credentials_snmpv3.snmpv3_credentials, catalystcenter_credentials_snmpv2_read.snmpv2_read_credentials, catalystcenter_credentials_snmpv2_write.snmpv2_write_credentials]
}


resource "catalystcenter_floor" "floor" {
  for_each = var.use_bulk_api ? {} : { for floor in try(local.catalyst_center.sites.floors, []) : "${floor.parent_name}/${floor.name}" => floor if contains(local.sites, try("${floor.parent_name}/${floor.name}", "")) }

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

locals {
  site_id_list = merge(
    { for k, v in catalystcenter_area.area_0 : k => v.id },
    { for k, v in catalystcenter_area.area_1 : k => v.id },
    { for k, v in catalystcenter_area.area_2 : k => v.id },
    { for k, v in catalystcenter_area.area_3 : k => v.id },
    { for k, v in catalystcenter_building.building : k => v.id },
    { for k, v in catalystcenter_floor.floor : k => v.id }
  )

  data_source_site_list = { for site in data.catalystcenter_sites.all_sites.sites : coalesce(site.name_hierarchy, site.name) => site.id }
}

data "catalystcenter_sites" "created_sites" {
  depends_on = [catalystcenter_areas.bulk_areas, catalystcenter_buildings.bulk_buildings, catalystcenter_floors.bulk_floors]
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