# CREDENTIALS

locals {
  sites_to_creds_map = merge(
    { for area in try(local.catalyst_center.sites.areas, []) : try("${area.parent_name}/${area.name}", area.name) => {
      cli          = try(area.cli_credentials, null)
      snmpv3       = try(area.snmpv3_credentials, null)
      snmpv2_read  = try(area.snmpv2_read_credentials, null)
      snmpv2_write = try(area.snmpv2_write_credentials, null)
      https_read   = try(area.https_read_credentials, null)
      https_write  = try(area.https_write_credentials, null)
    } },
    { for building in try(local.catalyst_center.sites.buildings, []) : "${building.parent_name}/${building.name}" => {
      cli          = try(building.cli_credentials, null)
      snmpv3       = try(building.snmpv3_credentials, null)
      snmpv2_read  = try(building.snmpv2_read_credentials, null)
      snmpv2_write = try(building.snmpv2_write_credentials, null)
      https_read   = try(building.https_read_credentials, null)
      https_write  = try(building.https_write_credentials, null)
    } },
    { for floor in try(local.catalyst_center.sites.floors, []) : "${floor.parent_name}/${floor.name}" => {
      cli          = try(floor.cli_credentials, null)
      snmpv3       = try(floor.snmpv3_credentials, null)
      snmpv2_read  = try(floor.snmpv2_read_credentials, null)
      snmpv2_write = try(floor.snmpv2_write_credentials, null)
      https_read   = try(floor.https_read_credentials, null)
      https_write  = try(floor.https_write_credentials, null)
    } }
  )

  sites_to_settings_map = merge(
    { "Global" = try(local.catalyst_center.sites.global.network_settings, null) },
    { for area in try(local.catalyst_center.sites.areas, []) : try("${area.parent_name}/${area.name}", area.name) => try(area.network_settings, null) },
    { for building in try(local.catalyst_center.sites.buildings, []) : "${building.parent_name}/${building.name}" => try(building.network_settings, null) },
    { for floor in try(local.catalyst_center.sites.floors, []) : "${floor.parent_name}/${floor.name}" => try(floor.network_settings, null) }
  )
}

resource "catalystcenter_credentials_https_read" "https_read_credentials" {
  for_each = { for cred in try(local.catalyst_center.network_settings.device_credentials.https_read_credentials, []) : cred.name => cred if var.manage_global_settings || (!var.manage_global_settings && length(var.managed_sites) == 0) }

  description = each.key
  username    = try(each.value.username, local.defaults.catalyst_center.network_settings.device_credentials.https_read_credentials.username, null)
  password    = try(each.value.password, local.defaults.catalyst_center.network_settings.device_credentials.https_read_credentials.password, null)
  port        = try(each.value.port, local.defaults.catalyst_center.network_settings.device_credentials.https_read_credentials.port, null)
}

resource "catalystcenter_credentials_https_write" "https_write_credentials" {
  for_each = { for cred in try(local.catalyst_center.network_settings.device_credentials.https_write_credentials, []) : cred.name => cred if var.manage_global_settings || (!var.manage_global_settings && length(var.managed_sites) == 0) }

  description = each.key
  username    = try(each.value.username, local.defaults.catalyst_center.network_settings.device_credentials.https_write_credentials.username, null)
  password    = try(each.value.password, local.defaults.catalyst_center.network_settings.device_credentials.https_write_credentials.password, null)
  port        = try(each.value.port, local.defaults.catalyst_center.network_settings.device_credentials.https_write_credentials.port, null)
}

resource "catalystcenter_credentials_cli" "cli_credentials" {
  for_each = { for cred in try(local.catalyst_center.network_settings.device_credentials.cli_credentials, []) : cred.name => cred if var.manage_global_settings || (!var.manage_global_settings && length(var.managed_sites) == 0) }

  description     = each.key
  username        = try(each.value.username, local.defaults.catalyst_center.network_settings.device_credentials.cli_credentials.username, null)
  password        = try(each.value.password, local.defaults.catalyst_center.network_settings.device_credentials.cli_credentials.password, null)
  enable_password = try(each.value.enable, local.defaults.catalyst_center.network_settings.device_credentials.cli_credentials.enable, null)
}

resource "catalystcenter_credentials_snmpv2_read" "snmpv2_read_credentials" {
  for_each = { for cred in try(local.catalyst_center.network_settings.device_credentials.snmpv2_read_credentials, []) : cred.name => cred if var.manage_global_settings || (!var.manage_global_settings && length(var.managed_sites) == 0) }

  description    = each.key
  read_community = try(each.value.read_community, local.defaults.catalyst_center.network_settings.device_credentials.snmpv2_read_credentials.read_community, null)
}

resource "catalystcenter_credentials_snmpv2_write" "snmpv2_write_credentials" {
  for_each = { for cred in try(local.catalyst_center.network_settings.device_credentials.snmpv2_write_credentials, []) : cred.name => cred if var.manage_global_settings || (!var.manage_global_settings && length(var.managed_sites) == 0) }

  description     = each.key
  write_community = try(each.value.write_community, local.defaults.catalyst_center.network_settings.device_credentials.snmpv2_write_credentials.write_community, null)
}

