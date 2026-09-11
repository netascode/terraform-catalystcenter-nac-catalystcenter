# CREDENTIALS

locals {
  sites_to_creds_map = merge(
    { for area in local.flat_areas : "${area.parent_name}/${area.name}" => {
      cli          = try(area.cli_credentials, null)
      snmpv3       = try(area.snmpv3_credentials, null)
      snmpv2_read  = try(area.snmpv2_read_credentials, null)
      snmpv2_write = try(area.snmpv2_write_credentials, null)
      https_read   = try(area.https_read_credentials, null)
      https_write  = try(area.https_write_credentials, null)
    } },
    { for building in local.flat_buildings : "${building.parent_name}/${building.name}" => {
      cli          = try(building.cli_credentials, null)
      snmpv3       = try(building.snmpv3_credentials, null)
      snmpv2_read  = try(building.snmpv2_read_credentials, null)
      snmpv2_write = try(building.snmpv2_write_credentials, null)
      https_read   = try(building.https_read_credentials, null)
      https_write  = try(building.https_write_credentials, null)
    } },
    { for floor in local.flat_floors : "${floor.parent_name}/${floor.name}" => {
      cli          = try(floor.cli_credentials, null)
      snmpv3       = try(floor.snmpv3_credentials, null)
      snmpv2_read  = try(floor.snmpv2_read_credentials, null)
      snmpv2_write = try(floor.snmpv2_write_credentials, null)
      https_read   = try(floor.https_read_credentials, null)
      https_write  = try(floor.https_write_credentials, null)
    } }
  )

  sites_to_settings_map = merge(
    { "Global" = local.global_network_settings },
    local.area_network_settings,
    { for building in local.flat_buildings : "${building.parent_name}/${building.name}" => try(building.network_settings, null) if try(building.network_settings, null) != null },
    { for floor in local.flat_floors : "${floor.parent_name}/${floor.name}" => try(floor.network_settings, null) if try(floor.network_settings, null) != null }
  )
}

resource "catalystcenter_credentials_https_read" "https_read_credentials" {
  for_each = { for cred in try(local.catalyst_center.network_settings.device_credentials.https_read_credentials, []) : cred.name => cred if var.manage_global_settings || (!var.manage_global_settings && length(var.managed_sites) == 0) }

  description         = each.key
  username            = try(each.value.username, local.defaults.catalyst_center.network_settings.device_credentials.https_read_credentials.username, null)
  password_wo         = try(each.value.password, local.defaults.catalyst_center.network_settings.device_credentials.https_read_credentials.password, null)
  password_wo_version = try(each.value.password_version, local.defaults.catalyst_center.network_settings.device_credentials.https_read_credentials.password_version, 1)
  port                = try(each.value.port, local.defaults.catalyst_center.network_settings.device_credentials.https_read_credentials.port, null)
}

resource "catalystcenter_credentials_https_write" "https_write_credentials" {
  for_each = { for cred in try(local.catalyst_center.network_settings.device_credentials.https_write_credentials, []) : cred.name => cred if var.manage_global_settings || (!var.manage_global_settings && length(var.managed_sites) == 0) }

  description         = each.key
  username            = try(each.value.username, local.defaults.catalyst_center.network_settings.device_credentials.https_write_credentials.username, null)
  password_wo         = try(each.value.password, local.defaults.catalyst_center.network_settings.device_credentials.https_write_credentials.password, null)
  password_wo_version = try(each.value.password_version, local.defaults.catalyst_center.network_settings.device_credentials.https_write_credentials.password_version, 1)
  port                = try(each.value.port, local.defaults.catalyst_center.network_settings.device_credentials.https_write_credentials.port, null)
}

resource "catalystcenter_credentials_cli" "cli_credentials" {
  for_each = { for cred in try(local.catalyst_center.network_settings.device_credentials.cli_credentials, []) : cred.name => cred if var.manage_global_settings || (!var.manage_global_settings && length(var.managed_sites) == 0) }

  description                = each.key
  username                   = try(each.value.username, local.defaults.catalyst_center.network_settings.device_credentials.cli_credentials.username, null)
  password_wo                = try(each.value.password, local.defaults.catalyst_center.network_settings.device_credentials.cli_credentials.password, null)
  password_wo_version        = try(each.value.password_version, local.defaults.catalyst_center.network_settings.device_credentials.cli_credentials.password_version, 1)
  enable_password_wo         = try(each.value.enable, local.defaults.catalyst_center.network_settings.device_credentials.cli_credentials.enable, null)
  enable_password_wo_version = try(each.value.enable_version, local.defaults.catalyst_center.network_settings.device_credentials.cli_credentials.enable_version, 1)
}

resource "catalystcenter_credentials_snmpv2_read" "snmpv2_read_credentials" {
  for_each = { for cred in try(local.catalyst_center.network_settings.device_credentials.snmpv2_read_credentials, []) : cred.name => cred if var.manage_global_settings || (!var.manage_global_settings && length(var.managed_sites) == 0) }

  description               = each.key
  read_community_wo         = try(each.value.read_community, local.defaults.catalyst_center.network_settings.device_credentials.snmpv2_read_credentials.read_community, null)
  read_community_wo_version = try(each.value.read_community_version, local.defaults.catalyst_center.network_settings.device_credentials.snmpv2_read_credentials.read_community_version, 1)
}

resource "catalystcenter_credentials_snmpv2_write" "snmpv2_write_credentials" {
  for_each = { for cred in try(local.catalyst_center.network_settings.device_credentials.snmpv2_write_credentials, []) : cred.name => cred if var.manage_global_settings || (!var.manage_global_settings && length(var.managed_sites) == 0) }

  description                = each.key
  write_community_wo         = try(each.value.write_community, local.defaults.catalyst_center.network_settings.device_credentials.snmpv2_write_credentials.write_community, null)
  write_community_wo_version = try(each.value.write_community_version, local.defaults.catalyst_center.network_settings.device_credentials.snmpv2_write_credentials.write_community_version, 1)
}

resource "catalystcenter_credentials_snmpv3" "snmpv3_credentials" {
  for_each = { for cred in try(local.catalyst_center.network_settings.device_credentials.snmpv3_credentials, []) : cred.name => cred if var.manage_global_settings || (!var.manage_global_settings && length(var.managed_sites) == 0) }

  description                 = each.key
  username                    = try(each.value.username, local.defaults.catalyst_center.network_settings.device_credentials.snmpv3_credentials.username, null)
  privacy_type                = try(each.value.privacy_type, local.defaults.catalyst_center.network_settings.device_credentials.snmpv3_credentials.privacy_type, null)
  privacy_password_wo         = try(each.value.privacy_password, local.defaults.catalyst_center.network_settings.device_credentials.snmpv3_credentials.privacy_password, null)
  privacy_password_wo_version = try(each.value.privacy_password_version, local.defaults.catalyst_center.network_settings.device_credentials.snmpv3_credentials.privacy_password_version, 1)
  auth_type                   = try(each.value.auth_type, local.defaults.catalyst_center.network_settings.device_credentials.snmpv3_credentials.auth_type, null)
  auth_password_wo            = try(each.value.auth_password, local.defaults.catalyst_center.network_settings.device_credentials.snmpv3_credentials.auth_password, null)
  auth_password_wo_version    = try(each.value.auth_password_version, local.defaults.catalyst_center.network_settings.device_credentials.snmpv3_credentials.auth_password_version, 1)
  snmp_mode                   = try(each.value.snmp_mode, local.defaults.catalyst_center.network_settings.device_credentials.snmpv3_credentials.snmp_mode, null)
}


