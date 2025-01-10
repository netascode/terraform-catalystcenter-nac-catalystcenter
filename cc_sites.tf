## Global area
resource "catalystcenter_area" "area_0" {
  for_each = { for area in try(local.catalyst_center.sites.areas, []) : "${area.parent_name}/${area.name}" => area if area.parent_name == "Global" }

  name        = each.value.name
  parent_name = try(each.value.parent_name, local.defaults.catalyst_center.sites.parent_name, null)

  depends_on = [catalystcenter_credentials_cli.cli_credentials, catalystcenter_credentials_https_read.https_read_credentials, catalystcenter_credentials_https_write.https_write_credentials, catalystcenter_credentials_snmpv3.snmpv3_credentials, catalystcenter_credentials_snmpv2_read.snmpv2_read_credentials, catalystcenter_credentials_snmpv2_write.snmpv2_write_credentials]
}

# 1st level area Global/area
resource "catalystcenter_area" "area_1" {
  for_each = { for area in try(local.catalyst_center.sites.areas, []) : "${area.parent_name}/${area.name}" => area if length(regexall("\\/", area.parent_name)) == 1 }

  name        = each.value.name
  parent_name = try(each.value.parent_name, local.defaults.catalyst_center.sites.areas.parent_name, null)

  depends_on = [catalystcenter_area.area_0, catalystcenter_credentials_cli.cli_credentials, catalystcenter_credentials_https_read.https_read_credentials, catalystcenter_credentials_https_write.https_write_credentials, catalystcenter_credentials_snmpv3.snmpv3_credentials, catalystcenter_credentials_snmpv2_read.snmpv2_read_credentials, catalystcenter_credentials_snmpv2_write.snmpv2_write_credentials]
}

# 2nd level area Global/area/area
resource "catalystcenter_area" "area_2" {
  for_each = { for area in try(local.catalyst_center.sites.areas, []) : "${area.parent_name}/${area.name}" => area if length(regexall("\\/", area.parent_name)) == 2 }

  name        = each.value.name
  parent_name = try(each.value.parent_name, local.defaults.catalyst_center.sites.areas.parent_name, null)

  depends_on = [catalystcenter_area.area_1, catalystcenter_credentials_cli.cli_credentials, catalystcenter_credentials_https_read.https_read_credentials, catalystcenter_credentials_https_write.https_write_credentials, catalystcenter_credentials_snmpv3.snmpv3_credentials, catalystcenter_credentials_snmpv2_read.snmpv2_read_credentials, catalystcenter_credentials_snmpv2_write.snmpv2_write_credentials]
}

resource "catalystcenter_building" "building" {
  for_each = { for building in try(local.catalyst_center.sites.buildings, []) : "${building.parent_name}/${building.name}" => building }

  name        = each.value.name
  parent_name = try(each.value.parent_name, local.defaults.catalyst_center.sites.buildings.parent_name, null)
  country     = try(each.value.country, local.defaults.catalyst_center.sites.buildings.country, null)
  address     = try(each.value.address, local.defaults.catalyst_center.sites.buildings.address, null)
  latitude    = try(each.value.latitude, local.defaults.catalyst_center.sites.buildings.latitude, null)
  longitude   = try(each.value.longitude, local.defaults.catalyst_center.sites.buildings.longitude, null)

  depends_on = [catalystcenter_area.area_0, catalystcenter_area.area_1, catalystcenter_area.area_2, catalystcenter_credentials_cli.cli_credentials, catalystcenter_credentials_https_read.https_read_credentials, catalystcenter_credentials_https_write.https_write_credentials, catalystcenter_credentials_snmpv3.snmpv3_credentials, catalystcenter_credentials_snmpv2_read.snmpv2_read_credentials, catalystcenter_credentials_snmpv2_write.snmpv2_write_credentials]
}


resource "catalystcenter_floor" "floor" {
  for_each = { for floor in try(local.catalyst_center.sites.floors, []) : "${floor.parent_name}/${floor.name}" => floor }

  name        = each.value.name
  parent_name = try(each.value.parent_name, local.defaults.catalyst_center.sites.floors.parent_name, null)
  rf_model    = try(each.value.rf_model, local.defaults.catalyst_center.sites.floors.rf_model, null)
  width       = try(each.value.width, local.defaults.catalyst_center.sites.floors.width, null)
  length      = try(each.value.length, local.defaults.catalyst_center.sites.floors.length, null)
  height      = try(each.value.height, local.defaults.catalyst_center.sites.floors.height, null)

  depends_on = [catalystcenter_building.building, catalystcenter_credentials_cli.cli_credentials, catalystcenter_credentials_https_read.https_read_credentials, catalystcenter_credentials_https_write.https_write_credentials, catalystcenter_credentials_snmpv3.snmpv3_credentials, catalystcenter_credentials_snmpv2_read.snmpv2_read_credentials, catalystcenter_credentials_snmpv2_write.snmpv2_write_credentials]
}

locals {
  site_id_list = merge(
    { for k, v in catalystcenter_area.area_0 : k => v.id },
    { for k, v in catalystcenter_area.area_1 : k => v.id },
    { for k, v in catalystcenter_area.area_2 : k => v.id },
    { for k, v in catalystcenter_building.building : k => v.id },
    { for k, v in catalystcenter_floor.floor : k => v.id }
  )
}