resource "catalystcenter_credentials_snmpv3" "snmpv3_credentials" {
  for_each = { for cred in try(local.catalyst_center.network_settings.device_credentials.snmpv3_credentials, []) : cred.name => cred if var.manage_global_settings || (!var.manage_global_settings && length(var.managed_sites) == 0) }

  description      = each.key
  username         = try(each.value.username, local.defaults.catalyst_center.network_settings.device_credentials.snmpv3_credentials.username, null)
  privacy_type     = try(each.value.privacy_type, local.defaults.catalyst_center.network_settings.device_credentials.snmpv3_credentials.privacy_type, null)
  privacy_password = try(each.value.privacy_password, local.defaults.catalyst_center.network_settings.device_credentials.snmpv3_credentials.privacy_password, null)
  auth_type        = try(each.value.auth_type, local.defaults.catalyst_center.network_settings.device_credentials.snmpv3_credentials.auth_type, null)
  auth_password    = try(each.value.auth_password, local.defaults.catalyst_center.network_settings.device_credentials.snmpv3_credentials.auth_password, null)
  snmp_mode        = try(each.value.snmp_mode, local.defaults.catalyst_center.network_settings.device_credentials.snmpv3_credentials.snmp_mode, null)
}

resource "catalystcenter_assign_credentials" "assign_credentials" {
  for_each = { for k, v in try(local.sites_to_creds_map, {}) : k => v if(v.cli != null || v.snmpv3 != null || v.https_read != null || v.https_write != null) && contains(local.sites, k) && k != "Global" }

  site_id          = try(local.site_id_list[each.key], local.data_source_site_list[each.key], null)
  cli_id           = each.value.cli != null ? try(catalystcenter_credentials_cli.cli_credentials[each.value.cli].id, data.catalystcenter_assign_credentials.global_assign_credentials.cli_id) : null
  https_read_id    = each.value.https_read != null ? try(catalystcenter_credentials_https_read.https_read_credentials[each.value.https_read].id, data.catalystcenter_assign_credentials.global_assign_credentials.https_read_id) : null
  https_write_id   = each.value.https_write != null ? try(catalystcenter_credentials_https_write.https_write_credentials[each.value.https_write].id, data.catalystcenter_assign_credentials.global_assign_credentials.https_write_id) : null
  snmp_v2_read_id  = each.value.snmpv2_read != null ? try(catalystcenter_credentials_snmpv2_read.snmpv2_read_credentials[each.value.snmpv2_read].id, data.catalystcenter_assign_credentials.global_assign_credentials.snmp_v2_read_id) : null
  snmp_v2_write_id = each.value.snmpv2_write != null ? try(catalystcenter_credentials_snmpv2_write.snmpv2_write_credentials[each.value.snmpv2_write].id, data.catalystcenter_assign_credentials.global_assign_credentials.snmp_v2_write_id) : null
  snmp_v3_id       = each.value.snmpv3 != null ? try(catalystcenter_credentials_snmpv3.snmpv3_credentials[each.value.snmpv3].id, data.catalystcenter_assign_credentials.global_assign_credentials.snmp_v3_id) : null

  depends_on = [catalystcenter_floor.floor, catalystcenter_building.building, catalystcenter_area.area_0, catalystcenter_area.area_1, catalystcenter_area.area_2, catalystcenter_area.area_3]
}

resource "catalystcenter_assign_credentials" "global_assign_credentials" {
  for_each = { for k, v in try(local.sites_to_creds_map, {}) : k => v if(v.cli != null || v.snmpv3 != null || v.https_read != null || v.https_write != null) && ((var.manage_global_settings && k == "Global") || (!var.manage_global_settings && length(var.managed_sites) == 0)) }

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
  network_settings   = { for settings in try(local.catalyst_center.network_settings.network, []) : settings.name => settings }
  aaa_settings       = { for settings in try(local.catalyst_center.network_settings.aaa_servers, []) : settings.name => settings }
  telemetry_settings = { for settings in try(local.catalyst_center.network_settings.telemetry, []) : settings.name => settings }
}

resource "catalystcenter_ntp_settings" "ntp_servers" {
  for_each = { for k, v in try(local.sites_to_settings_map, {}) : k => v if try(local.network_settings[v.network].ntp_servers, null) != null && contains(local.sites, k) && k != "Global" }

  site_id = try(local.site_id_list[each.key], local.data_source_site_list[each.key], null)
  servers = try(local.network_settings[each.value.network].ntp_servers, local.defaults.catalyst_center.network_settings.network.ntp_servers, null)

  depends_on = [catalystcenter_floor.floor, catalystcenter_building.building, catalystcenter_area.area_0, catalystcenter_area.area_1, catalystcenter_area.area_2, catalystcenter_area.area_3]
}