locals {
  multi_state_non_global_credentials = !var.manage_global_settings && length(var.managed_sites) > 0
  multi_state_non_global_cli_creds = local.multi_state_non_global_credentials ? toset([
    for k, v in try(local.sites_to_creds_map, {}) : v.cli
    if v.cli != null
  ]) : toset([])

  multi_state_non_global_https_read_creds = local.multi_state_non_global_credentials ? toset([
    for k, v in try(local.sites_to_creds_map, {}) : v.https_read
    if v.https_read != null
  ]) : toset([])

  multi_state_non_global_https_write_creds = local.multi_state_non_global_credentials ? toset([
    for k, v in try(local.sites_to_creds_map, {}) : v.https_write
    if v.https_write != null
  ]) : toset([])

  multi_state_non_global_snmpv2_read_creds = local.multi_state_non_global_credentials ? toset([
    for k, v in try(local.sites_to_creds_map, {}) : v.snmpv2_read
    if v.snmpv2_read != null
  ]) : toset([])

  multi_state_non_global_snmpv2_write_creds = local.multi_state_non_global_credentials ? toset([
    for k, v in try(local.sites_to_creds_map, {}) : v.snmpv2_write
    if v.snmpv2_write != null
  ]) : toset([])

  multi_state_non_global_snmpv3_creds = local.multi_state_non_global_credentials ? toset([
    for k, v in try(local.sites_to_creds_map, {}) : v.snmpv3
    if v.snmpv3 != null
  ]) : toset([])
}

data "catalystcenter_credentials_cli" "multi_state_non_global_credentials" {
  for_each    = local.multi_state_non_global_cli_creds
  description = each.value
}

data "catalystcenter_credentials_https_read" "multi_state_non_global_credentials" {
  for_each    = local.multi_state_non_global_https_read_creds
  description = each.value
}

data "catalystcenter_credentials_https_write" "multi_state_non_global_credentials" {
  for_each    = local.multi_state_non_global_https_write_creds
  description = each.value
}

data "catalystcenter_credentials_snmpv2_read" "multi_state_non_global_credentials" {
  for_each    = local.multi_state_non_global_snmpv2_read_creds
  description = each.value
}

data "catalystcenter_credentials_snmpv2_write" "multi_state_non_global_credentials" {
  for_each    = local.multi_state_non_global_snmpv2_write_creds
  description = each.value
}

data "catalystcenter_credentials_snmpv3" "multi_state_non_global_credentials" {
  for_each    = local.multi_state_non_global_snmpv3_creds
  description = each.value
}

resource "catalystcenter_assign_credentials" "assign_credentials" {
  for_each = { for k, v in try(local.sites_to_creds_map, {}) : k => v if(v.cli != null || v.snmpv3 != null || v.https_read != null || v.https_write != null || v.snmpv2_read != null || v.snmpv2_write != null) && contains(local.sites, k) && k != "Global" }

  site_id          = try(var.use_bulk_api ? coalesce(local.site_id_list_bulk[each.key], local.data_source_created_sites_list[each.key]) : local.site_id_list[each.key], local.data_source_site_list[each.key], null)
  cli_id           = each.value.cli != null ? try(catalystcenter_credentials_cli.cli_credentials[each.value.cli].id, data.catalystcenter_credentials_cli.multi_state_non_global_credentials[each.value.cli].id, data.catalystcenter_assign_credentials.global_assign_credentials.cli_id) : null
  https_read_id    = each.value.https_read != null ? try(catalystcenter_credentials_https_read.https_read_credentials[each.value.https_read].id, data.catalystcenter_credentials_https_read.multi_state_non_global_credentials[each.value.https_read].id, data.catalystcenter_assign_credentials.global_assign_credentials.https_read_id) : null
  https_write_id   = each.value.https_write != null ? try(catalystcenter_credentials_https_write.https_write_credentials[each.value.https_write].id, data.catalystcenter_credentials_https_write.multi_state_non_global_credentials[each.value.https_write].id, data.catalystcenter_assign_credentials.global_assign_credentials.https_write_id) : null
  snmp_v2_read_id  = each.value.snmpv2_read != null ? try(catalystcenter_credentials_snmpv2_read.snmpv2_read_credentials[each.value.snmpv2_read].id, data.catalystcenter_credentials_snmpv2_read.multi_state_non_global_credentials[each.value.snmpv2_read].id, data.catalystcenter_assign_credentials.global_assign_credentials.snmp_v2_read_id) : null
  snmp_v2_write_id = each.value.snmpv2_write != null ? try(catalystcenter_credentials_snmpv2_write.snmpv2_write_credentials[each.value.snmpv2_write].id, data.catalystcenter_credentials_snmpv2_write.multi_state_non_global_credentials[each.value.snmpv2_write].id, data.catalystcenter_assign_credentials.global_assign_credentials.snmp_v2_write_id) : null
  snmp_v3_id       = each.value.snmpv3 != null ? try(catalystcenter_credentials_snmpv3.snmpv3_credentials[each.value.snmpv3].id, data.catalystcenter_credentials_snmpv3.multi_state_non_global_credentials[each.value.snmpv3].id, data.catalystcenter_assign_credentials.global_assign_credentials.snmp_v3_id) : null

  depends_on = [catalystcenter_floor.floor, catalystcenter_building.building, catalystcenter_area.area_0, catalystcenter_area.area_1, catalystcenter_area.area_2, catalystcenter_area.area_3, catalystcenter_area.area_4, catalystcenter_area.area_5, catalystcenter_area.area_6, catalystcenter_area.area_7, catalystcenter_area.area_8, catalystcenter_area.area_9, catalystcenter_area.area_10, data.catalystcenter_sites.created_sites]
}

