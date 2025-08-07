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

  l3_virtual_networks = {
    for key in keys(local.l3_virtual_networks_fabric_site) : key => concat(
      try(local.l3_virtual_networks_fabric_site[key], []),
      try(local.l3_virtual_networks_fabric_zone[key], [])
    )
  }

  global_l3_virtual_networks = {
    for vn in try(local.catalyst_center.fabric.l3_virtual_networks, []) : vn.name => []
  }

  device_name_to_id = try({
    for device in data.catalystcenter_network_devices.all_devices.devices : device.hostname => device.id
  }, {})
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
    ])
  }

  name                              = each.key
  type                              = try(each.value.type, local.defaults.catalyst_center.fabric.transits.type, null)
  routing_protocol_name             = try(each.value.type, "") == "IP_BASED_TRANSIT" ? try(each.value.routing_protocol_name, local.defaults.catalyst_center.fabric.transits.routing_protocol_name, null) : null
  autonomous_system_number          = try(each.value.type, "") == "IP_BASED_TRANSIT" ? try(each.value.autonomous_system_number, local.defaults.catalyst_center.fabric.transits.autonomous_system_number, null) : null
  is_multicast_over_transit_enabled = try(each.value.type, "") != "IP_BASED_TRANSIT" ? try(each.value.multicast_over_sda_transit, local.defaults.catalyst_center.fabric.transits.multicast_over_sda_transit, null) : null
  control_plane_network_device_ids  = try(each.value.type, "") != "IP_BASED_TRANSIT" ? [for device in try(each.value.control_plane_devices, []) : try(local.device_name_to_id[device], null)] : null

  depends_on = [catalystcenter_fabric_provision_device.provision_device]
}

resource "catalystcenter_fabric_site" "fabric_site" {
  for_each = { for site in try(local.catalyst_center.fabric.fabric_sites, []) : site.name => site if contains(local.sites, site.name) }

  authentication_profile_name = try(each.value.authentication_template.name, local.defaults.catalyst_center.fabric.fabric_sites.authentication_template.name, null)
  site_id                     = try(local.site_id_list[each.key], each.key, null)
  pub_sub_enabled             = try(each.value.pub_sub_enabled, local.defaults.catalyst_center.fabric.fabric_sites.pub_sub_enabled, null)

  depends_on = [catalystcenter_floor.floor, catalystcenter_building.building, catalystcenter_area.area_0, catalystcenter_area.area_1, catalystcenter_area.area_2, catalystcenter_area.area_3, catalystcenter_telemetry_settings.telemetry_settings, catalystcenter_aaa_settings.aaa_servers]
}

locals {
  fabric_zones = flatten([
    for fabric_site in try(local.catalyst_center.fabric.fabric_sites, []) : [
      for fabric_zone in try(fabric_site.fabric_zones, []) : fabric_zone
    ]
  ])
}

resource "catalystcenter_fabric_zone" "fabric_zone" {
  for_each = { for zone in try(local.fabric_zones, []) : zone.name => zone }

  authentication_profile_name = try(each.value.authentication_template.name, local.defaults.catalyst_center.fabric.fabric_sites.authentication_template.name, null)
  site_id                     = try(local.site_id_list[each.key], each.key, null)

  depends_on = [catalystcenter_fabric_site.fabric_site]
}

data "catalystcenter_fabric_sites" "fabric_sites" {
}

locals {
  fabric_zone_id_list             = { for k, v in catalystcenter_fabric_zone.fabric_zone : k => v.id }
  fabric_site_id_list             = { for k, v in catalystcenter_fabric_site.fabric_site : k => v.id }
  data_source_fabric_site_id_list = try({ for site in data.catalystcenter_fabric_sites.fabric_sites.sites : site.site_id => site.id }, {})
}

