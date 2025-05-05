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

  l3_virtual_networks = {
    for vn in flatten([
      for fabric_site in try(local.catalyst_center.fabric.fabric_sites, []) : [
        for vn in try(fabric_site.l3_virtual_networks, []) : {
          name             = vn.name
          fabric_site_name = fabric_site.name
        }
      ]
    ]) : vn.name => vn.fabric_site_name...
  }
}

resource "catalystcenter_transit_network" "transit" {
  for_each = { for transit in try(local.catalyst_center.fabric.transits, []) : transit.name => transit }

  name                              = each.key
  type                              = try(each.value.type, local.defaults.catalyst_center.fabric.transits.type, null)
  routing_protocol_name             = try(each.value.type, "") == "IP_BASED_TRANSIT" ? try(each.value.routing_protocol_name, local.defaults.catalyst_center.fabric.transits.routing_protocol_name, null) : null
  autonomous_system_number          = try(each.value.type, "") == "IP_BASED_TRANSIT" ? try(each.value.autonomous_system_number, local.defaults.catalyst_center.fabric.transits.autonomous_system_number, null) : null
  is_multicast_over_transit_enabled = try(each.value.type, "") != "IP_BASED_TRANSIT" ? try(each.value.multicast_over_sda_transit, local.defaults.catalyst_center.fabric.transits.multicast_over_sda_transit, null) : null
  control_plane_network_device_ids  = try(each.value.type, "") != "IP_BASED_TRANSIT" ? [for device in try(each.value.control_plane_devices, []) : try(local.device_name_to_id[device], null)] : null
}

resource "catalystcenter_fabric_site" "fabric_site" {
  for_each = { for site in try(local.catalyst_center.fabric.fabric_sites, []) : site.name => site }

  authentication_profile_name = try(each.value.authentication_template_name, local.defaults.catalyst_center.fabric.fabric_sites.authentication_template_name, null)
  site_id                     = try(local.site_id_list[each.key], each.key, null)
  pub_sub_enabled             = try(each.value.pub_sub_enabled, local.defaults.catalyst_center.fabric.fabric_sites.pub_sub_enabled, null)

  depends_on = [catalystcenter_floor.floor, catalystcenter_building.building, catalystcenter_area.area_0, catalystcenter_area.area_1, catalystcenter_area.area_2, catalystcenter_telemetry_settings.telemetry_settings]
}

locals {
  fabric_site_id_list = { for k, v in catalystcenter_fabric_site.fabric_site : k => v.id }
}

resource "catalystcenter_fabric_l3_virtual_network" "l3_vn" {
  for_each = { for vn_name, site_names in try(local.l3_virtual_networks, {}) : vn_name => site_names if vn_name != "INFRA_VN" }

  virtual_network_name = each.key
  fabric_ids           = [for site in each.value : catalystcenter_fabric_site.fabric_site[site].id]

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
  for_each = { for anycast_gateway in local.anycast_gateways : anycast_gateway.name => anycast_gateway }

  fabric_id                                 = catalystcenter_fabric_site.fabric_site[each.value.fabric_site_name].id
  virtual_network_name                      = try(each.value.l3_virtual_network, local.defaults.catalyst_center.fabric.fabric_sites.anycast_gateways.l3_virtual_network, null)
  ip_pool_name                              = try(each.value.ip_pool_name, each.key, null)
  vlan_name                                 = try(each.value.vlan_name, local.defaults.catalyst_center.fabric.fabric_sites.anycast_gateways.vlan_name, null)
  vlan_id                                   = try(each.value.vlan_id, local.defaults.catalyst_center.fabric.fabric_sites.anycast_gateways.vlan_id, null)
  traffic_type                              = try(each.value.traffic_type, local.defaults.catalyst_center.fabric.fabric_sites.anycast_gateways.traffic_type, null)
  critical_pool                             = lookup(each.value, "pool_type", "") == "FABRIC_AP" ? null : try(each.value.critical_pool, local.defaults.catalyst_center.fabric.fabric_sites.anycast_gateways.critical_pool, null)
  intra_subnet_routing_enabled              = lookup(each.value, "pool_type", "") == "FABRIC_AP" ? null : try(each.value.intra_subnet_routing_enabled, local.defaults.catalyst_center.fabric.fabric_sites.anycast_gateways.intra_subnet_routing_enabled, null)
  ip_directed_broadcast                     = lookup(each.value, "pool_type", "") == "FABRIC_AP" ? null : try(each.value.ip_directed_broadcast, local.defaults.catalyst_center.fabric.fabric_sites.anycast_gateways.ip_directed_broadcast, null)
  l2_flooding_enabled                       = lookup(each.value, "pool_type", "") == "FABRIC_AP" ? null : try(each.value.layer2_flooding, local.defaults.catalyst_center.fabric.fabric_sites.anycast_gateways.layer2_flooding, null)
  multiple_ip_to_mac_addresses              = lookup(each.value, "pool_type", "") == "FABRIC_AP" ? null : try(each.value.multiple_ip_to_mac_addresses, local.defaults.catalyst_center.fabric.fabric_sites.anycast_gateways.multiple_ip_to_mac_addresses, null)
  wireless_pool                             = lookup(each.value, "pool_type", "") == "FABRIC_AP" ? null : try(each.value.wireless_pool, local.defaults.catalyst_center.fabric.fabric_sites.anycast_gateways.wireless_pool, null)
  auto_generate_vlan_name                   = try(each.value.auto_generate_vlan_name, local.defaults.catalyst_center.fabric.fabric_sites.anycast_gateways.auto_generate_vlan_name, null)
  pool_type                                 = try(each.value.pool_type, local.defaults.catalyst_center.fabric.fabric_sites.anycast_gateways.pool_type, null)
  security_group_name                       = try(each.value.security_group_name, local.defaults.catalyst_center.fabric.fabric_sites.anycast_gateways.security_group_name, null)
  supplicant_based_extended_node_onboarding = try(each.value.supplicant_based_extended_node_onboarding, local.defaults.catalyst_center.fabric.fabric_sites.anycast_gateways.supplicant_based_extended_node_onboarding, null)
  tcp_mss_adjustment                        = try(each.value.tcp_mss_adjustment, local.defaults.catalyst_center.fabric.fabric_sites.anycast_gateways.tcp_mss_adjustment, null)

  depends_on = [catalystcenter_ip_pool_reservation.pool_reservation, catalystcenter_fabric_site.fabric_site, catalystcenter_fabric_l3_virtual_network.l3_vn]
}

resource "catalystcenter_fabric_vlan_to_ssid" "vlan_to_ssid" {
  for_each = local.wireless_controllers ? { for site in try(local.catalyst_center.fabric.fabric_sites, []) : site.name => site if length(keys(catalystcenter_fabric_device.wireless_controller)) > 0 } : {}

  fabric_id = catalystcenter_fabric_site.fabric_site[each.key].id
  mappings = flatten([
    for vlan in distinct([for ssid in each.value.wireless_ssids : ssid.vlan_name]) : {
      vlan_name    = vlan
      ssid_details = [for ssid in each.value.wireless_ssids : { name = ssid.name } if ssid.vlan_name == vlan]
    }
  ])

  depends_on = [catalystcenter_wireless_ssid.ssid, catalystcenter_fabric_l2_virtual_network.l2_vn, catalystcenter_fabric_device.wireless_controller, catalystcenter_wireless_device_provision.wireless_controller]
}