resource "catalystcenter_assign_credentials" "global_assign_credentials" {
  for_each = { for k, v in try(local.sites_to_creds_map, {}) : k => v if(v.cli != null || v.snmpv3 != null || v.https_read != null || v.https_write != null || v.snmpv2_read != null || v.snmpv2_write != null) && ((var.manage_global_settings && k == "Global") || (!var.manage_global_settings && length(var.managed_sites) == 0)) && k == "Global" }

  site_id          = try(data.catalystcenter_site.global.id, null)
  cli_id           = each.value.cli != null ? catalystcenter_credentials_cli.cli_credentials[each.value.cli].id : null
  https_read_id    = each.value.https_read != null ? catalystcenter_credentials_https_read.https_read_credentials[each.value.https_read].id : null
  https_write_id   = each.value.https_write != null ? catalystcenter_credentials_https_write.https_write_credentials[each.value.https_write].id : null
  snmp_v2_read_id  = each.value.snmpv2_read != null ? catalystcenter_credentials_snmpv2_read.snmpv2_read_credentials[each.value.snmpv2_read].id : null
  snmp_v2_write_id = each.value.snmpv2_write != null ? catalystcenter_credentials_snmpv2_write.snmpv2_write_credentials[each.value.snmpv2_write].id : null
  snmp_v3_id       = each.value.snmpv3 != null ? catalystcenter_credentials_snmpv3.snmpv3_credentials[each.value.snmpv3].id : null
}

data "catalystcenter_assign_credentials" "global_assign_credentials" {
  id      = try(data.catalystcenter_site.global.id, null)
  site_id = try(data.catalystcenter_site.global.id, null)
}

# Network Settings

locals {
  # Named global definitions live under sites.global.network_settings now that
  # network settings are folded into the sites tree (issue #523). A site level
  # may reference one of these by name (e.g. `network: Global_Network`), so the
  # lookup maps must be built from global_network_settings. The old top-level
  # network_settings path is kept as a fallback for back-compat.
  network_settings = { for settings in try(local.global_network_settings.network, local.catalyst_center.network_settings.network, []) : settings.name => settings }
  aaa_settings     = { for settings in try(local.global_network_settings.aaa_servers, local.catalyst_center.network_settings.aaa_servers, []) : settings.name => settings }

  site_aaa_settings = {
    for k, v in try(local.sites_to_settings_map, {}) : k => {
      network_aaa             = try(local.aaa_settings[tostring(v.aaa_servers)].network_aaa, v.network_aaa, null)
      client_and_endpoint_aaa = try(local.aaa_settings[tostring(v.aaa_servers)].client_and_endpoint_aaa, v.client_and_endpoint_aaa, null)
    }
    if v != null && try(coalesce(try(tostring(v.aaa_servers), null), try(v.network_aaa, null), try(v.client_and_endpoint_aaa, null)), null) != null
  }
  telemetry_settings = { for settings in try(local.global_network_settings.telemetry, local.catalyst_center.network_settings.telemetry, []) : settings.name => settings }

  site_network_settings = {
    for k, v in try(local.sites_to_settings_map, {}) : k => {
      # `network` accepts three forms (issue #523 embed-or-reference):
      #   1. string reference  -> local.network_settings[<name>]
      #   2. inline object      -> v.network.<field>
      #   3. flat siblings      -> v.<field>  (back-compat)
      ntp_servers  = try(local.network_settings[v.network].ntp_servers, v.network.ntp_servers, v.ntp_servers, null)
      dhcp_servers = try(local.network_settings[v.network].dhcp_servers, v.network.dhcp_servers, v.dhcp_servers, null)
      dns_servers  = try(local.network_settings[v.network].dns_servers, v.network.dns_servers, v.dns_servers, null)
      domain_name  = try(local.network_settings[v.network].domain_name, v.network.domain_name, v.domain_name, null)
      timezone     = try(local.network_settings[v.network].timezone, v.network.timezone, v.timezone, null)
      banner       = try(local.network_settings[v.network].banner, v.network.banner, v.banner, null)
    }
    if v != null
  }

  # Telemetry, same two forms: `telemetry: <name>` reference (a string) or an
  # inline block (an object). The global definitions live under
  # global.network_settings as a *list* (`telemetry:` is a list of named defs) —
  # that is a definition source, not a site-applied value, so a list-typed
  # value is excluded from per-site resolution (can(tolist()) is true only for
  # lists/tuples, false for strings and objects).
  site_telemetry_settings = {
    for k, v in try(local.sites_to_settings_map, {}) : k => try(local.telemetry_settings[v.telemetry], v.telemetry, null)
    if v != null && try(v.telemetry, null) != null && !can(tolist(v.telemetry))
  }
}

resource "catalystcenter_ntp_settings" "ntp_servers" {
  for_each = { for k, v in try(local.sites_to_settings_map, {}) : k => v if try(local.site_network_settings[k].ntp_servers, null) != null && contains(local.sites, k) && k != "Global" }

  site_id = try(var.use_bulk_api ? coalesce(local.site_id_list_bulk[each.key], local.data_source_created_sites_list[each.key]) : local.site_id_list[each.key], local.data_source_site_list[each.key], null)
  servers = try(local.site_network_settings[each.key].ntp_servers, local.defaults.catalyst_center.network_settings.network.ntp_servers, null)

  depends_on = [catalystcenter_floor.floor, catalystcenter_building.building, catalystcenter_area.area_0, catalystcenter_area.area_1, catalystcenter_area.area_2, catalystcenter_area.area_3, catalystcenter_area.area_4, catalystcenter_area.area_5, catalystcenter_area.area_6, catalystcenter_area.area_7, catalystcenter_area.area_8, catalystcenter_area.area_9, catalystcenter_area.area_10, catalystcenter_aaa_settings.global_aaa_servers, data.catalystcenter_sites.created_sites]
}

resource "catalystcenter_ntp_settings" "global_ntp_servers" {
  for_each = { for k, v in try(local.sites_to_settings_map, {}) : k => v if try(local.site_network_settings[k].ntp_servers, null) != null && k == "Global" && (var.manage_global_settings || (!var.manage_global_settings && length(var.managed_sites) == 0)) }

  site_id = try(data.catalystcenter_site.global.id, null)
  servers = try(local.site_network_settings[each.key].ntp_servers, local.defaults.catalyst_center.network_settings.network.ntp_servers, null)

  depends_on = [catalystcenter_floor.floor, catalystcenter_building.building, catalystcenter_area.area_0, catalystcenter_area.area_1, catalystcenter_area.area_2, catalystcenter_area.area_3, catalystcenter_area.area_4, catalystcenter_area.area_5, catalystcenter_area.area_6, catalystcenter_area.area_7, catalystcenter_area.area_8, catalystcenter_area.area_9, catalystcenter_area.area_10, data.catalystcenter_sites.created_sites]
}

resource "catalystcenter_dhcp_settings" "dhcp_servers" {
  for_each = { for k, v in try(local.sites_to_settings_map, {}) : k => v if try(local.site_network_settings[k].dhcp_servers, null) != null && contains(local.sites, k) && k != "Global" }

  site_id = try(var.use_bulk_api ? coalesce(local.site_id_list_bulk[each.key], local.data_source_created_sites_list[each.key]) : local.site_id_list[each.key], local.data_source_site_list[each.key], null)
  servers = try(local.site_network_settings[each.key].dhcp_servers, local.defaults.catalyst_center.network_settings.network.dhcp_servers, null)

  depends_on = [catalystcenter_floor.floor, catalystcenter_building.building, catalystcenter_area.area_0, catalystcenter_area.area_1, catalystcenter_area.area_2, catalystcenter_area.area_3, catalystcenter_area.area_4, catalystcenter_area.area_5, catalystcenter_area.area_6, catalystcenter_area.area_7, catalystcenter_area.area_8, catalystcenter_area.area_9, catalystcenter_area.area_10, catalystcenter_ntp_settings.ntp_servers, data.catalystcenter_sites.created_sites]
}