resource "catalystcenter_ntp_settings" "global_ntp_servers" {
  for_each = { for k, v in try(local.sites_to_settings_map, {}) : k => v if try(local.network_settings[v.network].ntp_servers, null) != null && k == "Global" && (var.manage_global_settings || (!var.manage_global_settings && length(var.managed_sites) == 0)) }

  site_id = try(data.catalystcenter_site.global.id, null)
  servers = try(local.network_settings[each.value.network].ntp_servers, local.defaults.catalyst_center.network_settings.network.ntp_servers, null)

  depends_on = [catalystcenter_floor.floor, catalystcenter_building.building, catalystcenter_area.area_0, catalystcenter_area.area_1, catalystcenter_area.area_2, catalystcenter_area.area_3]
}

resource "catalystcenter_dhcp_settings" "dhcp_servers" {
  for_each = { for k, v in try(local.sites_to_settings_map, {}) : k => v if try(local.network_settings[v.network].dhcp_servers, null) != null && contains(local.sites, k) && k != "Global" }

  site_id = try(local.site_id_list[each.key], local.data_source_site_list[each.key], null)
  servers = try(local.network_settings[each.value.network].dhcp_servers, local.defaults.catalyst_center.network_settings.network.dhcp_servers, null)

  depends_on = [catalystcenter_floor.floor, catalystcenter_building.building, catalystcenter_area.area_0, catalystcenter_area.area_1, catalystcenter_area.area_2, catalystcenter_area.area_3]
}

resource "catalystcenter_dhcp_settings" "global_dhcp_servers" {
  for_each = { for k, v in try(local.sites_to_settings_map, {}) : k => v if try(local.network_settings[v.network].dhcp_servers, null) != null && k == "Global" && (var.manage_global_settings || (!var.manage_global_settings && length(var.managed_sites) == 0)) }

  site_id = try(data.catalystcenter_site.global.id, null)
  servers = try(local.network_settings[each.value.network].dhcp_servers, local.defaults.catalyst_center.network_settings.network.dhcp_servers, null)
}

resource "catalystcenter_dns_settings" "dns_settings" {
  for_each = { for k, v in try(local.sites_to_settings_map, {}) : k => v if try(local.network_settings[v.network].domain_name, null) != null && contains(local.sites, k) && k != "Global" }

  site_id     = try(local.site_id_list[each.key], local.data_source_site_list[each.key], null)
  domain_name = try(local.network_settings[each.value.network].domain_name, local.defaults.catalyst_center.network_settings.network.domain_name, null)
  dns_servers = try(local.network_settings[each.value.network].dns_servers, local.defaults.catalyst_center.network_settings.network.dns_servers, null)

  depends_on = [catalystcenter_floor.floor, catalystcenter_building.building, catalystcenter_area.area_0, catalystcenter_area.area_1, catalystcenter_area.area_2, catalystcenter_area.area_3]
}

resource "catalystcenter_dns_settings" "global_dns_settings" {
  for_each = { for k, v in try(local.sites_to_settings_map, {}) : k => v if try(local.network_settings[v.network].domain_name, null) != null && k == "Global" && (var.manage_global_settings || (!var.manage_global_settings && length(var.managed_sites) == 0)) }

  site_id     = try(data.catalystcenter_site.global.id, null)
  domain_name = try(local.network_settings[each.value.network].domain_name, local.defaults.catalyst_center.network_settings.network.domain_name, null)
  dns_servers = try(local.network_settings[each.value.network].dns_servers, local.defaults.catalyst_center.network_settings.network.dns_servers, null)
}

resource "catalystcenter_timezone_settings" "timezone" {
  for_each = { for k, v in try(local.sites_to_settings_map, {}) : k => v if try(local.network_settings[v.network].timezone, null) != null && contains(local.sites, k) && k != "Global" }

  site_id    = try(local.site_id_list[each.key], local.data_source_site_list[each.key], null)
  identifier = try(local.network_settings[each.value.network].timezone, local.defaults.catalyst_center.network_settings.network.timezone, null)

  depends_on = [catalystcenter_floor.floor, catalystcenter_building.building, catalystcenter_area.area_0, catalystcenter_area.area_1, catalystcenter_area.area_2, catalystcenter_area.area_3]
}

resource "catalystcenter_timezone_settings" "global_timezone" {
  for_each = { for k, v in try(local.sites_to_settings_map, {}) : k => v if try(local.network_settings[v.network].timezone, null) != null && k == "Global" && (var.manage_global_settings || (!var.manage_global_settings && length(var.managed_sites) == 0)) }

  site_id    = try(data.catalystcenter_site.global.id, null)
  identifier = try(local.network_settings[each.value.network].timezone, local.defaults.catalyst_center.network_settings.network.timezone, null)
}

