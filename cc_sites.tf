data "catalystcenter_site" "global" {
  name_hierarchy = "Global"
}

data "catalystcenter_sites" "all_sites" {
}

## 1st level area Global/area
resource "catalystcenter_area" "area_0" {
  for_each = { for area in try(local.catalyst_center.sites.areas, []) : "${area.parent_name}/${area.name}" => area if try(area.parent_name, "") == "Global" && contains(local.sites, "Global/${area.name}") }

  name      = each.value.name
  parent_id = try(data.catalystcenter_site.global.id, null)

  depends_on = [catalystcenter_discovery.discovery, catalystcenter_credentials_cli.cli_credentials, catalystcenter_credentials_https_read.https_read_credentials, catalystcenter_credentials_https_write.https_write_credentials, catalystcenter_credentials_snmpv3.snmpv3_credentials, catalystcenter_credentials_snmpv2_read.snmpv2_read_credentials, catalystcenter_credentials_snmpv2_write.snmpv2_write_credentials]
}

# 2nd level area Global/area/area
resource "catalystcenter_area" "area_1" {
  for_each = { for area in try(local.catalyst_center.sites.areas, []) : "${area.parent_name}/${area.name}" => area if length(regexall("\\/", try(area.parent_name, ""))) == 1 && contains(local.sites, try("${area.parent_name}/${area.name}", "")) }

  name      = each.value.name
  parent_id = try(catalystcenter_area.area_0[each.value.parent_name].id, data.catalystcenter_site.global.id, null)

  depends_on = [catalystcenter_area.area_0, catalystcenter_credentials_cli.cli_credentials, catalystcenter_credentials_https_read.https_read_credentials, catalystcenter_credentials_https_write.https_write_credentials, catalystcenter_credentials_snmpv3.snmpv3_credentials, catalystcenter_credentials_snmpv2_read.snmpv2_read_credentials, catalystcenter_credentials_snmpv2_write.snmpv2_write_credentials]
}

# 3rd level area Global/area/area/area
resource "catalystcenter_area" "area_2" {
  for_each = { for area in try(local.catalyst_center.sites.areas, []) : "${area.parent_name}/${area.name}" => area if length(regexall("\\/", try(area.parent_name, ""))) == 2 && contains(local.sites, try("${area.parent_name}/${area.name}", "")) }

  name      = each.value.name
  parent_id = try(catalystcenter_area.area_1[each.value.parent_name].id, data.catalystcenter_site.global.id, null)

  depends_on = [catalystcenter_area.area_1, catalystcenter_credentials_cli.cli_credentials, catalystcenter_credentials_https_read.https_read_credentials, catalystcenter_credentials_https_write.https_write_credentials, catalystcenter_credentials_snmpv3.snmpv3_credentials, catalystcenter_credentials_snmpv2_read.snmpv2_read_credentials, catalystcenter_credentials_snmpv2_write.snmpv2_write_credentials]
}

# 4th level area Global/area/area/area/area
resource "catalystcenter_area" "area_3" {
  for_each = { for area in try(local.catalyst_center.sites.areas, []) : "${area.parent_name}/${area.name}" => area if length(regexall("\\/", try(area.parent_name, ""))) == 3 && contains(local.sites, try("${area.parent_name}/${area.name}", "")) }

  name      = each.value.name
  parent_id = try(catalystcenter_area.area_2[each.value.parent_name].id, data.catalystcenter_site.global.id, null)

  depends_on = [catalystcenter_area.area_2, catalystcenter_credentials_cli.cli_credentials, catalystcenter_credentials_https_read.https_read_credentials, catalystcenter_credentials_https_write.https_write_credentials, catalystcenter_credentials_snmpv3.snmpv3_credentials, catalystcenter_credentials_snmpv2_read.snmpv2_read_credentials, catalystcenter_credentials_snmpv2_write.snmpv2_write_credentials]
}

resource "catalystcenter_building" "building" {
  for_each = { for building in try(local.catalyst_center.sites.buildings, []) : "${building.parent_name}/${building.name}" => building if contains(local.sites, try("${building.parent_name}/${building.name}", "")) }

  name      = each.value.name
  parent_id = try(catalystcenter_area.area_3[each.value.parent_name].id, catalystcenter_area.area_2[each.value.parent_name].id, catalystcenter_area.area_1[each.value.parent_name].id, catalystcenter_area.area_0[each.value.parent_name].id, data.catalystcenter_site.global.id, null)
  country   = try(each.value.country, local.defaults.catalyst_center.sites.buildings.country, null)
  address   = try(each.value.address, local.defaults.catalyst_center.sites.buildings.address, null)
  latitude  = try(each.value.latitude, local.defaults.catalyst_center.sites.buildings.latitude, null)
  longitude = try(each.value.longitude, local.defaults.catalyst_center.sites.buildings.longitude, null)

  depends_on = [catalystcenter_area.area_0, catalystcenter_area.area_1, catalystcenter_area.area_2, catalystcenter_area.area_3, catalystcenter_credentials_cli.cli_credentials, catalystcenter_credentials_https_read.https_read_credentials, catalystcenter_credentials_https_write.https_write_credentials, catalystcenter_credentials_snmpv3.snmpv3_credentials, catalystcenter_credentials_snmpv2_read.snmpv2_read_credentials, catalystcenter_credentials_snmpv2_write.snmpv2_write_credentials]
}


resource "catalystcenter_floor" "floor" {
  for_each = { for floor in try(local.catalyst_center.sites.floors, []) : "${floor.parent_name}/${floor.name}" => floor if contains(local.sites, try("${floor.parent_name}/${floor.name}", "")) }

  name             = each.value.name
  parent_id        = try(catalystcenter_building.building[each.value.parent_name].id, data.catalystcenter_site.global.id, null)
  floor_number     = try(each.value.floor_number, local.defaults.catalyst_center.sites.floors.floor_number, null)
  rf_model         = try(each.value.rf_model, local.defaults.catalyst_center.sites.floors.rf_model, null)
  width            = try(each.value.width, local.defaults.catalyst_center.sites.floors.width, null)
  length           = try(each.value.length, local.defaults.catalyst_center.sites.floors.length, null)
  height           = try(each.value.height, local.defaults.catalyst_center.sites.floors.height, null)
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