resource "catalystcenter_dhcp_settings" "global_dhcp_servers" {
  for_each = { for k, v in try(local.sites_to_settings_map, {}) : k => v if try(local.site_network_settings[k].dhcp_servers, null) != null && k == "Global" && (var.manage_global_settings || (!var.manage_global_settings && length(var.managed_sites) == 0)) }

  site_id = try(data.catalystcenter_site.global.id, null)
  servers = try(local.site_network_settings[each.key].dhcp_servers, local.defaults.catalyst_center.network_settings.network.dhcp_servers, null)

  depends_on = [catalystcenter_ntp_settings.global_ntp_servers]
}

resource "catalystcenter_dns_settings" "dns_settings" {
  for_each = { for k, v in try(local.sites_to_settings_map, {}) : k => v if try(local.site_network_settings[k].domain_name, null) != null && contains(local.sites, k) && k != "Global" }

  site_id     = try(var.use_bulk_api ? coalesce(local.site_id_list_bulk[each.key], local.data_source_created_sites_list[each.key]) : local.site_id_list[each.key], local.data_source_site_list[each.key], null)
  domain_name = try(local.site_network_settings[each.key].domain_name, local.defaults.catalyst_center.network_settings.network.domain_name, null)
  dns_servers = try(local.site_network_settings[each.key].dns_servers, local.defaults.catalyst_center.network_settings.network.dns_servers, null)

  depends_on = [catalystcenter_floor.floor, catalystcenter_building.building, catalystcenter_area.area_0, catalystcenter_area.area_1, catalystcenter_area.area_2, catalystcenter_area.area_3, catalystcenter_area.area_4, catalystcenter_area.area_5, catalystcenter_area.area_6, catalystcenter_area.area_7, catalystcenter_area.area_8, catalystcenter_area.area_9, catalystcenter_area.area_10, catalystcenter_dhcp_settings.dhcp_servers, data.catalystcenter_sites.created_sites]
}

resource "catalystcenter_dns_settings" "global_dns_settings" {
  for_each = { for k, v in try(local.sites_to_settings_map, {}) : k => v if try(local.site_network_settings[k].domain_name, null) != null && k == "Global" && (var.manage_global_settings || (!var.manage_global_settings && length(var.managed_sites) == 0)) }

  site_id     = try(data.catalystcenter_site.global.id, null)
  domain_name = try(local.site_network_settings[each.key].domain_name, local.defaults.catalyst_center.network_settings.network.domain_name, null)
  dns_servers = try(local.site_network_settings[each.key].dns_servers, local.defaults.catalyst_center.network_settings.network.dns_servers, null)

  depends_on = [catalystcenter_dhcp_settings.global_dhcp_servers]
}

resource "catalystcenter_timezone_settings" "timezone" {
  for_each = { for k, v in try(local.sites_to_settings_map, {}) : k => v if try(local.site_network_settings[k].timezone, null) != null && contains(local.sites, k) && k != "Global" }

  site_id    = try(var.use_bulk_api ? coalesce(local.site_id_list_bulk[each.key], local.data_source_created_sites_list[each.key]) : local.site_id_list[each.key], local.data_source_site_list[each.key], null)
  identifier = try(local.site_network_settings[each.key].timezone, local.defaults.catalyst_center.network_settings.network.timezone, null)

  depends_on = [catalystcenter_floor.floor, catalystcenter_building.building, catalystcenter_area.area_0, catalystcenter_area.area_1, catalystcenter_area.area_2, catalystcenter_area.area_3, catalystcenter_area.area_4, catalystcenter_area.area_5, catalystcenter_area.area_6, catalystcenter_area.area_7, catalystcenter_area.area_8, catalystcenter_area.area_9, catalystcenter_area.area_10, catalystcenter_dns_settings.dns_settings, data.catalystcenter_sites.created_sites]
}

resource "catalystcenter_timezone_settings" "global_timezone" {
  for_each = { for k, v in try(local.sites_to_settings_map, {}) : k => v if try(local.site_network_settings[k].timezone, null) != null && k == "Global" && (var.manage_global_settings || (!var.manage_global_settings && length(var.managed_sites) == 0)) }

  site_id    = try(data.catalystcenter_site.global.id, null)
  identifier = try(local.site_network_settings[each.key].timezone, local.defaults.catalyst_center.network_settings.network.timezone, null)

  depends_on = [catalystcenter_dns_settings.global_dns_settings]
}

resource "catalystcenter_banner_settings" "banner" {
  for_each = { for k, v in try(local.sites_to_settings_map, {}) : k => v if try(local.site_network_settings[k].banner, null) != null && contains(local.sites, k) && k != "Global" }

  site_id = try(var.use_bulk_api ? coalesce(local.site_id_list_bulk[each.key], local.data_source_created_sites_list[each.key]) : local.site_id_list[each.key], local.data_source_site_list[each.key], null)
  type    = try(local.site_network_settings[each.key].banner, local.defaults.catalyst_center.network_settings.network.banner, null) != null ? "Custom" : "Builtin"
  message = try(local.site_network_settings[each.key].banner, local.defaults.catalyst_center.network_settings.network.banner, null)

  depends_on = [catalystcenter_floor.floor, catalystcenter_building.building, catalystcenter_area.area_0, catalystcenter_area.area_1, catalystcenter_area.area_2, catalystcenter_area.area_3, catalystcenter_area.area_4, catalystcenter_area.area_5, catalystcenter_area.area_6, catalystcenter_area.area_7, catalystcenter_area.area_8, catalystcenter_area.area_9, catalystcenter_area.area_10, catalystcenter_timezone_settings.timezone, data.catalystcenter_sites.created_sites]
}

resource "catalystcenter_banner_settings" "global_banner" {
  for_each = { for k, v in try(local.sites_to_settings_map, {}) : k => v if try(local.site_network_settings[k].banner, null) != null && k == "Global" && (var.manage_global_settings || (!var.manage_global_settings && length(var.managed_sites) == 0)) }

  site_id = try(data.catalystcenter_site.global.id, null)
  type    = try(local.site_network_settings[each.key].banner, local.defaults.catalyst_center.network_settings.network.banner, null) != null ? "Custom" : "Builtin"
  message = try(local.site_network_settings[each.key].banner, local.defaults.catalyst_center.network_settings.network.banner, null)

  depends_on = [catalystcenter_timezone_settings.global_timezone]
}