resource "catalystcenter_fabric_l3_virtual_network" "l3_vn" {
  for_each = var.manage_global_settings ? (length(local.l3_virtual_networks) > 0 ? local.l3_virtual_networks_fabric_site : local.global_l3_virtual_networks) : {}

  virtual_network_name = each.key
  fabric_ids = try([
    for site in each.value : (
      contains(keys(catalystcenter_fabric_site.fabric_site), site)
      ? catalystcenter_fabric_site.fabric_site[site].id
      : contains(keys(catalystcenter_fabric_zone.fabric_zone), site)
      ? catalystcenter_fabric_zone.fabric_zone[site].id
      : try(local.data_source_fabric_site_id_list[local.data_source_site_list[site]], "DSD")
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
  for_each = { for vn in try(local.l2_virtual_networks, []) : "${vn.name}#_#${vn.fabric_site_name}" => vn }

  fabric_id                          = catalystcenter_fabric_site.fabric_site[each.value.fabric_site_name].id
  vlan_name                          = try(each.value.vlan_name, local.defaults.catalyst_center.fabric.fabric_sites.l2_virtual_networks.vlan_name, null)
  vlan_id                            = try(each.value.vlan_id, local.defaults.catalyst_center.fabric.fabric_sites.l2_virtual_networks.vlan_id, null)
  traffic_type                       = try(each.value.traffic_type, local.defaults.catalyst_center.fabric.fabric_sites.l2_virtual_networks.traffic_type, null)
  fabric_enabled_wireless            = try(each.value.fabric_enabled_wireless, local.defaults.catalyst_center.fabric.fabric_sites.l2_virtual_networks.fabric_enabled_wireless, null)
  associated_l3_virtual_network_name = try(each.value.associated_l3_virtual_network_name, local.defaults.catalyst_center.fabric.fabric_sites.l2_virtual_networks.associated_l3_virtual_network_name, null)

  depends_on = [catalystcenter_fabric_l3_virtual_network.l3_vn]
}

resource "catalystcenter_anycast_gateway" "anycast_gateway" {
  for_each = { for anycast_gateway in local.anycast_gateways : anycast_gateway.name => anycast_gateway if contains(local.sites, anycast_gateway.fabric_site_name) }

  fabric_id                                 = catalystcenter_fabric_site.fabric_site[each.value.fabric_site_name].id
  virtual_network_name                      = try(each.value.l3_virtual_network, local.defaults.catalyst_center.fabric.fabric_sites.anycast_gateways.l3_virtual_network, null)
  ip_pool_name                              = try(each.value.ip_pool_name, each.key, null)
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

  depends_on = [catalystcenter_ip_pool_reservation.pool_reservation, catalystcenter_fabric_site.fabric_site, catalystcenter_fabric_l3_virtual_network.l3_vn]
}

locals {
  border_devices = { for device in try(local.catalyst_center.fabric.border_devices, []) : device.name => device }
}

resource "catalystcenter_fabric_device" "border_device" {
  for_each = { for device in try(local.catalyst_center.inventory.devices, []) : device.name => device if strcontains(device.state, "PROVISION") && contains(try(device.fabric_roles, []), "BORDER_NODE") && contains(local.sites, try(device.fabric_site, "NONE")) }

  network_device_id               = lookup(local.device_ip_to_id, each.value.device_ip, "")
  fabric_id                       = try(catalystcenter_fabric_site.fabric_site[each.value.fabric_site].id, null)
  device_roles                    = try(each.value.fabric_roles, local.defaults.catalyst_center.inventory.devices.fabric_roles, null)
  border_types                    = try(local.border_devices[each.key].border_types, local.defaults.catalyst_center.fabric.border_devices.border_types, null)
  local_autonomous_system_number  = try(local.border_devices[each.key].local_autonomous_system_number, local.defaults.catalyst_center.fabric.border_devices.local_autonomous_system_number, null)
  default_exit                    = try(local.border_devices[each.key].default_exit, local.defaults.catalyst_center.fabric.border_devices.default_exit, null)
  import_external_routes          = try(local.border_devices[each.key].import_external_routes, local.defaults.catalyst_center.fabric.border_devices.import_external_routes, null)
  border_priority                 = try(local.border_devices[each.key].border_priority, local.defaults.catalyst_center.fabric.border_devices.border_priority, null)
  prepend_autonomous_system_count = try(local.border_devices[each.key].prepend_autonomous_system_count, local.defaults.catalyst_center.fabric.border_devices.prepend_autonomous_system_count, null)

  depends_on = [catalystcenter_device_role.role, catalystcenter_fabric_provision_device.provision_device]
}

resource "catalystcenter_fabric_device" "wireless_controller" {
  for_each = { for device in try(local.catalyst_center.inventory.devices, []) : device.name => device if strcontains(device.state, "PROVISION") && contains(try(device.fabric_roles, []), "WIRELESS_CONTROLLER_NODE") }

  network_device_id = lookup(local.device_ip_to_id, each.value.device_ip, "")
  fabric_id         = try(catalystcenter_fabric_site.fabric_site[each.value.fabric_site].id, null)
  device_roles      = try(each.value.fabric_roles, local.defaults.catalyst_center.inventory.devices.fabric_roles, null)

  depends_on = [catalystcenter_device_role.role, catalystcenter_fabric_provision_device.provision_device, catalystcenter_wireless_device_provision.wireless_controller]
}

resource "catalystcenter_fabric_device" "edge_device" {
  for_each = { for device in try(local.catalyst_center.inventory.devices, []) : device.name => device if strcontains(device.state, "PROVISION") && !contains(try(device.fabric_roles, []), "BORDER_NODE") && try(device.fabric_roles, null) != null && contains(try(device.fabric_roles, []), "EDGE_NODE") && contains(local.sites, try(device.fabric_site, "NONE")) }

  network_device_id = try(local.device_ip_to_id[each.value.device_ip], "")
  fabric_id         = try(catalystcenter_fabric_zone.fabric_zone[each.value.fabric_zone].id, catalystcenter_fabric_site.fabric_site[each.value.fabric_site].id, null)
  device_roles      = try(each.value.fabric_roles, local.defaults.catalyst_center.inventory.devices.fabric_roles, null)

  depends_on = [catalystcenter_device_role.role, catalystcenter_fabric_provision_device.provision_device, catalystcenter_fabric_device.border_device]
}

resource "catalystcenter_fabric_vlan_to_ssid" "vlan_to_ssid" {
  for_each = local.wireless_controllers ? { for site in try(local.catalyst_center.fabric.fabric_sites, []) : site.name => site if length(keys(catalystcenter_fabric_device.wireless_controller)) > 0 && length(try(site.wireless_ssids, [])) != 0 } : {}

  fabric_id = catalystcenter_fabric_site.fabric_site[each.key].id
  mappings = flatten([
    for vlan in distinct([for ssid in try(each.value.wireless_ssids, []) : ssid.vlan_name]) : {
      vlan_name    = vlan
      ssid_details = [for ssid in each.value.wireless_ssids : { name = ssid.name } if ssid.vlan_name == vlan]
    }
  ])

  depends_on = [catalystcenter_wireless_ssid.ssid, catalystcenter_fabric_l2_virtual_network.l2_vn, catalystcenter_anycast_gateway.anycast_gateway, catalystcenter_fabric_device.wireless_controller, catalystcenter_wireless_device_provision.wireless_controller, catalystcenter_wireless_profile.wireless_profile]
}

resource "catalystcenter_fabric_l3_handoff_sda_transit" "sda_transit" {
  for_each = { for device in try(local.catalyst_center.inventory.devices, []) : device.name => device if strcontains(device.state, "PROVISION") && contains(try(device.fabric_roles, []), "BORDER_NODE") && try(local.border_devices[device.name].sda_transit, null) != null && contains(local.sites, try(device.fabric_site, "NONE")) }

  network_device_id                 = lookup(local.device_ip_to_id, each.value.device_ip, "")
  fabric_id                         = try(catalystcenter_fabric_site.fabric_site[each.value.fabric_site].id, null)
  transit_network_id                = try(catalystcenter_transit_network.transit[local.border_devices[each.key].sda_transit].id, data.catalystcenter_transit_network.transit[local.border_devices[each.key].sda_transit].id, null)
  affinity_id_prime                 = try(local.border_devices[each.key].affinity_id_prime, local.defaults.catalyst_center.fabric.border_devices.affinity_id_prime, null)
  affinity_id_decider               = try(local.border_devices[each.key].affinity_id_decider, local.defaults.catalyst_center.fabric.border_devices.affinity_id_decider, null)
  connected_to_internet             = try(local.border_devices[each.key].connected_to_internet, local.defaults.catalyst_center.fabric.border_devices.connected_to_internet, null)
  is_multicast_over_transit_enabled = try(local.border_devices[each.key].multicast_over_transit, local.defaults.catalyst_center.fabric.border_devices.multicast_over_transit, null)

  depends_on = [catalystcenter_fabric_provision_device.provision_device, catalystcenter_fabric_device.border_device, catalystcenter_transit_network.transit]
}

locals {
  l3_handoffs_ip_transit = flatten([
    for border_device in try(local.catalyst_center.fabric.border_devices, []) : [
      for transit in try(border_device.l3_handoffs, []) : [
        for interface in try(transit.interfaces, []) : [
          for vn in try(interface.virtual_networks) : {
            key                   = format("%s/%s/%s/%s", vn.name, interface.name, transit.name, border_device.name)
            transit_name          = try(transit.name, null)
            device_name           = try(border_device.name, null)
            device_ip             = try(local.all_devices[border_device.name].device_ip, null)
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
    ]
  ])
}

resource "catalystcenter_fabric_l3_handoff_ip_transit" "l3_handoff_ip_transit" {
  for_each = { for handoff in local.l3_handoffs_ip_transit : handoff.key => handoff if strcontains(local.all_devices[handoff.device_name].state, "PROVISION") && try(local.all_devices[handoff.device_name].fabric_roles, null) != null && contains(local.sites, try(local.all_devices[handoff.device_name].fabric_site, "NONE")) }

  network_device_id                  = lookup(local.device_ip_to_id, each.value.device_ip, "")
  fabric_id                          = try(catalystcenter_fabric_site.fabric_site[local.all_devices[each.value.device_name].fabric_site].id, null)
  transit_network_id                 = try(catalystcenter_transit_network.transit[each.value.transit_name].id, data.catalystcenter_transit_network.transit[each.value.transit_name].id, null)
  interface_name                     = try(each.value.interface_name, null)
  virtual_network_name               = try(each.value.virtual_network_name, null)
  vlan_id                            = try(each.value.vlan_id, null)
  tcp_mss_adjustment                 = try(each.value.tcp_mss_adjustment, null)
  external_connectivity_ip_pool_name = try(each.value.external_handoff_pool, null) != null ? try(each.value.external_handoff_pool, local.defaults.catalyst_center.fabric.border_devices.l3_handoffs.virtual_network.external_handoff_pool, null) : null
  local_ip_address                   = try(each.value.external_handoff_pool, null) == null ? try(each.value.local_ip_address, null) : null
  remote_ip_address                  = try(each.value.external_handoff_pool, null) == null ? try(each.value.peer_ip_address, null) : null
  local_ipv6_address                 = try(each.value.external_handoff_pool, null) == null ? try(each.value.local_ipv6_address, null) : null
  remote_ipv6_address                = try(each.value.external_handoff_pool, null) == null ? try(each.value.peer_ipv6_address, null) : null

  depends_on = [catalystcenter_fabric_device.border_device, catalystcenter_device_role.role, catalystcenter_fabric_l3_virtual_network.l3_vn, catalystcenter_fabric_site.fabric_site, catalystcenter_ip_pool_reservation.pool_reservation]
}

locals {
  l2_handoffs = flatten([
    for border_device in try(local.catalyst_center.fabric.border_devices, []) : [
      for vn in try(border_device.l2_handoffs.l2_with_anycast_gateway, []) : [
        for interface in try(vn.interfaces) : {
          key              = format("vlan%s/%s/%s", vn.external_vlan, border_device.name, interface)
          device_name      = try(border_device.name, null)
          device_ip        = try(local.all_devices[border_device.name].device_ip, null)
          interface_name   = try(interface, null)
          external_vlan_id = try(vn.external_vlan, null)
          name             = try(vn.name, null)
        }
      ]
    ]
  ])

  l2_handoff_vlan_id_map = {
    for item in local.anycast_gateways : "${item.name}#_#${item.l3_virtual_network}#_#${item.fabric_site_name}" => try(catalystcenter_anycast_gateway.anycast_gateway[item.name].vlan_id, null)
  }
}

resource "catalystcenter_fabric_l2_handoff" "l2_handoff" {
  for_each = { for handoff in local.l2_handoffs : handoff.key => handoff if strcontains(local.all_devices[handoff.device_name].state, "PROVISION") && contains(local.sites, try(local.all_devices[handoff.device_name].fabric_site, "NONE")) }

  network_device_id = lookup(local.device_ip_to_id, each.value.device_ip, "")
  fabric_id         = try(catalystcenter_fabric_site.fabric_site[local.all_devices[each.value.device_name].fabric_site].id, null)
  interface_name    = try(each.value.interface_name, null)
  internal_vlan_id  = try(local.l2_handoff_vlan_id_map["${each.value.name}#_#${local.all_devices[each.value.device_name].fabric_site}"], null)
  external_vlan_id  = try(each.value.external_vlan_id, null)

  depends_on = [catalystcenter_fabric_device.border_device, catalystcenter_fabric_l3_virtual_network.l3_vn, catalystcenter_fabric_site.fabric_site]
}

locals {
  l2_handoffs_no_anycast = flatten([
    for border_device in try(local.catalyst_center.fabric.border_devices, []) : [
      for vlan in try(border_device.l2_handoffs.l2_without_anycast_gateway.vlans, []) : [
        for interface in try(border_device.l2_handoffs.l2_without_anycast_gateway.interfaces, []) : {
          key              = format("vlan%s/%s/%s", vlan.external_vlan, border_device.name, interface)
          device_name      = try(border_device.name, null)
          device_ip        = try(local.all_devices[border_device.name].device_ip, null)
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

  network_device_id = lookup(local.device_ip_to_id, each.value.device_ip, "")
  fabric_id         = try(catalystcenter_fabric_site.fabric_site[local.all_devices[each.value.device_name].fabric_site].id, null)
  interface_name    = try(each.value.interface_name, null)
  internal_vlan_id  = try(local.l2_handoff_vlan_id_map_no_anycast["${each.value.vlan_name}#_#${local.all_devices[each.value.device_name].fabric_site}"], null)
  external_vlan_id  = try(each.value.external_vlan_id, null)

  depends_on = [catalystcenter_fabric_device.border_device, catalystcenter_fabric_site.fabric_site, catalystcenter_fabric_l2_virtual_network.l2_vn]
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
            network_device_id          = try(local.device_ip_to_id[device.device_ip], "")
            fabric_id                  = try(local.fabric_zone_id_list[device.fabric_zone], local.fabric_site_id_list[device.fabric_site], null)
          }
          ] : [
          {
            interface_name             = assignment.interface_name
            connected_device_type      = try(assignment.connected_device_type, local.defaults.catalyst_center.inventory.devices.port_assignments.connected_device_type, null)
            data_vlan_name             = try(assignment.data_vlan_name, local.defaults.catalyst_center.inventory.devices.port_assignments.data_vlan_name, null)
            voice_vlan_name            = try(assignment.voice_vlan_name, local.defaults.catalyst_center.inventory.devices.port_assignments.voice_vlan_name, null)
            security_group_name        = try(assignment.security_group_name, local.defaults.catalyst_center.inventory.devices.port_assignments.security_group_name, null)
            authenticate_template_name = try(assignment.authenticate_template_name, local.defaults.catalyst_center.inventory.devices.port_assignments.authenticate_template_name, null)
            network_device_id          = try(local.device_ip_to_id[device.device_ip], "")
            fabric_id                  = try(local.fabric_zone_id_list[device.fabric_zone], local.fabric_site_id_list[device.fabric_site], null)
          }
        ]
      )
    ]) if try(device.port_assignments, null) != null
  }
}

resource "catalystcenter_fabric_port_assignments" "port_assignments" {
  for_each = { for device in try(local.catalyst_center.inventory.devices, []) : device.name => device if strcontains(device.state, "PROVISION") && try(contains(device.fabric_roles, "EDGE_NODE"), null) != null && try(device.port_assignments, null) != null && contains(local.sites, try(device.fabric_site, "NONE")) }

  fabric_id         = try(catalystcenter_fabric_zone.fabric_zone[each.value.fabric_zone].id, catalystcenter_fabric_site.fabric_site[each.value.fabric_site].id, null)
  network_device_id = try(local.device_ip_to_id[each.value.device_ip], "")
  port_assignments  = try(local.device_port_assignments[each.key], null)

  depends_on = [catalystcenter_fabric_device.edge_device, catalystcenter_fabric_device.border_device, catalystcenter_fabric_provision_device.provision_device, catalystcenter_anycast_gateway.anycast_gateway]
}