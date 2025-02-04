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

  l3_virtual_networks = flatten([
    for fabric_site in try(local.catalyst_center.fabric.fabric_sites, []) : [
      for vn in try(fabric_site.l3_virtual_networks, []) : {
        "name" : try(vn.name, null)
        "fabric_site_name" : try(fabric_site.name, null)
      }
    ]
  ])
}

resource "catalystcenter_transit_network" "transit" {
  for_each                          = { for transit in try(local.catalyst_center.fabric.transits, []) : transit.name => transit }
  name                              = each.key
  type                              = try(each.value.type, local.defaults.catalyst_center.fabric.transits.type, null)
  routing_protocol_name             = try(each.value.routing_protocol_name, local.defaults.catalyst_center.fabric.transits.routing_protocol_name, null)
  autonomous_system_number          = try(each.value.autonomous_system_number, local.defaults.catalyst_center.fabric.transits.autonomous_system_number, null)
  is_multicast_over_transit_enabled = try(each.value.is_multicast_over_transit_enabled, local.defaults.catalyst_center.fabric.transits.is_multicast_over_transit_enabled, null)
  control_plane_network_device_ids  = try(each.value.control_plane_network_device_ids, local.defaults.catalyst_center.fabric.transits.control_plane_network_device_ids, null)
}

resource "catalystcenter_fabric_site" "fabric_site" {
  for_each = { for site in try(local.catalyst_center.fabric.fabric_sites, []) : site.name => site }

  authentication_profile_name = try(each.value.authentication_template_name, local.defaults.catalyst_center.fabric.fabric_sites.authentication_template_name, null)
  site_id                     = try(local.site_id_list[each.key], each.key, null)
  pub_sub_enabled             = try(each.value.pub_sub_enabled, local.defaults.catalyst_center.fabric.fabric_sites.pub_sub_enabled, null)

  depends_on = [catalystcenter_floor.floor, catalystcenter_building.building, catalystcenter_area.area_0, catalystcenter_area.area_1, catalystcenter_area.area_2, catalystcenter_network.network_settings]
}

locals {
  fabric_site_id_list = { for k, v in catalystcenter_fabric_site.fabric_site : k => v.id }
}

resource "catalystcenter_fabric_virtual_network" "vn" {
  for_each = { for vn in try(local.l3_virtual_networks, []) : vn.name => vn if vn.name != "INFRA_VN" }

  virtual_network_name = each.key
  is_guest             = try(each.value.is_guest, local.defaults.catalyst_center.fabric.fabric_sites.l3_virtual_networks.is_guest, null)
  sg_names             = try(each.value.sg_names, local.defaults.catalyst_center.fabric.fabric_sites.l3_virtual_networks.sg_names, null)

  depends_on = [catalystcenter_ip_pool_reservation.pool_reservation]
}

resource "catalystcenter_fabric_l2_virtual_network" "l2_vn" {
  for_each = { for vn in try(local.l2_virtual_networks, []) : vn.name => vn }

  fabric_id                          = catalystcenter_fabric_site.fabric_site[each.value.fabric_site_name].id
  vlan_name                          = try(each.value.vlan_name, local.defaults.catalyst_center.fabric.fabric_sites.l2_virtual_networks.vlan_name, null)
  vlan_id                            = try(each.value.vlan_id, local.defaults.catalyst_center.fabric.fabric_sites.l2_virtual_networks.vlan_id, null)
  traffic_type                       = try(each.value.traffic_type, local.defaults.catalyst_center.fabric.fabric_sites.l2_virtual_networks.traffic_type, null)
  fabric_enabled_wireless            = try(each.value.fabric_enabled_wireless, local.defaults.catalyst_center.fabric.fabric_sites.l2_virtual_networks.fabric_enabled_wireless, null)
  associated_l3_virtual_network_name = try(each.value.associated_l3_virtual_network_name, local.defaults.catalyst_center.fabric.fabric_sites.l2_virtual_networks.associated_l3_virtual_network_name, null)

  depends_on = [catalystcenter_virtual_network_to_fabric_site.vn_to_fabric_site]
}

resource "catalystcenter_virtual_network_to_fabric_site" "vn_to_fabric_site" {
  for_each = { for vn in try(local.l3_virtual_networks, []) : "${vn.name}/${vn.fabric_site_name}" => vn }

  site_name_hierarchy  = try(each.value.fabric_site_name, null)
  virtual_network_name = try(catalystcenter_fabric_virtual_network.vn[each.value.name].virtual_network_name, "INFRA_VN", null)

  depends_on = [catalystcenter_ip_pool_reservation.pool_reservation, catalystcenter_fabric_site.fabric_site, catalystcenter_fabric_virtual_network.vn]
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

  depends_on = [catalystcenter_ip_pool_reservation.pool_reservation, catalystcenter_fabric_site.fabric_site, catalystcenter_virtual_network_to_fabric_site.vn_to_fabric_site]
}