resource "catalystcenter_banner_settings" "banner" {
  for_each = { for k, v in try(local.sites_to_settings_map, {}) : k => v if try(local.network_settings[v.network].banner, null) != null && contains(local.sites, k) && k != "Global" }

  site_id = try(local.site_id_list[each.key], local.data_source_site_list[each.key], null)
  type    = try(local.network_settings[each.value.network].banner, local.defaults.catalyst_center.network_settings.network.banner, null) != null ? "Custom" : "Builtin"
  message = try(local.network_settings[each.value.network].banner, local.defaults.catalyst_center.network_settings.network.banner, null)

  depends_on = [catalystcenter_floor.floor, catalystcenter_building.building, catalystcenter_area.area_0, catalystcenter_area.area_1, catalystcenter_area.area_2, catalystcenter_area.area_3]
}

resource "catalystcenter_banner_settings" "global_banner" {
  for_each = { for k, v in try(local.sites_to_settings_map, {}) : k => v if try(local.network_settings[v.network].banner, null) != null && k == "Global" && (var.manage_global_settings || (!var.manage_global_settings && length(var.managed_sites) == 0)) }

  site_id = try(data.catalystcenter_site.global.id, null)
  type    = try(local.network_settings[each.value.network].banner, local.defaults.catalyst_center.network_settings.network.banner, null) != null ? "Custom" : "Builtin"
  message = try(local.network_settings[each.value.network].banner, local.defaults.catalyst_center.network_settings.network.banner, null)
}

resource "catalystcenter_telemetry_settings" "telemetry_settings" {
  for_each = { for k, v in try(local.sites_to_settings_map, {}) : k => v if try(v.telemetry, null) != null && contains(local.sites, k) && k != "Global" }

  site_id                             = try(local.site_id_list[each.key], local.data_source_site_list[each.key], null)
  enable_wired_data_collection        = try(local.telemetry_settings[each.value.telemetry].wired_data_collection, local.defaults.catalyst_center.network_settings.telemetry.wired_data_collection, null)
  enable_wireless_telemetry           = try(local.telemetry_settings[each.value.telemetry].wireless_telemetry, local.defaults.catalyst_center.network_settings.telemetry.wireless_telemetry, null)
  use_builtin_trap_server             = try(local.telemetry_settings[each.value.telemetry].catalyst_center_as_snmp_server, local.defaults.catalyst_center.network_settings.telemetry.catalyst_center_as_snmp_server, null)
  external_trap_servers               = try(local.telemetry_settings[each.value.telemetry].snmp_servers, local.defaults.catalyst_center.network_settings.telemetry.snmp_servers, null)
  use_builtin_syslog_server           = try(local.telemetry_settings[each.value.telemetry].catalyst_center_as_syslog_server, local.defaults.catalyst_center.network_settings.telemetry.catalyst_center_as_syslog_server, null)
  external_syslog_servers             = try(local.telemetry_settings[each.value.telemetry].syslog_servers, local.defaults.catalyst_center.network_settings.telemetry.syslog_servers, null)
  netflow_collector                   = try(local.telemetry_settings[each.value.telemetry].catalyst_center_as_network_collector, local.defaults.catalyst_center.network_settings.telemetry.catalyst_center_as_network_collector, null) == true ? "Builtin" : "TelemetryBrokerOrUDPDirector"
  enable_netflow_collector_on_devices = try(local.telemetry_settings[each.value.telemetry].enable_netflow_collector_on_devices, local.defaults.catalyst_center.network_settings.telemetry.enable_netflow_collector_on_devices, null)
  netflow_collector_ip_address        = try(local.telemetry_settings[each.value.telemetry].catalyst_center_as_network_collector, local.defaults.catalyst_center.network_settings.telemetry.catalyst_center_as_network_collector, null) == false ? try(local.telemetry_settings[each.value.telemetry].netflow_collector_ip_address, local.defaults.catalyst_center.network_settings.telemetry.netflow_collector_ip_address, null) : null
  netflow_collector_port              = try(local.telemetry_settings[each.value.telemetry].catalyst_center_as_network_collector, local.defaults.catalyst_center.network_settings.telemetry.catalyst_center_as_network_collector, null) == false ? try(local.telemetry_settings[each.value.telemetry].netflow_collector_port, local.defaults.catalyst_center.network_settings.telemetry.netflow_collector_port, null) : null

  depends_on = [catalystcenter_floor.floor, catalystcenter_building.building, catalystcenter_area.area_0, catalystcenter_area.area_1, catalystcenter_area.area_2, catalystcenter_area.area_3]
}

