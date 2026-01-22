locals {
  l2_virtual_networks = flatten([
    for fabric_site in try(local.catalyst_center.fabric.fabric_sites, []) : [
      for vn in try(fabric_site.l2_virtual_networks, []) : merge(
        vn,
        {
          "fabric_site_name" : try(fabric_site.name, null)
        }
      )
    ]
  ])

  anycast_gateways = flatten([
    for fabric_site in try(local.catalyst_center.fabric.fabric_sites, []) : [
      for vn in try(fabric_site.anycast_gateways, []) : merge(
        vn,
        {
          "fabric_site_name" : try(fabric_site.name, null)
        }
      )
    ]
  ])

  anycast_gateways_by_fabric_site = {
    for fabric_site in try(local.catalyst_center.fabric.fabric_sites, []) :
    fabric_site.name => [
      for anycast_gateway in try(fabric_site.anycast_gateways, []) : merge(
        anycast_gateway,
        {
          "fabric_site_name" : try(fabric_site.name, null)
        }
      )
    ]
  }

  all_vn_names = [
    for vn in try(local.catalyst_center.fabric.l3_virtual_networks, []) :
    try(vn.name, vn)
  ]

  l3_virtual_networks_fabric_zone = {
    for vn in flatten([
      for fabric_site in try(local.catalyst_center.fabric.fabric_sites, []) : [
        for fabric_zone in try(fabric_site.fabric_zones, []) : [
          for vn in try(fabric_zone.l3_virtual_networks, []) : {
            name             = vn
            fabric_site_name = fabric_zone.name
          }
        ]
      ]
    ]) : vn.name => vn.fabric_site_name...
  }

  l3_virtual_networks_fabric_site = {
    for vn in flatten([
      for fabric_site in try(local.catalyst_center.fabric.fabric_sites, []) : [
        for vn in try(fabric_site.l3_virtual_networks, []) : {
          name             = try(vn.name, vn)
          fabric_site_name = fabric_site.name
        }
      ]
    ]) : vn.name => vn.fabric_site_name...
  }

  l3_virtual_networks_all = flatten([
    for fabric_site in try(local.catalyst_center.fabric.fabric_sites, []) : [
      for vn in try(fabric_site.l3_virtual_networks, []) : {
        name             = try(vn.name, vn)
        fabric_site_name = fabric_site.name
      }
    ]
  ])

  # L3 VNs for fabric zones (used in multistate mode)
  l3_virtual_networks_all_zones = flatten([
    for fabric_site in try(local.catalyst_center.fabric.fabric_sites, []) : [
      for fabric_zone in try(fabric_site.fabric_zones, []) : [
        for vn in try(fabric_zone.l3_virtual_networks, []) : {
          name                    = vn
          fabric_zone_name        = fabric_zone.name
          parent_fabric_site_name = fabric_site.name
        }
      ]
    ]
  ])

  l3_virtual_networks = {
    for key in keys(local.l3_virtual_networks_fabric_site_complete) : key => concat(
      try(local.l3_virtual_networks_fabric_site[key], []),
      try(local.l3_virtual_networks_fabric_zone[key], [])
    )
  }

  global_l3_virtual_networks = {
    for vn in try(local.catalyst_center.fabric.l3_virtual_networks, []) : vn.name => []
  }

  l3_virtual_networks_fabric_site_complete = {
    for vn in local.all_vn_names :
    vn => concat(
      lookup(local.l3_virtual_networks_fabric_site, vn, []),
      lookup(local.l3_virtual_networks_fabric_zone, vn, [])
    )
  }

  device_name_to_id = try({
    for device in data.catalystcenter_network_devices.all_devices.devices : device.hostname => device.id
  }, {})

  device_name_to_ip = try(merge(
    {
      for device in try(local.catalyst_center.inventory.devices, []) : device.name => device.device_ip
      if try(device.device_ip, null) != null
    },
    {
      for device in try(local.catalyst_center.inventory.devices, []) : device.fqdn_name => device.device_ip
      if try(device.fqdn_name, null) != null && try(device.device_ip, null) != null
    }
  ), {})
}

data "catalystcenter_transit_network" "transit" {
  for_each = var.manage_global_settings == false && length(var.managed_sites) != 0 ? toset([for transit in try(local.catalyst_center.fabric.transits, []) : transit.name]) : toset([])

  name = each.key
}

resource "catalystcenter_transit_network" "transit" {
  for_each = { for transit in try(local.catalyst_center.fabric.transits, []) : transit.name => transit if var.manage_global_settings &&
    alltrue([
      for device in try(transit.control_plane_devices, []) :
      contains(local.provisioned_sda_transit_cp_devices, device)
    ]) || (!var.manage_global_settings && length(var.managed_sites) == 0)
  }

  name                              = each.key
  type                              = try(each.value.type, local.defaults.catalyst_center.fabric.transits.type, null)
  routing_protocol_name             = try(each.value.type, "") == "IP_BASED_TRANSIT" ? try(each.value.routing_protocol_name, local.defaults.catalyst_center.fabric.transits.routing_protocol_name, null) : null
  autonomous_system_number          = try(each.value.type, "") == "IP_BASED_TRANSIT" ? try(each.value.autonomous_system_number, local.defaults.catalyst_center.fabric.transits.autonomous_system_number, null) : null
  is_multicast_over_transit_enabled = try(each.value.type, "") != "IP_BASED_TRANSIT" ? try(each.value.multicast_over_sda_transit, local.defaults.catalyst_center.fabric.transits.multicast_over_sda_transit, null) : null
  control_plane_network_device_ids  = try(each.value.type, "") != "IP_BASED_TRANSIT" ? [for device in try(each.value.control_plane_devices, []) : try(local.device_name_to_id[device], local.device_name_to_id[local.name_to_fqdn_mapping[device]], null)] : null

  depends_on = [catalystcenter_provision_devices.provision_devices, catalystcenter_provision_device.provision_device]
}

resource "catalystcenter_fabric_site" "fabric_site" {
  for_each = { for site in try(local.catalyst_center.fabric.fabric_sites, []) : site.name => site if contains(local.sites, site.name) }

  authentication_profile_name = try(each.value.authentication_template.name, local.defaults.catalyst_center.fabric.fabric_sites.authentication_template.name, null)
  site_id                     = try(local.site_id_list[each.key], each.key, null)
  pub_sub_enabled             = try(each.value.pub_sub_enabled, local.defaults.catalyst_center.fabric.fabric_sites.pub_sub_enabled, null)

  depends_on = [catalystcenter_floor.floor, catalystcenter_building.building, catalystcenter_area.area_0, catalystcenter_area.area_1, catalystcenter_area.area_2, catalystcenter_area.area_3, catalystcenter_area.area_4, catalystcenter_area.area_5, catalystcenter_area.area_6, catalystcenter_area.area_7, catalystcenter_area.area_8, catalystcenter_area.area_9, catalystcenter_telemetry_settings.telemetry_settings, catalystcenter_aaa_settings.aaa_servers]
}