resource "catalystcenter_telemetry_settings" "telemetry_settings" {
  for_each = { for k, v in try(local.sites_to_settings_map, {}) : k => v if try(local.site_telemetry_settings[k], null) != null && contains(local.sites, k) && k != "Global" }

  site_id                             = try(var.use_bulk_api ? coalesce(local.site_id_list_bulk[each.key], local.data_source_created_sites_list[each.key]) : local.site_id_list[each.key], local.data_source_site_list[each.key], null)
  enable_wired_data_collection        = try(local.site_telemetry_settings[each.key].wired_data_collection, local.defaults.catalyst_center.network_settings.telemetry.wired_data_collection, null)
  enable_wireless_telemetry           = try(local.site_telemetry_settings[each.key].wireless_telemetry, local.defaults.catalyst_center.network_settings.telemetry.wireless_telemetry, null)
  use_builtin_trap_server             = try(local.site_telemetry_settings[each.key].catalyst_center_as_snmp_server, local.defaults.catalyst_center.network_settings.telemetry.catalyst_center_as_snmp_server, null)
  external_trap_servers               = try(local.site_telemetry_settings[each.key].snmp_servers, local.defaults.catalyst_center.network_settings.telemetry.snmp_servers, null)
  use_builtin_syslog_server           = try(local.site_telemetry_settings[each.key].catalyst_center_as_syslog_server, local.defaults.catalyst_center.network_settings.telemetry.catalyst_center_as_syslog_server, null)
  external_syslog_servers             = try(local.site_telemetry_settings[each.key].syslog_servers, local.defaults.catalyst_center.network_settings.telemetry.syslog_servers, null)
  netflow_collector                   = try(local.site_telemetry_settings[each.key].catalyst_center_as_network_collector, local.defaults.catalyst_center.network_settings.telemetry.catalyst_center_as_network_collector, null) == true ? "Builtin" : "TelemetryBrokerOrUDPDirector"
  enable_netflow_collector_on_devices = try(local.site_telemetry_settings[each.key].enable_netflow_collector_on_devices, local.defaults.catalyst_center.network_settings.telemetry.enable_netflow_collector_on_devices, null)
  netflow_collector_ip_address        = try(local.site_telemetry_settings[each.key].catalyst_center_as_network_collector, local.defaults.catalyst_center.network_settings.telemetry.catalyst_center_as_network_collector, null) == false ? try(local.site_telemetry_settings[each.key].netflow_collector_ip_address, local.defaults.catalyst_center.network_settings.telemetry.netflow_collector_ip_address, null) : null
  netflow_collector_port              = try(local.site_telemetry_settings[each.key].catalyst_center_as_network_collector, local.defaults.catalyst_center.network_settings.telemetry.catalyst_center_as_network_collector, null) == false ? try(local.site_telemetry_settings[each.key].netflow_collector_port, local.defaults.catalyst_center.network_settings.telemetry.netflow_collector_port, null) : null

  depends_on = [catalystcenter_floor.floor, catalystcenter_building.building, catalystcenter_area.area_0, catalystcenter_area.area_1, catalystcenter_area.area_2, catalystcenter_area.area_3, catalystcenter_area.area_4, catalystcenter_area.area_5, catalystcenter_area.area_6, catalystcenter_area.area_7, catalystcenter_area.area_8, catalystcenter_area.area_9, catalystcenter_area.area_10, catalystcenter_banner_settings.banner, data.catalystcenter_sites.created_sites]
}

resource "catalystcenter_telemetry_settings" "global_telemetry_settings" {
  for_each = { for k, v in try(local.sites_to_settings_map, {}) : k => v if try(local.site_telemetry_settings[k], null) != null && k == "Global" && (var.manage_global_settings || (!var.manage_global_settings && length(var.managed_sites) == 0)) }

  site_id                             = try(data.catalystcenter_site.global.id, null)
  enable_wired_data_collection        = try(local.site_telemetry_settings[each.key].wired_data_collection, local.defaults.catalyst_center.network_settings.telemetry.wired_data_collection, null)
  enable_wireless_telemetry           = try(local.site_telemetry_settings[each.key].wireless_telemetry, local.defaults.catalyst_center.network_settings.telemetry.wireless_telemetry, null)
  use_builtin_trap_server             = try(local.site_telemetry_settings[each.key].catalyst_center_as_snmp_server, local.defaults.catalyst_center.network_settings.telemetry.catalyst_center_as_snmp_server, null)
  external_trap_servers               = try(local.site_telemetry_settings[each.key].snmp_servers, local.defaults.catalyst_center.network_settings.telemetry.snmp_servers, null)
  use_builtin_syslog_server           = try(local.site_telemetry_settings[each.key].catalyst_center_as_syslog_server, local.defaults.catalyst_center.network_settings.telemetry.catalyst_center_as_syslog_server, null)
  external_syslog_servers             = try(local.site_telemetry_settings[each.key].syslog_servers, local.defaults.catalyst_center.network_settings.telemetry.syslog_servers, null)
  netflow_collector                   = try(local.site_telemetry_settings[each.key].catalyst_center_as_network_collector, local.defaults.catalyst_center.network_settings.telemetry.catalyst_center_as_network_collector, null) == true ? "Builtin" : "TelemetryBrokerOrUDPDirector"
  enable_netflow_collector_on_devices = try(local.site_telemetry_settings[each.key].enable_netflow_collector_on_devices, local.defaults.catalyst_center.network_settings.telemetry.enable_netflow_collector_on_devices, null)
  netflow_collector_ip_address        = try(local.site_telemetry_settings[each.key].catalyst_center_as_network_collector, local.defaults.catalyst_center.network_settings.telemetry.catalyst_center_as_network_collector, null) == false ? try(local.site_telemetry_settings[each.key].netflow_collector_ip_address, local.defaults.catalyst_center.network_settings.telemetry.netflow_collector_ip_address, null) : null
  netflow_collector_port              = try(local.site_telemetry_settings[each.key].catalyst_center_as_network_collector, local.defaults.catalyst_center.network_settings.telemetry.catalyst_center_as_network_collector, null) == false ? try(local.site_telemetry_settings[each.key].netflow_collector_port, local.defaults.catalyst_center.network_settings.telemetry.netflow_collector_port, null) : null

  depends_on = [catalystcenter_banner_settings.global_banner]
}