resource "catalystcenter_telemetry_settings" "global_telemetry_settings" {
  for_each = { for k, v in try(local.sites_to_settings_map, {}) : k => v if try(v.telemetry, null) != null && k == "Global" && (var.manage_global_settings || (!var.manage_global_settings && length(var.managed_sites) == 0)) }

  site_id                             = try(data.catalystcenter_site.global.id, null)
  enable_wired_data_collection        = try(local.telemetry_settings[each.value.telemetry].wired_data_collection, local.defaults.catalyst_center.network_settings.telemetry.wired_data_collection, null)
  enable_wireless_telemetry           = try(local.telemetry_settings[each.value.telemetry].wireless_telemetry, local.defaults.catalyst_center.network_settings.telemetry.wireless_telemetry, null)
  use_builtin_trap_server             = try(local.telemetry_settings[each.value.telemetry].catalyst_center_as_snmp_server, local.defaults.catalyst_center.network_settings.telemetry.catalyst_center_as_snmp_server, null)
  external_trap_servers               = try(local.telemetry_settings[each.value.telemetry].snmp_servers, local.defaults.catalyst_center.network_settings.telemetry.snmp_servers, null)
  use_builtin_syslog_server           = try(local.telemetry_settings[each.value.telemetry].catalyst_center_as_syslog_server, local.defaults.catalyst_center.network_settings.telemetry.catalyst_center_as_syslog_server, null)
  external_syslog_servers             = try(local.telemetry_settings[each.value.telemetry].syslog_servers, local.defaults.catalyst_center.network_settings.telemetry.syslog_servers, null)
  netflow_collector                   = try(local.telemetry_settings[each.value.telemetry].catalyst_center_as_network_collector, local.defaults.catalyst_center.network_settings.telemetry.catalyst_center_as_network_collector, null) == true ? "Builtin" : "TelemetryBrokerOrUDPDirector"
  enable_netflow_collector_on_devices = try(local.telemetry_settings[each.value.telemetry].enable_netflow_collector_on_devices, local.defaults.catalyst_center.network_settings.telemetry.enable_netflow_collector_on_devices, null)
  netflow_collector_ip_address        = try(local.telemetry_settings[each.value.telemetry].catalyst_center_as_network_collector, local.defaults.catalyst_center.network_settings.telemetry.catalyst_center_as_network_collector, null) == false ? try(local.telemetry_settings[each.value.telemetry].netflow_collector_ip_address, local.defaults.catalyst_center.network_settings.telemetry.netflow_collector_ip_address, null) : null
  netflow_collector_port              = try(local.telemetry_settings[each.value.telemetry].catalyst_center_as_network_collector, local.defaults.catalyst_center.network_settings.telemetry.catalyst_center_as_network_collector, null) == false ? try(local.telemetry_settings[each.value.telemetry].netflow_collector_port, local.defaults.catalyst_center.network_settings.telemetry.netflow_collector_port, null) : null
}

resource "catalystcenter_aaa_settings" "aaa_servers" {
  for_each = { for k, v in try(local.sites_to_settings_map, {}) : k => v if v != null && try(v.aaa_servers, null) != null && contains(local.sites, k) && k != "Global" }

  site_id                         = try(local.site_id_list[each.key], local.data_source_site_list[each.key], null)
  network_aaa_server_type         = try(local.aaa_settings[each.value.aaa_servers].network_aaa.server_type, local.defaults.catalyst_center.network_settings.aaa_servers.network_aaa.server_type, null)
  network_aaa_protocol            = try(local.aaa_settings[each.value.aaa_servers].network_aaa.protocol, local.defaults.catalyst_center.network_settings.aaa_servers.network_aaa.protocol, null)
  network_aaa_primary_server_ip   = try(local.aaa_settings[each.value.aaa_servers].network_aaa.primary_ip, local.defaults.catalyst_center.network_settings.aaa_servers.network_aaa.primary_ip, null)
  network_aaa_secondary_server_ip = try(local.aaa_settings[each.value.aaa_servers].network_aaa.secondary_ip, local.defaults.catalyst_center.network_settings.aaa_servers.network_aaa.secondary_ip, null)
  network_aaa_shared_secret       = try(local.aaa_settings[each.value.aaa_servers].network_aaa.shared_secret, local.defaults.catalyst_center.network_settings.aaa_servers.network_aaa.shared_secret, null)
  network_aaa_pan                 = try(local.aaa_settings[each.value.aaa_servers].network_aaa.server_type, "") == "ISE" ? try(local.aaa_settings[each.value.aaa_servers].network_aaa.pan, local.aaa_settings[each.value.aaa_servers].network_aaa.primary_ip, local.defaults.catalyst_center.network_settings.aaa_servers.network_aaa.pan, null) : null
  client_aaa_server_type          = try(local.aaa_settings[each.value.aaa_servers].client_and_endpoint_aaa.server_type, local.defaults.catalyst_center.network_settings.aaa_servers.client_and_endpoint_aaa.server_type, null)
  client_aaa_protocol             = try(local.aaa_settings[each.value.aaa_servers].client_and_endpoint_aaa.protocol, local.defaults.catalyst_center.network_settings.aaa_servers.client_and_endpoint_aaa.protocol, null)
  client_aaa_primary_server_ip    = try(local.aaa_settings[each.value.aaa_servers].client_and_endpoint_aaa.primary_ip, local.defaults.catalyst_center.network_settings.aaa_servers.client_and_endpoint_aaa.primary_ip, null)
  client_aaa_secondary_server_ip  = try(local.aaa_settings[each.value.aaa_servers].client_and_endpoint_aaa.secondary_ip, local.defaults.catalyst_center.network_settings.aaa_servers.client_and_endpoint_aaa.secondary_ip, null)
  client_aaa_shared_secret        = try(local.aaa_settings[each.value.aaa_servers].client_and_endpoint_aaa.shared_secret, local.defaults.catalyst_center.network_settings.aaa_servers.client_and_endpoint_aaa.shared_secret, null)
  client_aaa_pan                  = try(local.aaa_settings[each.value.aaa_servers].client_and_endpoint_aaa.server_type, "") == "ISE" ? try(local.aaa_settings[each.value.aaa_servers].client_and_endpoint_aaa.pan, local.aaa_settings[each.value.aaa_servers].client_and_endpoint_aaa.primary_ip, local.defaults.catalyst_center.network_settings.aaa_servers.client_and_endpoint_aaa.pan, null) : null

  depends_on = [catalystcenter_floor.floor, catalystcenter_building.building, catalystcenter_area.area_0, catalystcenter_area.area_1, catalystcenter_area.area_2, catalystcenter_area.area_3]
}