resource "catalystcenter_apply_pending_fabric_events" "fabric_pending_events" {
  for_each = { for site in try(local.catalyst_center.fabric.fabric_sites, []) : site.name => site if contains(local.sites, site.name) && try(site.reconfigure, false) == true }

  fabric_id = try(catalystcenter_fabric_site.fabric_site[each.key].id, null)

  depends_on = [catalystcenter_ip_pool_reservation.pool_reservation]
}

locals {
  fabric_zones = flatten([
    for fabric_site in try(local.catalyst_center.fabric.fabric_sites, []) : [
      for fabric_zone in try(fabric_site.fabric_zones, []) : merge(
        fabric_zone,
        {
          "parent_fabric_site_name" : fabric_site.name
        }
      )
    ]
  ])
}

resource "catalystcenter_fabric_zone" "fabric_zone" {
  for_each = {
    for zone in try(local.fabric_zones, []) : zone.name => zone
    if contains(local.sites, zone.parent_fabric_site_name) && (
      contains(keys(local.site_id_list), zone.name) ||
      contains(keys(local.data_source_site_list), zone.name)
    )
  }

  authentication_profile_name = try(each.value.authentication_template.name, local.defaults.catalyst_center.fabric.fabric_sites.authentication_template.name, null)
  site_id                     = try(local.site_id_list[each.key], local.data_source_site_list[each.key])

  depends_on = [catalystcenter_fabric_site.fabric_site]
}

data "catalystcenter_fabric_sites" "fabric_sites" {
}

locals {
  fabric_zone_id_list             = { for k, v in catalystcenter_fabric_zone.fabric_zone : k => v.id }
  fabric_site_id_list             = { for k, v in catalystcenter_fabric_site.fabric_site : k => v.id }
  data_source_fabric_site_id_list = try({ for site in data.catalystcenter_fabric_sites.fabric_sites.sites : site.site_id => site.id }, {})
}

resource "catalystcenter_fabric_l3_virtual_network" "global_l3_vn" {
  for_each = var.manage_global_settings == true ? try(local.global_l3_virtual_networks, {}) : {}

  virtual_network_name = each.key

  lifecycle {
    ignore_changes = [
      fabric_ids
    ]
  }

  depends_on = [catalystcenter_ip_pool_reservation.pool_reservation]
}

data "catalystcenter_fabric_l3_virtual_network" "l3_vn" {
  for_each = var.manage_global_settings == false && length(var.managed_sites) != 0 ? try(local.global_l3_virtual_networks, {}) : {}

  virtual_network_name = each.key
}

resource "catalystcenter_virtual_network_to_fabric_site" "l3_vn_to_fabric_site" {
  for_each = { for l3_vn in try(local.l3_virtual_networks_all, []) : "${l3_vn.name}#_#${l3_vn.fabric_site_name}" => l3_vn if contains(local.sites, l3_vn.fabric_site_name) && length(var.managed_sites) != 0 }

  virtual_network_name = each.value.name
  virtual_network_id   = try(catalystcenter_fabric_l3_virtual_network.global_l3_vn[each.value.name].id, data.catalystcenter_fabric_l3_virtual_network.l3_vn[each.value.name].id)
  fabric_site_id       = try(local.fabric_site_id_list[each.value.fabric_site_name], null)

  depends_on = [catalystcenter_fabric_site.fabric_site]
}

resource "catalystcenter_virtual_network_to_fabric_site" "l3_vn_to_fabric_zone" {
  for_each = {
    for l3_vn in try(local.l3_virtual_networks_all_zones, []) : "${l3_vn.name}#_#${l3_vn.fabric_zone_name}" => l3_vn
    if contains(local.sites, l3_vn.parent_fabric_site_name) && length(var.managed_sites) != 0
  }

  virtual_network_name = each.value.name
  virtual_network_id   = try(catalystcenter_fabric_l3_virtual_network.global_l3_vn[each.value.name].id, data.catalystcenter_fabric_l3_virtual_network.l3_vn[each.value.name].id)
  fabric_site_id       = try(local.fabric_zone_id_list[each.value.fabric_zone_name], null)

  depends_on = [catalystcenter_fabric_zone.fabric_zone, catalystcenter_virtual_network_to_fabric_site.l3_vn_to_fabric_site]
}

resource "catalystcenter_fabric_l3_virtual_network" "l3_vn" {
  for_each = !var.manage_global_settings && length(var.managed_sites) == 0 ? (length(local.l3_virtual_networks) > 0 ? local.l3_virtual_networks : {}) : {}

  virtual_network_name = each.key
  fabric_ids = try([
    for site in each.value : (
      contains(keys(catalystcenter_fabric_site.fabric_site), site)
      ? catalystcenter_fabric_site.fabric_site[site].id
      : contains(keys(catalystcenter_fabric_zone.fabric_zone), site)
      ? catalystcenter_fabric_zone.fabric_zone[site].id
      : try(local.data_source_fabric_site_id_list[local.data_source_site_list[site]], " ")
    )
    if(
      contains(keys(catalystcenter_fabric_site.fabric_site), site)
      || contains(keys(catalystcenter_fabric_zone.fabric_zone), site)
      || contains(keys(local.data_source_site_list), site)
    )
  ], [])

  depends_on = [catalystcenter_ip_pool_reservation.pool_reservation, catalystcenter_fabric_site.fabric_site]
}

resource "catalystcenter_fabric_l2_virtual_network" "l2_vn" {
  for_each = { for vn in try(local.l2_virtual_networks, []) : "${vn.name}#_#${vn.fabric_site_name}" => vn if(var.manage_global_settings && contains(local.sites, vn.fabric_site_name)) || (!var.manage_global_settings && contains(local.sites, vn.fabric_site_name)) }

  fabric_id                          = catalystcenter_fabric_site.fabric_site[each.value.fabric_site_name].id
  vlan_name                          = try(each.value.vlan_name, local.defaults.catalyst_center.fabric.fabric_sites.l2_virtual_networks.vlan_name, null)
  vlan_id                            = try(each.value.vlan_id, local.defaults.catalyst_center.fabric.fabric_sites.l2_virtual_networks.vlan_id, null)
  traffic_type                       = try(each.value.traffic_type, local.defaults.catalyst_center.fabric.fabric_sites.l2_virtual_networks.traffic_type, null)
  fabric_enabled_wireless            = try(each.value.fabric_enabled_wireless, local.defaults.catalyst_center.fabric.fabric_sites.l2_virtual_networks.fabric_enabled_wireless, null)
  associated_l3_virtual_network_name = try(each.value.associated_l3_virtual_network_name, local.defaults.catalyst_center.fabric.fabric_sites.l2_virtual_networks.associated_l3_virtual_network_name, null)

  depends_on = [catalystcenter_fabric_l3_virtual_network.l3_vn, catalystcenter_virtual_network_to_fabric_site.l3_vn_to_fabric_site]
}