resource "catalystcenter_aaa_settings" "aaa_servers" {
  for_each = { for k, v in local.site_aaa_settings : k => v if contains(local.sites, k) && k != "Global" }

  site_id                              = try(var.use_bulk_api ? coalesce(local.site_id_list_bulk[each.key], local.data_source_created_sites_list[each.key]) : local.site_id_list[each.key], local.data_source_site_list[each.key], null)
  network_aaa_server_type              = try(each.value.network_aaa.server_type, local.defaults.catalyst_center.network_settings.aaa_servers.network_aaa.server_type, null)
  network_aaa_protocol                 = try(each.value.network_aaa.protocol, local.defaults.catalyst_center.network_settings.aaa_servers.network_aaa.protocol, null)
  network_aaa_primary_server_ip        = try(each.value.network_aaa.primary_ip, local.defaults.catalyst_center.network_settings.aaa_servers.network_aaa.primary_ip, null)
  network_aaa_secondary_server_ip      = try(each.value.network_aaa.secondary_ip, local.defaults.catalyst_center.network_settings.aaa_servers.network_aaa.secondary_ip, null)
  network_aaa_shared_secret_wo         = try(each.value.network_aaa.shared_secret, local.defaults.catalyst_center.network_settings.aaa_servers.network_aaa.shared_secret, null)
  network_aaa_shared_secret_wo_version = try(each.value.network_aaa.shared_secret_version, local.defaults.catalyst_center.network_settings.aaa_servers.network_aaa.shared_secret_version, 1)
  network_aaa_pan                      = try(each.value.network_aaa.server_type, "") == "ISE" ? try(each.value.network_aaa.pan, each.value.network_aaa.primary_ip, local.defaults.catalyst_center.network_settings.aaa_servers.network_aaa.pan, null) : null
  client_aaa_server_type               = try(each.value.client_and_endpoint_aaa.server_type, local.defaults.catalyst_center.network_settings.aaa_servers.client_and_endpoint_aaa.server_type, null)
  client_aaa_protocol                  = try(each.value.client_and_endpoint_aaa.protocol, local.defaults.catalyst_center.network_settings.aaa_servers.client_and_endpoint_aaa.protocol, null)
  client_aaa_primary_server_ip         = try(each.value.client_and_endpoint_aaa.primary_ip, local.defaults.catalyst_center.network_settings.aaa_servers.client_and_endpoint_aaa.primary_ip, null)
  client_aaa_secondary_server_ip       = try(each.value.client_and_endpoint_aaa.secondary_ip, local.defaults.catalyst_center.network_settings.aaa_servers.client_and_endpoint_aaa.secondary_ip, null)
  client_aaa_shared_secret_wo          = try(each.value.client_and_endpoint_aaa.shared_secret, local.defaults.catalyst_center.network_settings.aaa_servers.client_and_endpoint_aaa.shared_secret, null)
  client_aaa_shared_secret_wo_version  = try(each.value.client_and_endpoint_aaa.shared_secret_version, local.defaults.catalyst_center.network_settings.aaa_servers.client_and_endpoint_aaa.shared_secret_version, 1)
  client_aaa_pan                       = try(each.value.client_and_endpoint_aaa.server_type, "") == "ISE" ? try(each.value.client_and_endpoint_aaa.pan, each.value.client_and_endpoint_aaa.primary_ip, local.defaults.catalyst_center.network_settings.aaa_servers.client_and_endpoint_aaa.pan, null) : null

  depends_on = [catalystcenter_floor.floor, catalystcenter_building.building, catalystcenter_area.area_0, catalystcenter_area.area_1, catalystcenter_area.area_2, catalystcenter_area.area_3, catalystcenter_area.area_4, catalystcenter_area.area_5, catalystcenter_area.area_6, catalystcenter_area.area_7, catalystcenter_area.area_8, catalystcenter_area.area_9, catalystcenter_area.area_10, catalystcenter_telemetry_settings.telemetry_settings, data.catalystcenter_sites.created_sites]
}

resource "catalystcenter_aaa_settings" "global_aaa_servers" {
  for_each = { for k, v in local.site_aaa_settings : k => v if k == "Global" && (var.manage_global_settings || (!var.manage_global_settings && length(var.managed_sites) == 0)) }

  site_id                              = try(data.catalystcenter_site.global.id, null)
  network_aaa_server_type              = try(each.value.network_aaa.server_type, local.defaults.catalyst_center.network_settings.aaa_servers.network_aaa.server_type, null)
  network_aaa_protocol                 = try(each.value.network_aaa.protocol, local.defaults.catalyst_center.network_settings.aaa_servers.network_aaa.protocol, null)
  network_aaa_primary_server_ip        = try(each.value.network_aaa.primary_ip, local.defaults.catalyst_center.network_settings.aaa_servers.network_aaa.primary_ip, null)
  network_aaa_secondary_server_ip      = try(each.value.network_aaa.secondary_ip, local.defaults.catalyst_center.network_settings.aaa_servers.network_aaa.secondary_ip, null)
  network_aaa_shared_secret_wo         = try(each.value.network_aaa.shared_secret, local.defaults.catalyst_center.network_settings.aaa_servers.network_aaa.shared_secret, null)
  network_aaa_shared_secret_wo_version = try(each.value.network_aaa.shared_secret_version, local.defaults.catalyst_center.network_settings.aaa_servers.network_aaa.shared_secret_version, 1)
  network_aaa_pan                      = try(each.value.network_aaa.server_type, "") == "ISE" ? try(each.value.network_aaa.pan, each.value.network_aaa.primary_ip, local.defaults.catalyst_center.network_settings.aaa_servers.network_aaa.pan, null) : null
  client_aaa_server_type               = try(each.value.client_and_endpoint_aaa.server_type, local.defaults.catalyst_center.network_settings.aaa_servers.client_and_endpoint_aaa.server_type, null)
  client_aaa_protocol                  = try(each.value.client_and_endpoint_aaa.protocol, local.defaults.catalyst_center.network_settings.aaa_servers.client_and_endpoint_aaa.protocol, null)
  client_aaa_primary_server_ip         = try(each.value.client_and_endpoint_aaa.primary_ip, local.defaults.catalyst_center.network_settings.aaa_servers.client_and_endpoint_aaa.primary_ip, null)
  client_aaa_secondary_server_ip       = try(each.value.client_and_endpoint_aaa.secondary_ip, local.defaults.catalyst_center.network_settings.aaa_servers.client_and_endpoint_aaa.secondary_ip, null)
  client_aaa_shared_secret_wo          = try(each.value.client_and_endpoint_aaa.shared_secret, local.defaults.catalyst_center.network_settings.aaa_servers.client_and_endpoint_aaa.shared_secret, null)
  client_aaa_shared_secret_wo_version  = try(each.value.client_and_endpoint_aaa.shared_secret_version, local.defaults.catalyst_center.network_settings.aaa_servers.client_and_endpoint_aaa.shared_secret_version, 1)
  client_aaa_pan                       = try(each.value.client_and_endpoint_aaa.server_type, "") == "ISE" ? try(each.value.client_and_endpoint_aaa.pan, each.value.client_and_endpoint_aaa.primary_ip, local.defaults.catalyst_center.network_settings.aaa_servers.client_and_endpoint_aaa.pan, null) : null

  depends_on = [catalystcenter_telemetry_settings.global_telemetry_settings]
}

### IP Pools

data "catalystcenter_ip_pools" "all_ip_pools" {
}

