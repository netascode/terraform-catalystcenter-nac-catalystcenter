resource "catalystcenter_lan_automation" "lanauto_link" {
  for_each = { for lanauto in try(local.catalyst_center.lan_automation, []) : lanauto.name => lanauto if lanauto.type == "link" && lanauto.status == "START" }

  discovered_device_site_name_hierarchy = try(each.value.discovered_device_site_name_hierarchy, local.defaults.catalyst_center.lan_automation.discovered_device_site_name_hierarchy, null)
  primary_device_management_ip_address  = try(each.value.primary_device_management_ip_address, local.defaults.catalyst_center.lan_automation.primary_device_management_ip_address, null)
  peer_device_management_ip_address     = try(each.value.secondary_device_management_ip_address, local.defaults.catalyst_center.lan_automation.secondary_device_management_ip_address, null)
  primary_device_interface_names        = try(each.value.primary_device_interface_names, local.defaults.catalyst_center.lan_automation.primary_device_interface_names, null)
  ip_pools = [for pool in try(each.value.ip_pools, []) : {
    "ip_pool_name" : pool.name
    "ip_pool_role" : pool.role == "PRINCIPAL_IP_ADDRESS_POOL" ? "MAIN_POOL" : pool.role == "LINK_OVERLAPPING_IP_POOL" ? "PHYSICAL_LINK_POOL" : null
  }]
  multicast_enabled        = try(each.value.multicast_enabled, local.defaults.catalyst_center.lan_automation.multicast_enabled, null)
  redistribute_isis_to_bgp = try(each.value.advertise_lan_automation_routes_into_bgp, local.defaults.catalyst_center.lan_automation.advertise_lan_automation_routes_into_bgp, null)
  isis_domain_password     = try(each.value.isis_domain_password, local.defaults.catalyst_center.lan_automation.isis_domain_password, null)
}

resource "catalystcenter_lan_automation" "lanauto_edge" {
  for_each = { for lanauto in try(local.catalyst_center.lan_automation, []) : lanauto.name => lanauto if lanauto.type == "devices" && lanauto.status == "START" }

  discovered_device_site_name_hierarchy = try(each.value.discovered_device_site_name_hierarchy, local.defaults.catalyst_center.lan_automation.discovered_device_site_name_hierarchy, null)
  primary_device_management_ip_address  = try(each.value.primary_device_management_ip_address, local.defaults.catalyst_center.lan_automation.primary_device_management_ip_address, null)
  peer_device_management_ip_address     = try(each.value.secondary_device_management_ip_address, local.defaults.catalyst_center.lan_automation.secondary_device_management_ip_address, null)
  primary_device_interface_names        = try(each.value.primary_device_interface_names, local.defaults.catalyst_center.lan_automation.primary_device_interface_names, null)
  ip_pools = [for pool in try(each.value.ip_pools, []) : {
    "ip_pool_name" : pool.name
    "ip_pool_role" : pool.role == "PRINCIPAL_IP_ADDRESS_POOL" ? "MAIN_POOL" : pool.role == "LINK_OVERLAPPING_IP_POOL" ? "PHYSICAL_LINK_POOL" : null
  }]
  multicast_enabled        = try(each.value.multicast_enabled, local.defaults.catalyst_center.lan_automation.multicast_enabled, null)
  redistribute_isis_to_bgp = try(each.value.advertise_lan_automation_routes_into_bgp, local.defaults.catalyst_center.lan_automation.advertise_lan_automation_routes_into_bgp, null)
  isis_domain_password     = try(each.value.isis_domain_password, local.defaults.catalyst_center.lan_automation.isis_domain_password, null)
  host_name_prefix         = try(each.value.host_name_prefix, local.defaults.catalyst_center.lan_automation.host_name_prefix, null)
  discovery_level          = try(each.value.discovery_level, local.defaults.catalyst_center.lan_automation.discovery_level, null)
  discovery_devices        = try(each.value.discovery_devices, local.defaults.catalyst_center.lan_automation.discovery_devices, null)
  discovery_timeout        = try(each.value.discovery_timeout, local.defaults.catalyst_center.lan_automation.discovery_timeout, null)

  depends_on = [catalystcenter_ip_pool_reservation.pool_reservation]
}