resource "catalystcenter_aaa_settings" "global_aaa_servers" {
  for_each = { for k, v in try(local.sites_to_settings_map, {}) : k => v if v != null && try(v.aaa_servers, null) != null && k == "Global" && (var.manage_global_settings || (!var.manage_global_settings && length(var.managed_sites) == 0)) }

  site_id                         = try(data.catalystcenter_site.global.id, null)
  network_aaa_server_type         = try(local.aaa_settings[each.value.aaa_servers].network_aaa.server_type, local.defaults.catalyst_center.network_settings.aaa_servers.network_aaa.server_type, null)
  network_aaa_protocol            = try(local.aaa_settings[each.value.aaa_servers].network_aaa.protocol, local.defaults.catalyst_center.network_settings.aaa_servers.network_aaa.protocol, null)
  network_aaa_primary_server_ip   = try(local.aaa_settings[each.value.aaa_servers].network_aaa.primary_ip, local.defaults.catalyst_center.network_settings.aaa_servers.network_aaa.primary_ip, null)
  network_aaa_secondary_server_ip = try(local.aaa_settings[each.value.aaa_servers].network_aaa.secondary_ip, local.defaults.catalyst_center.network_settings.aaa_servers.network_aaa.secondary_ip, null)
  network_aaa_shared_secret       = try(local.aaa_settings[each.value.aaa_servers].network_aaa.shared_secret, local.defaults.catalyst_center.network_settings.aaa_servers.network_aaa.shared_secret, null)
  network_aaa_pan                 = try(local.aaa_settings[each.value.aaa_servers].network_aaa.server_type, "") == "ISE" ? try(local.aaa_settings[each.value.aaa_servers].network_aaa.pan, local.aaa_settings[each.value.aaa_servers].network_aaa.primary_ip, local.defaults.catalyst_center.network_settings.aaa_servers.network_aaa.pan, null) : null
  client_aaa_server_type          = try(local.aaa_settings[each.value.aaa_servers].client_and_endpoint_aaa.server_type, local.defaults.catalyst_center.network_settings.aaa_servers.client_and_endpoint_aaa.server_type, null)
  client_aaa_protocol             = try(local.aaa_settings[each.value.aaa_servers].client_and_endpoint_aaa.protocol, local.defaults.catalyst_center.network_settings.aaa_servers.client_and_endpoint_aaa.protocol, null)
  client_aaa_primary_server_ip    = try(local.aaa_settings[each.value.aaa_servers].client_and_endpoint_aaa.primary_ip, local.defaults.catalyst_center.network_settings.aaa_servers.client_and_endpoint_aaa.primary_ip, null)
  client_aaa_secondary_server_ip  = try(local.aaa_settings[each.value.aaa_servers].client_and_endpoint_aaa.secondary_ip, local.defaults.catalyst_center.network_settings.aaa_servers.client_and_endpoint_aaa.secondary_ip, null)
  client_aaa_shared_secret        = try(local.aaa_settings[each.value.aaa_servers].client_and_endpoint_aaa.shared_secret, local.defaults.catalyst_center.network_settings.aaa_servers.client_and_endpoint_aaa.shared_secret, null)
  client_aaa_pan                  = try(local.aaa_settings[each.value.aaa_servers].client_and_endpoint_aaa.server_type, "") == "ISE" ? try(local.aaa_settings[each.value.aaa_servers].client_and_endpoint_aaa.pan, local.aaa_settings[each.value.aaa_servers].client_and_endpoint_aaa.primary_ip, local.defaults.catalyst_center.network_settings.aaa_servers.client_and_endpoint_aaa.pan, null) : null
}

### IP Pools

data "catalystcenter_ip_pools" "all_ip_pools" {
}