locals {
  site_to_ip_pools_reservation_map = merge(
    local.area_ip_pool_reservations,
    { for building in local.flat_buildings : "${building.parent_name}/${building.name}" => try(building.network_settings.ip_pools_reservations, building.ip_pools_reservations, []) if try(coalesce(try(building.network_settings.ip_pools_reservations, null), try(building.ip_pools_reservations, null)), null) != null },
    { for floor in local.flat_floors : "${floor.parent_name}/${floor.name}" => try(floor.network_settings.ip_pools_reservations, floor.ip_pools_reservations, []) if try(coalesce(try(floor.network_settings.ip_pools_reservations, null), try(floor.ip_pools_reservations, null)), null) != null }
  )

  ip_pools_reservation_detail_by_name = {
    for entry in flatten([
      for pool in try(local.catalyst_center.network_settings.ip_pools, []) : [
        for reservation in try(pool.ip_pools_reservations, []) :
        merge(reservation, { global_pool = try(reservation.global_pool, pool.name, null) })
        if try(reservation.name, null) != null
      ]
    ]) : entry.name => entry
  }

  ip_pool_reservations_flat = flatten([
    for site, reservations in local.site_to_ip_pools_reservation_map : [
      # A bare-string reservation is a name reference: resolve it to the detail object
      # from network_settings; an object is used as-is.
      for r_raw in reservations : [
        for r in [
          try(local.ip_pools_reservation_detail_by_name[tostring(r_raw)], { name = tostring(r_raw) }, r_raw)
          ] : {
          key  = r.name
          site = site
          name = r.name
          # Resolved here rather than at the resource: a literal null would
          # short-circuit the try() chain and defeat the module default.
          type = try(r.type, local.defaults.catalyst_center.network_settings.ip_pools.ip_pools_reservations.type, null)
          # Flat form: IPv4-primary parent pool by name + top-level attributes.
          flat_global_pool = try(r.global_pool, null)
          flat = try(r.global_pool, null) != null ? {
            global_pool   = r.global_pool
            subnet        = try(r.subnet, null)
            prefix_length = try(r.prefix_length, null)
            gateway       = try(r.gateway, null)
            dns_servers   = try(r.dns_servers, null)
            dhcp_servers  = try(r.dhcp_servers, null)
          } : null
          # Flat form: optional additive IPv6 space on the same reservation.
          flat_ipv6_global_pool = try(r.ipv6_global_pool, null)
          flat_ipv6 = try(r.ipv6_global_pool, null) != null ? {
            global_pool   = r.ipv6_global_pool
            subnet        = try(r.ipv6_subnet, null)
            prefix_length = try(r.ipv6_prefix_length, null)
            gateway       = try(r.ipv6_gateway, null)
            dns_servers   = try(r.ipv6_dns_servers, null)
            dhcp_servers  = try(r.ipv6_dhcp_servers, null)
          } : null
          # Legacy nested form (unchanged).
          ipv4 = try(r.ipv4, null)
          ipv6 = try(r.ipv6, null)
        }
      ]
    ]
  ])

  ip_pools_reservation_to_site_map = {
    for r in local.ip_pool_reservations_flat : r.key => r.site
  }

  # Full reservation detail, keyed identically to the map above.
  ip_pool_reservations = {
    for r in local.ip_pool_reservations_flat : r.key => r
  }
}

locals {
  _global_ip_pools_raw = try(local.global_network_settings.ip_pools, try(local.catalyst_center.network_settings.ip_pools, []))

  global_ip_pools = {
    for pool in local._global_ip_pools_raw : pool.name => {
      name = pool.name
      # Falls back to the module default; a literal null here would short-circuit
      # the try() chain at the resource and defeat that default.
      type = try(title(pool.type), title(local.defaults.catalyst_center.network_settings.ip_pools.type), null)
      # Flat form declares the family explicitly; legacy nested form infers it from
      # whichever sub-block is present.
      family        = try(pool.ip_address_space, try(pool.ipv6, null) != null ? "IPv6" : "IPv4")
      subnet        = try(split("/", pool.ip_pool_cidr)[0], pool.ipv4.subnet, pool.ipv6.subnet, null)
      prefix_length = try(tonumber(split("/", pool.ip_pool_cidr)[1]), pool.ipv4.prefix, pool.ipv6.prefix, null)
      gateway       = try(pool.gateway, pool.ipv4.gateway, pool.ipv6.gateway, null)
      dhcp_servers  = try(pool.dhcp_servers, pool.ipv4.dhcp_servers, pool.ipv6.dhcp_servers, null)
      dns_servers   = try(pool.dns_servers, pool.ipv4.dns_servers, pool.ipv6.dns_servers, null)
    }
  }
}

resource "catalystcenter_ip_pool" "ip_pool_v4" {
  for_each = { for name, pool in local.global_ip_pools : name => pool if pool.family == "IPv4" && (var.manage_global_settings || (!var.manage_global_settings && length(var.managed_sites) == 0)) }

  name                        = each.key
  pool_type                   = try(each.value.type, local.defaults.catalyst_center.network_settings.ip_pools.type, null)
  address_space_subnet        = try(each.value.subnet, null)
  address_space_prefix_length = try(tonumber(each.value.prefix_length), null)
  address_space_gateway       = try(each.value.gateway, local.defaults.catalyst_center.network_settings.ip_pools.gateway, null)
  address_space_dhcp_servers  = try(each.value.dhcp_servers, local.defaults.catalyst_center.network_settings.ip_pools.dhcp_servers, null)
  address_space_dns_servers   = try(each.value.dns_servers, local.defaults.catalyst_center.network_settings.ip_pools.dns_servers, null)

  depends_on = [catalystcenter_floor.floor, catalystcenter_building.building, catalystcenter_area.area_0, catalystcenter_area.area_1, catalystcenter_area.area_2, catalystcenter_area.area_3, catalystcenter_area.area_4, catalystcenter_area.area_5, catalystcenter_area.area_6, catalystcenter_area.area_7, catalystcenter_area.area_8, catalystcenter_area.area_9, catalystcenter_area.area_10]
}

resource "catalystcenter_ip_pool" "ip_pool_v6" {
  for_each = { for name, pool in local.global_ip_pools : name => pool if pool.family == "IPv6" && (var.manage_global_settings || (!var.manage_global_settings && length(var.managed_sites) == 0)) }

  name                        = each.key
  pool_type                   = try(each.value.type, local.defaults.catalyst_center.network_settings.ip_pools.type, null)
  address_space_subnet        = try(each.value.subnet, null)
  address_space_prefix_length = try(tonumber(each.value.prefix_length), null)
  address_space_gateway       = try(each.value.gateway, local.defaults.catalyst_center.network_settings.ip_pools.gateway, null)
  address_space_dhcp_servers  = try(each.value.dhcp_servers, local.defaults.catalyst_center.network_settings.ip_pools.dhcp_servers, null)
  address_space_dns_servers   = try(each.value.dns_servers, local.defaults.catalyst_center.network_settings.ip_pools.dns_servers, null)

  depends_on = [catalystcenter_floor.floor, catalystcenter_building.building, catalystcenter_area.area_0, catalystcenter_area.area_1, catalystcenter_area.area_2, catalystcenter_area.area_3, catalystcenter_area.area_4, catalystcenter_area.area_5, catalystcenter_area.area_6, catalystcenter_area.area_7, catalystcenter_area.area_8, catalystcenter_area.area_9, catalystcenter_area.area_10]
}