resource "catalystcenter_anycast_gateway" "anycast_gateway" {
  for_each = { for anycast_gateway in local.anycast_gateways : anycast_gateway.ip_pool_name => anycast_gateway if contains(local.sites, anycast_gateway.fabric_site_name) && var.use_bulk_api == false }

  fabric_id                                 = catalystcenter_fabric_site.fabric_site[each.value.fabric_site_name].id
  virtual_network_name                      = try(each.value.l3_virtual_network, local.defaults.catalyst_center.fabric.fabric_sites.anycast_gateways.l3_virtual_network, null)
  ip_pool_name                              = try(each.key, null)
  vlan_name                                 = try(each.value.vlan_name, local.defaults.catalyst_center.fabric.fabric_sites.anycast_gateways.vlan_name, null)
  vlan_id                                   = try(each.value.vlan_id, local.defaults.catalyst_center.fabric.fabric_sites.anycast_gateways.vlan_id, null)
  traffic_type                              = try(each.value.traffic_type, local.defaults.catalyst_center.fabric.fabric_sites.anycast_gateways.traffic_type, null)
  critical_pool                             = lookup(each.value, "pool_type", "") == "FABRIC_AP" || lookup(each.value, "pool_type", "") == "EXTENDED_NODE" ? null : try(each.value.critical_pool, local.defaults.catalyst_center.fabric.fabric_sites.anycast_gateways.critical_pool, null)
  intra_subnet_routing_enabled              = lookup(each.value, "pool_type", "") == "FABRIC_AP" || lookup(each.value, "pool_type", "") == "EXTENDED_NODE" ? null : try(each.value.intra_subnet_routing_enabled, local.defaults.catalyst_center.fabric.fabric_sites.anycast_gateways.intra_subnet_routing_enabled, null)
  ip_directed_broadcast                     = lookup(each.value, "pool_type", "") == "FABRIC_AP" || lookup(each.value, "pool_type", "") == "EXTENDED_NODE" ? null : try(each.value.ip_directed_broadcast, local.defaults.catalyst_center.fabric.fabric_sites.anycast_gateways.ip_directed_broadcast, null)
  l2_flooding_enabled                       = lookup(each.value, "pool_type", "") == "FABRIC_AP" || lookup(each.value, "pool_type", "") == "EXTENDED_NODE" ? null : try(each.value.layer2_flooding, local.defaults.catalyst_center.fabric.fabric_sites.anycast_gateways.layer2_flooding, null)
  multiple_ip_to_mac_addresses              = lookup(each.value, "pool_type", "") == "FABRIC_AP" || lookup(each.value, "pool_type", "") == "EXTENDED_NODE" ? null : try(each.value.multiple_ip_to_mac_addresses, local.defaults.catalyst_center.fabric.fabric_sites.anycast_gateways.multiple_ip_to_mac_addresses, null)
  wireless_pool                             = lookup(each.value, "pool_type", "") == "FABRIC_AP" || lookup(each.value, "pool_type", "") == "EXTENDED_NODE" ? null : try(each.value.wireless_pool, local.defaults.catalyst_center.fabric.fabric_sites.anycast_gateways.wireless_pool, null)
  auto_generate_vlan_name                   = try(each.value.auto_generate_vlan_name, local.defaults.catalyst_center.fabric.fabric_sites.anycast_gateways.auto_generate_vlan_name, null)
  pool_type                                 = try(each.value.pool_type, local.defaults.catalyst_center.fabric.fabric_sites.anycast_gateways.pool_type, null)
  security_group_name                       = try(each.value.security_group_name, local.defaults.catalyst_center.fabric.fabric_sites.anycast_gateways.security_group_name, null)
  supplicant_based_extended_node_onboarding = try(each.value.supplicant_based_extended_node_onboarding, local.defaults.catalyst_center.fabric.fabric_sites.anycast_gateways.supplicant_based_extended_node_onboarding, null)
  tcp_mss_adjustment                        = try(each.value.tcp_mss_adjustment, local.defaults.catalyst_center.fabric.fabric_sites.anycast_gateways.tcp_mss_adjustment, null)
  group_based_policy_enforcement_enabled    = lookup(each.value, "pool_type", "") == "EXTENDED_NODE" ? try(each.value.group_based_policy_enforcement_enabled, local.defaults.catalyst_center.fabric.fabric_sites.anycast_gateways.group_based_policy_enforcement_enabled, null) : null

  depends_on = [catalystcenter_ip_pool_reservation.pool_reservation, catalystcenter_fabric_site.fabric_site, catalystcenter_fabric_l3_virtual_network.l3_vn, catalystcenter_virtual_network_to_fabric_site.l3_vn_to_fabric_site]
}

resource "catalystcenter_anycast_gateways" "anycast_gateways" {
  for_each = { for fabric_site, anycast_gateways in try(local.anycast_gateways_by_fabric_site, {}) : fabric_site => anycast_gateways if length(anycast_gateways) > 0 && contains(local.sites, fabric_site) && var.use_bulk_api }

  fabric_id = catalystcenter_fabric_site.fabric_site[each.key].id

  anycast_gateways = [
    for anycast_gateway in each.value : {
      fabric_id                                 = catalystcenter_fabric_site.fabric_site[each.key].id
      virtual_network_name                      = try(anycast_gateway.l3_virtual_network, local.defaults.catalyst_center.fabric.fabric_sites.anycast_gateways.l3_virtual_network, null)
      ip_pool_name                              = try(anycast_gateway.ip_pool_name, null)
      vlan_name                                 = try(anycast_gateway.vlan_name, local.defaults.catalyst_center.fabric.fabric_sites.anycast_gateways.vlan_name, null)
      vlan_id                                   = try(anycast_gateway.vlan_id, local.defaults.catalyst_center.fabric.fabric_sites.anycast_gateways.vlan_id, null)
      traffic_type                              = try(anycast_gateway.traffic_type, local.defaults.catalyst_center.fabric.fabric_sites.anycast_gateways.traffic_type, null)
      critical_pool                             = lookup(anycast_gateway, "pool_type", "") == "FABRIC_AP" || lookup(anycast_gateway, "pool_type", "") == "EXTENDED_NODE" ? null : try(anycast_gateway.critical_pool, local.defaults.catalyst_center.fabric.fabric_sites.anycast_gateways.critical_pool, null)
      intra_subnet_routing_enabled              = lookup(anycast_gateway, "pool_type", "") == "FABRIC_AP" || lookup(anycast_gateway, "pool_type", "") == "EXTENDED_NODE" ? null : try(anycast_gateway.intra_subnet_routing_enabled, local.defaults.catalyst_center.fabric.fabric_sites.anycast_gateways.intra_subnet_routing_enabled, null)
      ip_directed_broadcast                     = lookup(anycast_gateway, "pool_type", "") == "FABRIC_AP" || lookup(anycast_gateway, "pool_type", "") == "EXTENDED_NODE" ? null : try(anycast_gateway.ip_directed_broadcast, local.defaults.catalyst_center.fabric.fabric_sites.anycast_gateways.ip_directed_broadcast, null)
      l2_flooding_enabled                       = lookup(anycast_gateway, "pool_type", "") == "FABRIC_AP" || lookup(anycast_gateway, "pool_type", "") == "EXTENDED_NODE" ? null : try(anycast_gateway.layer2_flooding, local.defaults.catalyst_center.fabric.fabric_sites.anycast_gateways.layer2_flooding, null)
      multiple_ip_to_mac_addresses              = lookup(anycast_gateway, "pool_type", "") == "FABRIC_AP" || lookup(anycast_gateway, "pool_type", "") == "EXTENDED_NODE" ? null : try(anycast_gateway.multiple_ip_to_mac_addresses, local.defaults.catalyst_center.fabric.fabric_sites.anycast_gateways.multiple_ip_to_mac_addresses, null)
      wireless_pool                             = lookup(anycast_gateway, "pool_type", "") == "FABRIC_AP" || lookup(anycast_gateway, "pool_type", "") == "EXTENDED_NODE" ? null : try(anycast_gateway.wireless_pool, local.defaults.catalyst_center.fabric.fabric_sites.anycast_gateways.wireless_pool, null)
      auto_generate_vlan_name                   = try(anycast_gateway.auto_generate_vlan_name, local.defaults.catalyst_center.fabric.fabric_sites.anycast_gateways.auto_generate_vlan_name, null)
      pool_type                                 = try(anycast_gateway.pool_type, local.defaults.catalyst_center.fabric.fabric_sites.anycast_gateways.pool_type, null)
      security_group_name                       = try(anycast_gateway.security_group_name, local.defaults.catalyst_center.fabric.fabric_sites.anycast_gateways.security_group_name, null)
      supplicant_based_extended_node_onboarding = try(anycast_gateway.supplicant_based_extended_node_onboarding, local.defaults.catalyst_center.fabric.fabric_sites.anycast_gateways.supplicant_based_extended_node_onboarding, null)
      tcp_mss_adjustment                        = try(anycast_gateway.tcp_mss_adjustment, local.defaults.catalyst_center.fabric.fabric_sites.anycast_gateways.tcp_mss_adjustment, null)
      group_based_policy_enforcement_enabled    = lookup(anycast_gateway, "pool_type", "") == "EXTENDED_NODE" ? try(anycast_gateway.group_based_policy_enforcement_enabled, local.defaults.catalyst_center.fabric.fabric_sites.anycast_gateways.group_based_policy_enforcement_enabled, null) : null
    }
  ]

  depends_on = [catalystcenter_ip_pool_reservation.pool_reservation, catalystcenter_fabric_site.fabric_site, catalystcenter_fabric_l3_virtual_network.l3_vn, catalystcenter_virtual_network_to_fabric_site.l3_vn_to_fabric_site]
}