locals {
  ip_pools_reservations = {
    for r in flatten([
      for pool in try(local.catalyst_center.network_settings.ip_pools, []) : [
        for reservation in try(pool.ip_pools_reservations, []) : merge(
          {
            "global_pool" : try(pool.name, null)
          },
          { for key, value in reservation : key => try(value, null) }
        ) if try(pool.ip_address_space, "") == "IPv4"
      ]
    ]) : r.name => r
  }

  ipv6_pools_reservations = {
    for r in flatten([
      for pool in try(local.catalyst_center.network_settings.ip_pools, []) : [
        for reservation in try(pool.ip_pools_reservations, []) : merge(
          {
            "global_pool" : try(pool.name, null)
          },
          { for key, value in reservation : key => try(value, null) }
        ) if try(pool.ip_address_space, "") == "IPv6"
      ]
    ]) : r.name => r
  }

  site_to_ip_pools_reservation_map = merge(
    { for area in try(local.catalyst_center.sites.areas, []) : try("${area.parent_name}/${area.name}", area.name) => try(area.ip_pools_reservations, []) },
    { for building in try(local.catalyst_center.sites.buildings, []) : "${building.parent_name}/${building.name}" => try(building.ip_pools_reservations, []) },
    { for floor in try(local.catalyst_center.sites.floors, []) : "${floor.parent_name}/${floor.name}" => try(floor.ip_pools_reservations, []) }
  )

  ip_pools_reservation_to_site_map = {
    for r in flatten([
      for k, v in local.site_to_ip_pools_reservation_map : [
        for reservation in v : {
          "site" : k
          "reservation" : reservation
        }
      ]
    ]) : r.reservation => r.site
  }
}

resource "catalystcenter_ip_pool" "ip_pool_v4" {
  for_each = { for pool in try(local.catalyst_center.network_settings.ip_pools, []) : pool.name => pool if pool.ip_address_space == "IPv4" && (var.manage_global_settings || (!var.manage_global_settings && length(var.managed_sites) == 0)) }

  name                        = each.key
  pool_type                   = try(each.value.type, local.defaults.catalyst_center.network_settings.ip_pools.type, null)
  address_space_subnet        = try(split("/", each.value.ip_pool_cidr)[0], split("/", local.defaults.catalyst_center.network_settings.ip_pools.ip_pool_cidr)[0], null)
  address_space_prefix_length = try(tonumber(split("/", each.value.ip_pool_cidr)[1]), tonumber(split("/", local.defaults.catalyst_center.network_settings.ip_pools.ip_pool_cidr)[1]), null)
  address_space_gateway       = try(each.value.gateway, local.defaults.catalyst_center.network_settings.ip_pools.gateway, null)
  address_space_dhcp_servers  = try(each.value.dhcp_servers, local.defaults.catalyst_center.network_settings.ip_pools.dhcp_servers, null)
  address_space_dns_servers   = try(each.value.dns_servers, local.defaults.catalyst_center.network_settings.ip_pools.dns_servers, null)

  depends_on = [catalystcenter_floor.floor, catalystcenter_building.building, catalystcenter_area.area_0, catalystcenter_area.area_1, catalystcenter_area.area_2, catalystcenter_area.area_3]
}

resource "catalystcenter_ip_pool" "ip_pool_v6" {
  for_each = { for pool in try(local.catalyst_center.network_settings.ip_pools, []) : pool.name => pool if pool.ip_address_space == "IPv6" && (var.manage_global_settings || (!var.manage_global_settings && length(var.managed_sites) == 0)) }

  name                        = each.key
  pool_type                   = try(each.value.type, local.defaults.catalyst_center.network_settings.ip_pools.type, null)
  address_space_subnet        = try(split("/", each.value.ip_pool_cidr)[0], split("/", local.defaults.catalyst_center.network_settings.ip_pools.ip_pool_cidr)[0], null)
  address_space_prefix_length = try(tonumber(split("/", each.value.ip_pool_cidr)[1]), tonumber(split("/", local.defaults.catalyst_center.network_settings.ip_pools.ip_pool_cidr)[1]), null)
  address_space_gateway       = try(each.value.gateway, local.defaults.catalyst_center.network_settings.ip_pools.gateway, null)
  address_space_dhcp_servers  = try(each.value.dhcp_servers, local.defaults.catalyst_center.network_settings.ip_pools.dhcp_servers, null)
  address_space_dns_servers   = try(each.value.dns_servers, local.defaults.catalyst_center.network_settings.ip_pools.dns_servers, null)

  depends_on = [catalystcenter_floor.floor, catalystcenter_building.building, catalystcenter_area.area_0, catalystcenter_area.area_1, catalystcenter_area.area_2, catalystcenter_area.area_3]
}