locals {
  reservation_parent_pool_v4 = {
    for r in local.ip_pool_reservations_flat : r.key => try(coalesce(r.flat_global_pool, try(r.ipv4.global_pool, null)), null)
    if try(coalesce(r.flat_global_pool, try(r.ipv4.global_pool, null)), null) != null
  }

  reservation_parent_pool_v6 = {
    for r in local.ip_pool_reservations_flat : r.key => try(coalesce(r.flat_ipv6_global_pool, try(r.ipv6.global_pool, null)), null)
    if try(coalesce(r.flat_ipv6_global_pool, try(r.ipv6.global_pool, null)), null) != null
  }

  ip_pool_ids_v4 = { for name, r in catalystcenter_ip_pool.ip_pool_v4 : name => r.id }
  ip_pool_ids_v6 = { for name, r in catalystcenter_ip_pool.ip_pool_v6 : name => r.id }

  data_source_ip_pool_ids = try({
    for pool in data.catalystcenter_ip_pools.all_ip_pools.pools : pool.name => pool.id
  }, {})
}

resource "catalystcenter_ip_pool_reservation" "pool_reservation" {
  for_each = { for k, v in try(local.ip_pools_reservation_to_site_map, {}) : k => v if contains(local.sites, v) || (!var.manage_global_settings && length(var.managed_sites) == 0) }

  site_id = try(var.use_bulk_api ? coalesce(local.site_id_list_bulk[each.value], local.data_source_created_sites_list[each.value]) : coalesce(lookup(local.site_id_list, each.value, null), local.data_source_created_sites_list[each.value]), null)

  name      = local.ip_pool_reservations[each.key].name
  pool_type = try(local.ip_pool_reservations[each.key].type, local.defaults.catalyst_center.network_settings.ip_pools.ip_pools_reservations.type, null)

  # Flat reservations resolving to an IPv4 pool feed the ipv4_* args from their
  # top-level attributes; legacy nested reservations feed them from `ipv4:`.
  ipv4_global_pool_id = try(coalesce(lookup(local.ip_pool_ids_v4, lookup(local.reservation_parent_pool_v4, each.key, ""), null), lookup(local.data_source_ip_pool_ids, lookup(local.reservation_parent_pool_v4, each.key, ""), null)), null)
  ipv4_prefix_length  = lookup(local.reservation_parent_pool_v4, each.key, null) != null ? try(local.ip_pool_reservations[each.key].flat.prefix_length, local.ip_pool_reservations[each.key].ipv4.prefix_length, local.defaults.catalyst_center.network_settings.ip_pools.ip_pools_reservations.ipv4.prefix_length, null) : null
  ipv4_gateway        = lookup(local.reservation_parent_pool_v4, each.key, null) != null ? try(local.ip_pool_reservations[each.key].flat.gateway, local.ip_pool_reservations[each.key].ipv4.gateway, local.defaults.catalyst_center.network_settings.ip_pools.ip_pools_reservations.ipv4.gateway, null) : null
  ipv4_dhcp_servers   = lookup(local.reservation_parent_pool_v4, each.key, null) != null ? try(local.ip_pool_reservations[each.key].flat.dhcp_servers, local.ip_pool_reservations[each.key].ipv4.dhcp_servers, local.defaults.catalyst_center.network_settings.ip_pools.ip_pools_reservations.ipv4.dhcp_servers, null) : null
  ipv4_dns_servers    = lookup(local.reservation_parent_pool_v4, each.key, null) != null ? try(local.ip_pool_reservations[each.key].flat.dns_servers, local.ip_pool_reservations[each.key].ipv4.dns_servers, local.defaults.catalyst_center.network_settings.ip_pools.ip_pools_reservations.ipv4.dns_servers, null) : null
  ipv4_subnet         = lookup(local.reservation_parent_pool_v4, each.key, null) != null ? try(local.ip_pool_reservations[each.key].flat.subnet, local.ip_pool_reservations[each.key].ipv4.subnet, local.defaults.catalyst_center.network_settings.ip_pools.ip_pools_reservations.ipv4.subnet, null) : null

  ipv6_global_pool_id = try(coalesce(lookup(local.ip_pool_ids_v6, lookup(local.reservation_parent_pool_v6, each.key, ""), null), lookup(local.data_source_ip_pool_ids, lookup(local.reservation_parent_pool_v6, each.key, ""), null)), null)
  ipv6_prefix_length  = lookup(local.reservation_parent_pool_v6, each.key, null) != null ? try(local.ip_pool_reservations[each.key].flat_ipv6.prefix_length, local.ip_pool_reservations[each.key].ipv6.prefix_length, local.defaults.catalyst_center.network_settings.ip_pools.ip_pools_reservations.ipv6.prefix_length, null) : null
  ipv6_gateway        = lookup(local.reservation_parent_pool_v6, each.key, null) != null ? try(local.ip_pool_reservations[each.key].flat_ipv6.gateway, local.ip_pool_reservations[each.key].ipv6.gateway, local.defaults.catalyst_center.network_settings.ip_pools.ip_pools_reservations.ipv6.gateway, null) : null
  ipv6_dhcp_servers   = lookup(local.reservation_parent_pool_v6, each.key, null) != null ? try(local.ip_pool_reservations[each.key].flat_ipv6.dhcp_servers, local.ip_pool_reservations[each.key].ipv6.dhcp_servers, local.defaults.catalyst_center.network_settings.ip_pools.ip_pools_reservations.ipv6.dhcp_servers, null) : null
  ipv6_dns_servers    = lookup(local.reservation_parent_pool_v6, each.key, null) != null ? try(local.ip_pool_reservations[each.key].flat_ipv6.dns_servers, local.ip_pool_reservations[each.key].ipv6.dns_servers, local.defaults.catalyst_center.network_settings.ip_pools.ip_pools_reservations.ipv6.dns_servers, null) : null
  ipv6_subnet         = lookup(local.reservation_parent_pool_v6, each.key, null) != null ? try(local.ip_pool_reservations[each.key].flat_ipv6.subnet, local.ip_pool_reservations[each.key].ipv6.subnet, local.defaults.catalyst_center.network_settings.ip_pools.ip_pools_reservations.ipv6.subnet, null) : null
  ipv6_slaac_support  = lookup(local.reservation_parent_pool_v6, each.key, null) != null && try(coalesce(try(local.ip_pool_reservations[each.key].flat_ipv6.prefix_length, null), try(local.ip_pool_reservations[each.key].ipv6.prefix_length, null)), 0) == 64 ? true : null

  depends_on = [catalystcenter_ip_pool.ip_pool_v4, catalystcenter_ip_pool.ip_pool_v6, data.catalystcenter_sites.created_sites]
}