locals {
  border_devices = { for device in try(local.catalyst_center.fabric.border_devices, []) : device.name => device }

  fabric_devices = [for device in try(local.catalyst_center.inventory.devices, []) : device if strcontains(device.state, "PROVISION") && try(device.fabric_roles, null) != null && contains(local.sites, try(device.site, "NONE"))]

  fabric_devices_by_site = {
    for fabric_site in distinct([for d in try(local.catalyst_center.inventory.devices, []) : try(d.fabric_site, "")]) :
    fabric_site => [for d in local.fabric_devices : d if d.fabric_site == fabric_site] if fabric_site != ""
  }
}

resource "catalystcenter_fabric_devices" "fabric_devices" {
  for_each = { for fabric_site, devices in try(local.fabric_devices_by_site, {}) : fabric_site => devices if length(devices) > 0 && var.use_bulk_api }

  fabric_id = try(local.fabric_site_id_list[each.key], null)
  fabric_devices = [
    for device in each.value : {
      network_device_id = coalesce(
        try(lookup(local.device_name_to_id, device.name, null), null),
        try(lookup(local.device_name_to_id, device.fqdn_name, null), null),
        try(lookup(local.device_ip_to_id, device.device_ip, null), null)
      )
      fabric_id = try(catalystcenter_fabric_site.fabric_site[device.fabric_site].id, null)
      device_roles = try([
        for fabric_role in try(device.fabric_roles, []) : fabric_role if fabric_role != "EMBEDDED_WIRELESS_CONTROLLER_NODE"
      ], local.defaults.catalyst_center.inventory.devices.fabric_roles, null)
      border_types                    = try(local.border_devices[device.name].border_types, local.defaults.catalyst_center.fabric.border_devices.border_types, null)
      local_autonomous_system_number  = try(local.border_devices[device.name].local_autonomous_system_number, local.defaults.catalyst_center.fabric.border_devices.local_autonomous_system_number, null)
      default_exit                    = try(local.border_devices[device.name].default_exit, local.defaults.catalyst_center.fabric.border_devices.default_exit, null)
      import_external_routes          = try(local.border_devices[device.name].import_external_routes, local.defaults.catalyst_center.fabric.border_devices.import_external_routes, null)
      border_priority                 = try(local.border_devices[device.name].border_priority, 10) == 10 ? null : try(local.border_devices[device.name].border_priority, local.defaults.catalyst_center.fabric.border_devices.border_priority, null)
      prepend_autonomous_system_count = try(local.border_devices[device.name].prepend_autonomous_system_count, 0) == 0 ? null : try(local.border_devices[device.name].prepend_autonomous_system_count, local.defaults.catalyst_center.fabric.border_devices.prepend_autonomous_system_count, null)
    }
    if(
      lookup(local.device_name_to_id, device.name, null) != null ||
      lookup(local.device_name_to_id, try(device.fqdn_name, ""), null) != null ||
      lookup(local.device_ip_to_id, device.device_ip, null) != null
    )
  ]

  depends_on = [catalystcenter_device_role.role, catalystcenter_provision_devices.provision_devices, catalystcenter_provision_device.provision_device, catalystcenter_wireless_device_provision.wireless_controller]
}

resource "catalystcenter_fabric_device" "border_device" {
  for_each = { for device in try(local.catalyst_center.inventory.devices, []) : device.name => device if strcontains(device.state, "PROVISION") && contains(try(device.fabric_roles, []), "BORDER_NODE") && contains(local.sites, try(device.fabric_site, "NONE")) && var.use_bulk_api == false }

  network_device_id = coalesce(
    try(lookup(local.device_name_to_id, each.value.name, null), null),
    try(lookup(local.device_name_to_id, each.value.fqdn_name, null), null),
    try(lookup(local.device_ip_to_id, each.value.device_ip, null), null)
  )
  fabric_id = try(catalystcenter_fabric_site.fabric_site[each.value.fabric_site].id, null)
  device_roles = try([
    for fabric_role in try(each.value.fabric_roles, []) : fabric_role if fabric_role != "EMBEDDED_WIRELESS_CONTROLLER_NODE"
  ], local.defaults.catalyst_center.inventory.devices.fabric_roles, null)
  border_types                    = try(local.border_devices[each.key].border_types, local.defaults.catalyst_center.fabric.border_devices.border_types, null)
  local_autonomous_system_number  = try(local.border_devices[each.key].local_autonomous_system_number, local.defaults.catalyst_center.fabric.border_devices.local_autonomous_system_number, null)
  default_exit                    = try(local.border_devices[each.key].default_exit, local.defaults.catalyst_center.fabric.border_devices.default_exit, null)
  import_external_routes          = try(local.border_devices[each.key].import_external_routes, local.defaults.catalyst_center.fabric.border_devices.import_external_routes, null)
  border_priority                 = try(local.border_devices[each.key].border_priority, 10) == 10 ? null : try(local.border_devices[each.key].border_priority, local.defaults.catalyst_center.fabric.border_devices.border_priority, null)
  prepend_autonomous_system_count = try(local.border_devices[each.key].prepend_autonomous_system_count, 0) == 0 ? null : try(local.border_devices[each.key].prepend_autonomous_system_count, local.defaults.catalyst_center.fabric.border_devices.prepend_autonomous_system_count, null)

  depends_on = [catalystcenter_device_role.role, catalystcenter_provision_devices.provision_devices, catalystcenter_provision_device.provision_device]
}