locals {
  reservation_parent_pool_v4_list = flatten([
    for p in try(local.catalyst_center.network_settings.ip_pools, []) : [
      for r in try(p.ip_pools_reservations, []) : {
        key       = r.name
        pool_name = p.name
      }
      if try(p.ip_address_space, "") == "IPv4"
    ]
  ])

  reservation_parent_pool_v4 = {
    for item in local.reservation_parent_pool_v4_list :
    item.key => item.pool_name
  }

  reservation_parent_pool_v6_list = flatten([
    for p in try(local.catalyst_center.network_settings.ip_pools, []) : [
      for r in try(p.ip_pools_reservations, []) : {
        key       = r.name
        pool_name = p.name
      }
      if try(p.ip_address_space, "") == "IPv6"
    ]
  ])

  reservation_parent_pool_v6 = {
    for item in local.reservation_parent_pool_v6_list :
    item.key => item.pool_name
  }

  ip_pool_ids_v4 = { for name, r in catalystcenter_ip_pool.ip_pool_v4 : name => r.id }
  ip_pool_ids_v6 = { for name, r in catalystcenter_ip_pool.ip_pool_v6 : name => r.id }

  data_source_ip_pool_ids = try({
    for pool in data.catalystcenter_ip_pools.all_ip_pools.pools : pool.name => pool.id
  }, {})
}

resource "catalystcenter_ip_pool_reservation" "pool_reservation" {
  for_each = { for k, v in try(local.ip_pools_reservation_to_site_map, {}) : k => v if contains(local.sites, v) || (!var.manage_global_settings && length(var.managed_sites) == 0) }

  site_id             = try(local.site_id_list[local.ip_pools_reservation_to_site_map[each.key]], null)
  name                = each.key
  pool_type           = try(join("", [(substr(local.ip_pools_reservations[each.key].type, 0, 1)), substr(local.ip_pools_reservations[each.key].type, 1, length(local.ip_pools_reservations[each.key].type))]), local.defaults.catalyst_center.network_settings.ip_pools.ip_pools_reservations.type, null)
  ipv4_global_pool_id = try(coalesce(lookup(local.ip_pool_ids_v4, lookup(local.reservation_parent_pool_v4, each.key, ""), null), lookup(local.data_source_ip_pool_ids, lookup(local.reservation_parent_pool_v4, each.key, ""), null)), null)
  ipv4_prefix_length  = try(local.ip_pools_reservations[each.key].prefix_length, local.defaults.catalyst_center.network_settings.ip_pools.ip_pools_reservations.ipv4.prefix_length, null)
  ipv4_gateway        = try(local.ip_pools_reservations[each.key].gateway, local.defaults.catalyst_center.network_settings.ip_pools.ip_pools_reservations.ipv4.gateway, null)
  ipv4_dhcp_servers   = try(local.ip_pools_reservations[each.key].dhcp_servers, local.defaults.catalyst_center.network_settings.ip_pools.ip_pools_reservations.ipv4.dhcp_servers, null)
  ipv4_dns_servers    = try(local.ip_pools_reservations[each.key].dns_servers, local.defaults.catalyst_center.network_settings.ip_pools.ip_pools_reservations.ipv4.dns_servers, null)
  ipv4_subnet         = try(local.ip_pools_reservations[each.key].subnet, local.defaults.catalyst_center.network_settings.ip_pools.ip_pools_reservations.ipv4.subnet, null)
  ipv6_global_pool_id = try(coalesce(lookup(local.ip_pool_ids_v6, lookup(local.reservation_parent_pool_v6, each.key, ""), null), lookup(local.data_source_ip_pool_ids, lookup(local.reservation_parent_pool_v6, each.key, ""), null)), null)
  ipv6_prefix_length  = try(local.ipv6_pools_reservations[each.key], null) != null ? try(local.ipv6_pools_reservations[each.key].prefix_length, local.defaults.catalyst_center.network_settings.ip_pools.ip_pools_reservations.ipv6.prefix_length, null) : null
  ipv6_gateway        = try(local.ipv6_pools_reservations[each.key], null) != null ? try(local.ipv6_pools_reservations[each.key].gateway, local.defaults.catalyst_center.network_settings.ip_pools.ip_pools_reservations.ipv6.gateway, null) : null
  ipv6_dhcp_servers   = try(local.ipv6_pools_reservations[each.key], null) != null ? try(local.ipv6_pools_reservations[each.key].dhcp_servers, local.defaults.catalyst_center.network_settings.ip_pools.ip_pools_reservations.ipv6.dhcp_servers, null) : null
  ipv6_dns_servers    = try(local.ipv6_pools_reservations[each.key], null) != null ? try(local.ipv6_pools_reservations[each.key].dns_servers, local.defaults.catalyst_center.network_settings.ip_pools.ip_pools_reservations.ipv6.dns_servers, null) : null
  ipv6_subnet         = try(local.ipv6_pools_reservations[each.key], null) != null ? try(local.ipv6_pools_reservations[each.key].subnet, local.defaults.catalyst_center.network_settings.ip_pools.ip_pools_reservations.ipv6.subnet, null) : null
  ipv6_slaac_support  = try(local.ipv6_pools_reservations[each.key], null) != null && try(local.ipv6_pools_reservations[each.key].prefix_length, 0) == 64 ? true : null

  depends_on = [catalystcenter_ip_pool.ip_pool_v4, catalystcenter_ip_pool.ip_pool_v6]
}