resource "catalystcenter_fabric_device" "wireless_controller" {
  for_each = { for device in try(local.catalyst_center.inventory.devices, []) : device.name => device if strcontains(device.state, "PROVISION") && contains(try(device.fabric_roles, []), "WIRELESS_CONTROLLER_NODE") && var.use_bulk_api == false }

  network_device_id = coalesce(
    try(lookup(local.device_name_to_id, each.value.name, null), null),
    try(lookup(local.device_name_to_id, each.value.fqdn_name, null), null),
    try(lookup(local.device_ip_to_id, each.value.device_ip, null), null)
  )
  fabric_id    = try(catalystcenter_fabric_site.fabric_site[each.value.fabric_site].id, null)
  device_roles = try(each.value.fabric_roles, local.defaults.catalyst_center.inventory.devices.fabric_roles, null)

  depends_on = [catalystcenter_device_role.role, catalystcenter_provision_devices.provision_devices, catalystcenter_provision_device.provision_device, catalystcenter_wireless_device_provision.wireless_controller, catalystcenter_fabric_device.border_device, catalystcenter_fabric_devices.fabric_devices]
}

resource "catalystcenter_fabric_device" "edge_device" {
  for_each = { for device in try(local.catalyst_center.inventory.devices, []) : device.name => device if strcontains(device.state, "PROVISION") && !contains(try(device.fabric_roles, []), "BORDER_NODE") && try(device.fabric_roles, null) != null && contains(try(device.fabric_roles, []), "EDGE_NODE") && contains(local.sites, try(device.fabric_site, "NONE")) && var.use_bulk_api == false }

  network_device_id = coalesce(
    try(lookup(local.device_name_to_id, each.value.name, null), null),
    try(lookup(local.device_name_to_id, each.value.fqdn_name, null), null),
    try(lookup(local.device_ip_to_id, each.value.device_ip, null), null)
  )
  fabric_id = try(catalystcenter_fabric_zone.fabric_zone[each.value.fabric_zone].id, catalystcenter_fabric_site.fabric_site[each.value.fabric_site].id, null)
  device_roles = try([
    for fabric_role in try(each.value.fabric_roles, []) :
    fabric_role == "EMBEDDED_WIRELESS_CONTROLLER_NODE" && try(catalystcenter_fabric_ewlc.ewlc_device[each.key].id, null) != null ?
    "WIRELESS_CONTROLLER_NODE" :
    fabric_role
  ], local.defaults.catalyst_center.inventory.devices.fabric_roles, null)

  lifecycle {
    ignore_changes = [device_roles]
  }

  depends_on = [catalystcenter_device_role.role, catalystcenter_provision_devices.provision_devices, catalystcenter_provision_device.provision_device, catalystcenter_fabric_device.border_device, catalystcenter_fabric_devices.fabric_devices, catalystcenter_fabric_ewlc.ewlc_device]
}

resource "catalystcenter_fabric_ewlc" "ewlc_device" {
  for_each = { for device in try(local.catalyst_center.inventory.devices, []) : device.name => device if strcontains(device.state, "PROVISION") && contains(try(device.fabric_roles, []), "EMBEDDED_WIRELESS_CONTROLLER_NODE") && contains(local.sites, try(device.fabric_site, "NONE")) }

  network_device_id = coalesce(
    try(lookup(local.device_name_to_id, each.value.name, null), null),
    try(lookup(local.device_name_to_id, each.value.fqdn_name, null), null),
    try(lookup(local.device_ip_to_id, each.value.device_ip, null), null)
  )
  fabric_id                 = try(catalystcenter_fabric_zone.fabric_zone[each.value.fabric_zone].id, catalystcenter_fabric_site.fabric_site[each.value.fabric_site].id, null)
  enable_wireless           = try(each.value.enable_wireless, local.defaults.catalyst_center.inventory.devices.enable_wireless, true)
  enable_rolling_ap_upgrade = try(each.value.enable_rolling_ap_upgrade, local.defaults.catalyst_center.inventory.devices.enable_rolling_ap_upgrade, false)
  ap_reboot_percentage      = try(each.value.ap_reboot_percentage, local.defaults.catalyst_center.inventory.devices.ap_reboot_percentage, 25)

  depends_on = [catalystcenter_device_role.role, catalystcenter_provision_devices.provision_devices, catalystcenter_provision_device.provision_device, catalystcenter_fabric_device.border_device, catalystcenter_fabric_devices.fabric_devices, catalystcenter_assign_managed_ap_locations.managed_ap_locations]
}

resource "catalystcenter_fabric_vlan_to_ssid" "vlan_to_ssid" {
  for_each = local.wireless_controllers ? { for site in try(local.catalyst_center.fabric.fabric_sites, []) : site.name => site if((length(keys(catalystcenter_fabric_device.wireless_controller)) > 0 && var.use_bulk_api == false && length(try(site.wireless_ssids, [])) != 0) || (var.use_bulk_api == true && length(try(site.wireless_ssids, [])) != 0)) } : {}

  fabric_id = catalystcenter_fabric_site.fabric_site[each.key].id
  mappings = flatten([
    for vlan in distinct([for ssid in try(each.value.wireless_ssids, []) : ssid.vlan_name]) : {
      vlan_name    = vlan
      ssid_details = [for ssid in each.value.wireless_ssids : { name = ssid.name } if ssid.vlan_name == vlan]
    }
  ])

  depends_on = [catalystcenter_wireless_ssid.ssid, catalystcenter_fabric_l2_virtual_network.l2_vn, catalystcenter_anycast_gateways.anycast_gateways, catalystcenter_anycast_gateway.anycast_gateway, catalystcenter_fabric_devices.fabric_devices, catalystcenter_fabric_device.wireless_controller, catalystcenter_wireless_device_provision.wireless_controller, catalystcenter_wireless_profile.wireless_profile]
}

resource "catalystcenter_fabric_l3_handoff_sda_transit" "sda_transit" {
  for_each = { for device in try(local.catalyst_center.inventory.devices, []) : device.name => device if strcontains(device.state, "PROVISION") && contains(try(device.fabric_roles, []), "BORDER_NODE") && try(local.border_devices[device.name].sda_transit, null) != null && contains(local.sites, try(device.fabric_site, "NONE")) }

  network_device_id = coalesce(
    try(lookup(local.device_name_to_id, each.value.name, null), null),
    try(lookup(local.device_name_to_id, each.value.fqdn_name, null), null),
    try(lookup(local.device_ip_to_id, each.value.device_ip, null), null)
  )
  fabric_id                         = try(catalystcenter_fabric_site.fabric_site[each.value.fabric_site].id, null)
  transit_network_id                = try(catalystcenter_transit_network.transit[local.border_devices[each.key].sda_transit].id, data.catalystcenter_transit_network.transit[local.border_devices[each.key].sda_transit].id, null)
  affinity_id_prime                 = try(local.border_devices[each.key].affinity_id_prime, local.defaults.catalyst_center.fabric.border_devices.affinity_id_prime, null)
  affinity_id_decider               = try(local.border_devices[each.key].affinity_id_decider, local.defaults.catalyst_center.fabric.border_devices.affinity_id_decider, null)
  connected_to_internet             = try(local.border_devices[each.key].connected_to_internet, local.defaults.catalyst_center.fabric.border_devices.connected_to_internet, null)
  is_multicast_over_transit_enabled = try(local.border_devices[each.key].multicast_over_transit, local.defaults.catalyst_center.fabric.border_devices.multicast_over_transit, null)

  depends_on = [catalystcenter_provision_devices.provision_devices, catalystcenter_provision_device.provision_device, catalystcenter_fabric_device.border_device, catalystcenter_fabric_devices.fabric_devices, catalystcenter_transit_network.transit]
}

locals {
  l3_handoffs_ip_transit_by_device = {
    for border_device in try(local.catalyst_center.fabric.border_devices, []) :
    border_device.name => flatten([
      for transit in try(border_device.l3_handoffs, []) : [
        for interface in try(transit.interfaces, []) : [
          for vn in try(interface.virtual_networks, []) : {
            key                   = format("%s/%s/%s/%s", vn.name, interface.name, transit.name, border_device.name)
            transit_name          = try(transit.name, null)
            device_name           = try(border_device.name, null)
            device_ip             = try(local.device_name_to_ip[border_device.name], null)
            interface_name        = try(interface.name, null)
            virtual_network_name  = try(vn.name, null)
            vlan_id               = try(vn.vlan, null)
            local_ip_address      = try(vn.local_ip_address, null)
            local_ipv6_address    = try(vn.local_ipv6_address, null)
            peer_ipv6_address     = try(vn.peer_ipv6_address, null)
            peer_ip_address       = try(vn.peer_ip_address, null)
            tcp_mss_adjustment    = try(vn.tcp_mss_adjustment, null)
            external_handoff_pool = try(border_device.external_handoff_pool, null)
          }
        ]
      ]
    ])
  }
}

resource "catalystcenter_fabric_l3_handoff_ip_transits" "l3_handoff_ip_transits" {
  for_each = { for device in try(local.catalyst_center.inventory.devices, []) : device.name => device if strcontains(device.state, "PROVISION") && contains(try(device.fabric_roles, []), "BORDER_NODE") && length(try(local.l3_handoffs_ip_transit_by_device[device.name], [])) != 0 && contains(local.sites, try(device.fabric_site, "NONE")) }

  fabric_id = try(catalystcenter_fabric_zone.fabric_zone[each.value.fabric_zone].id, catalystcenter_fabric_site.fabric_site[each.value.fabric_site].id, null)
  network_device_id = coalesce(
    try(lookup(local.device_name_to_id, each.value.name, null), null),
    try(lookup(local.device_name_to_id, each.value.fqdn_name, null), null),
    try(lookup(local.device_ip_to_id, each.value.device_ip, null), null)
  )
  l3_handoffs = [for handoff in try(local.l3_handoffs_ip_transit_by_device[each.key], []) :
    {
      fabric_id = try(catalystcenter_fabric_zone.fabric_zone[each.value.fabric_zone].id, catalystcenter_fabric_site.fabric_site[each.value.fabric_site].id, null)
      network_device_id = coalesce(
        try(lookup(local.device_name_to_id, each.value.name, null), null),
        try(lookup(local.device_name_to_id, each.value.fqdn_name, null), null),
        try(lookup(local.device_ip_to_id, each.value.device_ip, null), null)
      )
      transit_network_id                 = try(catalystcenter_transit_network.transit[handoff.transit_name].id, data.catalystcenter_transit_network.transit[handoff.transit_name].id, null)
      interface_name                     = try(handoff.interface_name, null)
      virtual_network_name               = try(handoff.virtual_network_name, null)
      vlan_id                            = try(handoff.vlan_id, null)
      tcp_mss_adjustment                 = try(handoff.tcp_mss_adjustment, null)
      external_connectivity_ip_pool_name = try(handoff.external_handoff_pool, null) != null ? try(handoff.external_handoff_pool, local.defaults.catalyst_center.fabric.border_devices.l3_handoffs.virtual_network.external_handoff_pool, null) : null
      local_ip_address                   = try(handoff.external_handoff_pool, null) == null ? try(handoff.local_ip_address, null) : null
      remote_ip_address                  = try(handoff.external_handoff_pool, null) == null ? try(handoff.peer_ip_address, null) : null
      local_ipv6_address                 = try(handoff.external_handoff_pool, null) == null ? try(handoff.local_ipv6_address, null) : null
      remote_ipv6_address                = try(handoff.external_handoff_pool, null) == null ? try(handoff.peer_ipv6_address, null) : null
    }
  ]

  depends_on = [catalystcenter_fabric_device.border_device, catalystcenter_fabric_devices.fabric_devices, catalystcenter_device_role.role, catalystcenter_fabric_l3_virtual_network.l3_vn, catalystcenter_virtual_network_to_fabric_site.l3_vn_to_fabric_site, catalystcenter_fabric_site.fabric_site, catalystcenter_ip_pool_reservation.pool_reservation]
}

locals {
  l2_handoffs = flatten([
    for border_device in try(local.catalyst_center.fabric.border_devices, []) : [
      for vn in try(border_device.l2_handoffs.l2_with_anycast_gateway, []) : [
        for interface in try(vn.interfaces) : {
          key              = format("vlan%s/%s/%s", vn.external_vlan, border_device.name, interface)
          device_name      = try(border_device.name, null)
          device_ip        = try(local.device_name_to_ip[border_device.name], null)
          interface_name   = try(interface, null)
          external_vlan_id = try(vn.external_vlan, null)
          ip_pool_name     = try(vn.ip_pool_name, null)
          name             = try(vn.l3_virtual_network, null)
        }
      ]
    ]
  ])

  l2_handoff_vlan_id_map = {
    for item in local.anycast_gateways :
    "${item.ip_pool_name}#_#${item.l3_virtual_network}#_#${item.fabric_site_name}" => (
      var.use_bulk_api ?
      try(
        data.catalystcenter_anycast_gateway.created_gateways[item.ip_pool_name].vlan_id,
        one([
          for g in local.anycast_gateways_by_fabric_site[item.fabric_site_name] :
          g.vlan_id
          if g.ip_pool_name == item.ip_pool_name
        ]),
        null
      ) :
      try(
        catalystcenter_anycast_gateway.anycast_gateway[item.ip_pool_name].vlan_id,
        one([
          for g in local.anycast_gateways_by_fabric_site[item.fabric_site_name] :
          g.vlan_id
          if g.ip_pool_name == item.ip_pool_name
        ]),
        null
      )
    )
  }
}

data "catalystcenter_anycast_gateway" "created_gateways" {
  for_each = var.use_bulk_api ? {
    for item in local.anycast_gateways :
    item.ip_pool_name => item
    if contains(local.sites, item.fabric_site_name)
  } : {}

  fabric_id            = catalystcenter_fabric_site.fabric_site[each.value.fabric_site_name].id
  virtual_network_name = try(each.value.l3_virtual_network, local.defaults.catalyst_center.fabric.fabric_sites.anycast_gateways.l3_virtual_network)
  ip_pool_name         = each.value.ip_pool_name

  depends_on = [catalystcenter_anycast_gateways.anycast_gateways]
}


resource "catalystcenter_fabric_l2_handoff" "l2_handoff" {
  for_each = { for handoff in local.l2_handoffs : handoff.key => handoff if strcontains(local.all_devices[handoff.device_name].state, "PROVISION") && contains(local.sites, try(local.all_devices[handoff.device_name].fabric_site, "NONE")) }

  network_device_id = lookup(local.device_ip_to_id, each.value.device_ip, null)
  fabric_id         = try(catalystcenter_fabric_site.fabric_site[local.all_devices[each.value.device_name].fabric_site].id, null)
  interface_name    = try(each.value.interface_name, null)
  internal_vlan_id  = try(local.l2_handoff_vlan_id_map["${each.value.ip_pool_name}#_#${each.value.name}#_#${local.all_devices[each.value.device_name].fabric_site}"], null)
  external_vlan_id  = try(each.value.external_vlan_id, null)

  depends_on = [catalystcenter_fabric_device.border_device, catalystcenter_fabric_devices.fabric_devices, catalystcenter_fabric_l3_virtual_network.l3_vn, catalystcenter_virtual_network_to_fabric_site.l3_vn_to_fabric_site, catalystcenter_fabric_site.fabric_site, catalystcenter_anycast_gateway.anycast_gateway, catalystcenter_anycast_gateways.anycast_gateways, data.catalystcenter_anycast_gateway.created_gateways]

}

locals {
  l2_handoffs_no_anycast = flatten([
    for border_device in try(local.catalyst_center.fabric.border_devices, []) : [
      for vlan in try(border_device.l2_handoffs.l2_without_anycast_gateway.vlans, []) : [
        for interface in try(border_device.l2_handoffs.l2_without_anycast_gateway.interfaces, []) : {
          key              = format("vlan%s/%s/%s", vlan.external_vlan, border_device.name, interface)
          device_name      = try(border_device.name, null)
          device_ip        = try(local.device_name_to_ip[border_device.name], null)
          interface_name   = try(interface, null)
          external_vlan_id = try(vlan.external_vlan, null)
          vlan_name        = try(vlan.name, null)
        }
      ]
    ]
  ])
}

locals {
  l2_handoff_vlan_id_map_no_anycast = {
    for item in local.l2_virtual_networks : "${item.vlan_name}#_#${item.fabric_site_name}" => item.vlan_id if try(item.vlan_name, null) != null
  }
}

resource "catalystcenter_fabric_l2_handoff" "l2_handoff_no_anycast" {
  for_each = { for handoff in local.l2_handoffs_no_anycast : handoff.key => handoff if strcontains(local.all_devices[handoff.device_name].state, "PROVISION") && contains(local.sites, try(local.all_devices[handoff.device_name].fabric_site, "NONE")) }

  network_device_id = lookup(local.device_ip_to_id, each.value.device_ip, null)
  fabric_id         = try(catalystcenter_fabric_site.fabric_site[local.all_devices[each.value.device_name].fabric_site].id, null)
  interface_name    = try(each.value.interface_name, null)
  internal_vlan_id  = try(local.l2_handoff_vlan_id_map_no_anycast["${each.value.vlan_name}#_#${local.all_devices[each.value.device_name].fabric_site}"], null)
  external_vlan_id  = try(each.value.external_vlan_id, null)

  depends_on = [catalystcenter_fabric_device.border_device, catalystcenter_fabric_devices.fabric_devices, catalystcenter_fabric_site.fabric_site, catalystcenter_fabric_l2_virtual_network.l2_vn]
}

# Resolve port assignment interfaces range to interfaces list
locals {
  device_port_assignments = {
    for device in try(local.catalyst_center.inventory.devices, []) : device.name => flatten([
      for assignment in device.port_assignments : (
        try(assignment.interfaces_range, null) != null ? [
          for z in range(
            tonumber(regex("([0-9]+)$", split("-", assignment.interfaces_range)[0])[0]),
            tonumber(regex("([0-9]+)$", split("-", assignment.interfaces_range)[1])[0]) + 1
            ) : {
            interface_name             = format("%s/%s", regex("(^[A-Za-z]+[0-9]+/[0-9]+)", split("-", assignment.interfaces_range)[0])[0], z)
            connected_device_type      = try(assignment.connected_device_type, local.defaults.catalyst_center.inventory.devices.port_assignments.connected_device_type, null)
            data_vlan_name             = try(assignment.data_vlan_name, local.defaults.catalyst_center.inventory.devices.port_assignments.data_vlan_name, null)
            security_group_name        = try(assignment.security_group_name, local.defaults.catalyst_center.inventory.devices.port_assignments.security_group_name, null)
            voice_vlan_name            = try(assignment.voice_vlan_name, local.defaults.catalyst_center.inventory.devices.port_assignments.voice_vlan_name, null)
            authenticate_template_name = try(assignment.authenticate_template_name, local.defaults.catalyst_center.inventory.devices.port_assignments.authenticate_template_name, null)
            interface_description      = try(assignment.interface_description, local.defaults.catalyst_center.inventory.devices.port_assignments.interface_description, null)
            network_device_id = coalesce(
              try(lookup(local.device_name_to_id, device.name, null), null),
              try(lookup(local.device_name_to_id, device.fqdn_name, null), null),
              try(lookup(local.device_ip_to_id, device.device_ip, null), null)
            )
            fabric_id = try(local.fabric_zone_id_list[device.fabric_zone], local.fabric_site_id_list[device.fabric_site], null)
          }
          ] : [
          {
            interface_name             = assignment.interface_name
            connected_device_type      = try(assignment.connected_device_type, local.defaults.catalyst_center.inventory.devices.port_assignments.connected_device_type, null)
            data_vlan_name             = try(assignment.data_vlan_name, local.defaults.catalyst_center.inventory.devices.port_assignments.data_vlan_name, null)
            voice_vlan_name            = try(assignment.voice_vlan_name, local.defaults.catalyst_center.inventory.devices.port_assignments.voice_vlan_name, null)
            security_group_name        = try(assignment.security_group_name, local.defaults.catalyst_center.inventory.devices.port_assignments.security_group_name, null)
            authenticate_template_name = try(assignment.authenticate_template_name, local.defaults.catalyst_center.inventory.devices.port_assignments.authenticate_template_name, null)
            interface_description      = try(assignment.interface_description, local.defaults.catalyst_center.inventory.devices.port_assignments.interface_description, null)
            network_device_id = coalesce(
              try(lookup(local.device_name_to_id, device.name, null), null),
              try(lookup(local.device_name_to_id, device.fqdn_name, null), null),
              try(lookup(local.device_ip_to_id, device.device_ip, null), null)
            )
            fabric_id = try(local.fabric_zone_id_list[device.fabric_zone], local.fabric_site_id_list[device.fabric_site], null)
          }
        ]
      )
    ]) if try(device.port_assignments, null) != null
  }
}

resource "catalystcenter_fabric_port_assignments" "port_assignments" {
  for_each = { for device in try(local.catalyst_center.inventory.devices, []) : device.name => device if strcontains(device.state, "PROVISION") && try(contains(device.fabric_roles, "EDGE_NODE"), null) != null && try(device.port_assignments, null) != null && contains(local.sites, try(device.fabric_site, "NONE")) }

  fabric_id = try(catalystcenter_fabric_zone.fabric_zone[each.value.fabric_zone].id, catalystcenter_fabric_site.fabric_site[each.value.fabric_site].id, null)
  network_device_id = coalesce(
    try(lookup(local.device_name_to_id, each.value.name, null), null),
    try(lookup(local.device_name_to_id, each.value.fqdn_name, null), null),
    try(lookup(local.device_ip_to_id, each.value.device_ip, null), null)
  )
  port_assignments = try(local.device_port_assignments[each.key], null)

  depends_on = [catalystcenter_fabric_device.edge_device, catalystcenter_fabric_device.border_device, catalystcenter_fabric_devices.fabric_devices, catalystcenter_provision_devices.provision_devices, catalystcenter_provision_device.provision_device, catalystcenter_anycast_gateway.anycast_gateway, catalystcenter_anycast_gateways.anycast_gateways]
}


locals {
  fabric_multicast_configs = {
    for fabric_site in try(local.catalyst_center.fabric.fabric_sites, []) :
    fabric_site.name => {
      fabric_site_name = fabric_site.name
      virtual_networks = [
        for vn in try(fabric_site.multicast.virtual_networks, []) : {
          virtual_network_name = try(vn.name, null)
          ip_pool_name         = try(vn.ip_pool_name, null)
          ipv4_ssm_ranges      = try(vn.ipv4_ssm_ranges, [])
          multicast_rps        = try(vn.multicast_rps, [])
        }
      ]
    } if try(fabric_site.multicast, null) != null
  }
}

resource "catalystcenter_fabric_multicast_virtual_networks" "multicast" {
  for_each = {
    for fabric_site, config in local.fabric_multicast_configs :
    fabric_site => config
    if contains(local.sites, fabric_site) && length(config.virtual_networks) > 0
  }

  fabric_id = try(catalystcenter_fabric_site.fabric_site[each.key].id, null)

  virtual_networks = [
    for vn in each.value.virtual_networks : {
      fabric_id            = try(catalystcenter_fabric_site.fabric_site[each.key].id, null)
      virtual_network_name = try(vn.virtual_network_name, null)
      ip_pool_name         = try(vn.ip_pool_name, null)
      ipv4_ssm_ranges      = try(vn.ipv4_ssm_ranges, [])
      multicast_rps = [
        for rp in try(vn.multicast_rps, []) : {
          ipv4_address       = try(rp.ipv4_address, null)
          ipv6_address       = try(rp.ipv6_address, null)
          ipv4_asm_ranges    = try(rp.ipv4_asm_ranges, [])
          ipv6_asm_ranges    = try(rp.ipv6_asm_ranges, [])
          is_default_v4_rp   = try(rp.is_default_v4_rp, null)
          is_default_v6_rp   = try(rp.is_default_v6_rp, null)
          rp_device_location = try(rp.rp_location, null)
          network_device_ids = try(rp.rp_location, "") == "FABRIC" ? [
            for device_name in try(rp.fabric_rps, []) :
            try(local.device_name_to_id[device_name], local.device_name_to_id[local.name_to_fqdn_mapping[device_name]], null)
          ] : []
        }
      ]
    }
  ]

  depends_on = [
    catalystcenter_fabric_site.fabric_site, catalystcenter_fabric_l3_virtual_network.l3_vn, catalystcenter_virtual_network_to_fabric_site.l3_vn_to_fabric_site, catalystcenter_ip_pool_reservation.pool_reservation, catalystcenter_provision_devices.provision_devices, catalystcenter_provision_device.provision_device
  ]
}

locals {
  extranet_policies = flatten([
    for policy in try(local.catalyst_center.fabric.extranet_policies, []) : {
      name                             = try(policy.name, null)
      provider_virtual_network_name    = try(policy.provider_virtual_network, null)
      subscriber_virtual_network_names = try(policy.subscriber_virtual_networks, [])
      fabric_sites                     = try(policy.fabric_sites, [])
      policy_key                       = policy.name
      fabric_ids = length(try(policy.fabric_sites, [])) > 0 ? [
        for site in try(policy.fabric_sites, []) :
        try(catalystcenter_fabric_site.fabric_site[site].id, null)
        if contains(local.sites, site)
        ] : (
        var.manage_global_settings ? null : flatten([
          for fabric_site in try(local.catalyst_center.fabric.fabric_sites, []) :
          contains(local.sites, fabric_site.name) ? try(catalystcenter_fabric_site.fabric_site[fabric_site.name].id, null) : null
        ])
      )
    }
  ])
}

resource "catalystcenter_extranet_policy" "extranet_policy" {
  for_each = {
    for policy in local.extranet_policies : policy.policy_key => policy
    if try(policy.name, null) != null &&
    try(policy.provider_virtual_network_name, null) != null &&
    length(try(policy.subscriber_virtual_network_names, [])) > 0 &&
    !var.manage_global_settings &&
    (length(try(policy.fabric_sites, [])) == 0 ||
    length([for site in try(policy.fabric_sites, []) : site if contains(local.sites, site)]) > 0)
  }

  extranet_policy_name             = each.value.name
  provider_virtual_network_name    = each.value.provider_virtual_network_name
  subscriber_virtual_network_names = toset(each.value.subscriber_virtual_network_names)
  fabric_ids                       = try(each.value.fabric_ids, null) != null ? toset(compact(each.value.fabric_ids)) : null

  depends_on = [catalystcenter_fabric_site.fabric_site, catalystcenter_fabric_l3_virtual_network.l3_vn, catalystcenter_virtual_network_to_fabric_site.l3_vn_to_fabric_site, catalystcenter_fabric_l3_virtual_network.global_l3_vn]
}
