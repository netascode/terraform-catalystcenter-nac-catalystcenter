resource "catalystcenter_lan_automation_link" "link" {
  for_each = {
    for link in try(local.catalyst_center.lan_automation.links, []) :
    "${link.name}#_#${link.action}" => link
    if contains(["ADD_LINK", "DELETE_LINK"], try(link.action, ""))
  }

  action                               = try(each.value.action, local.defaults.catalyst_center.lan_automation.links.action, null)
  primary_device_management_ip_address = try(each.value.primary_device_management_ip_address, local.defaults.catalyst_center.lan_automation.links.primary_device_management_ip_address, null)
  primary_device_interface_name        = try(each.value.primary_device_interface_name, local.defaults.catalyst_center.lan_automation.links.primary_device_interface_name, null)
  peer_device_management_ip_address    = try(each.value.secondary_device_management_ip_address, local.defaults.catalyst_center.lan_automation.links.secondary_device_management_ip_address, null)
  peer_device_interface_name           = try(each.value.secondary_device_interface_name, local.defaults.catalyst_center.lan_automation.links.secondary_device_interface_name, null)
  ip_pool_name                         = try(each.value.ip_pool_name, local.defaults.catalyst_center.lan_automation.links.ip_pool_name, null)

  # Link add/remove operates on the seed device and the devices a LAN automation session
  # discovered, so both endpoints must already be onboarded: sessions run first, and the
  # seed/discovered devices are assigned to their site before any link operation.
  depends_on = [
    catalystcenter_lan_automation.lanauto_edge,
    catalystcenter_assign_device_to_site.devices_to_site,
  ]
}

resource "catalystcenter_lan_automation" "lanauto_edge" {
  # The provider models a session as create=START / delete=STOP: creating this resource
  # starts LAN automation, destroying it stops it. So we only instantiate entries with
  # status == "START"; a "STOP" entry (or a removed entry) produces no resource, which
  # tears the session down on the next apply.
  for_each = {
    for lanauto in try(local.catalyst_center.lan_automation.devices, []) :
    lanauto.name => lanauto
    if try(lanauto.status, "") == "START"
  }

  discovered_device_site_name_hierarchy = try(each.value.discovered_device_site_name_hierarchy, local.defaults.catalyst_center.lan_automation.devices.discovered_device_site_name_hierarchy, null)
  primary_device_management_ip_address  = try(each.value.primary_device_management_ip_address, local.defaults.catalyst_center.lan_automation.devices.primary_device_management_ip_address, null)
  peer_device_management_ip_address     = try(each.value.peer_device_management_ip_address, each.value.secondary_device_management_ip_address, local.defaults.catalyst_center.lan_automation.devices.peer_device_management_ip_address, null)
  primary_device_interface_names        = try(each.value.primary_device_interface_names, local.defaults.catalyst_center.lan_automation.devices.primary_device_interface_names, null)
  ip_pools = [for pool in try(each.value.ip_pools, []) : {
    "ip_pool_name" : try(pool.ip_pool_name, pool.name, null)
    # Ported DM supplies provider enums directly (MAIN_POOL / PHYSICAL_LINK_POOL); legacy DM
    # used PRINCIPAL_IP_ADDRESS_POOL / LINK_OVERLAPPING_IP_POOL which we translate as fallback.
    "ip_pool_role" : try(pool.ip_pool_role, pool.role == "PRINCIPAL_IP_ADDRESS_POOL" ? "MAIN_POOL" : pool.role == "LINK_OVERLAPPING_IP_POOL" ? "PHYSICAL_LINK_POOL" : pool.role, null)
  }]
  multicast_enabled               = try(each.value.multicast_enabled, local.defaults.catalyst_center.lan_automation.devices.multicast_enabled, null)
  redistribute_isis_to_bgp        = try(each.value.redistribute_isis_to_bgp, each.value.advertise_lan_automation_routes_into_bgp, local.defaults.catalyst_center.lan_automation.devices.redistribute_isis_to_bgp, null)
  isis_domain_password_wo         = try(each.value.isis_domain_password, local.defaults.catalyst_center.lan_automation.devices.isis_domain_password, null)
  isis_domain_password_wo_version = try(each.value.isis_domain_password_version, local.defaults.catalyst_center.lan_automation.devices.isis_domain_password_version, 1)
  host_name_prefix                = try(each.value.host_name_prefix, local.defaults.catalyst_center.lan_automation.devices.host_name_prefix, null)
  discovery_level                 = try(each.value.discovery_level, local.defaults.catalyst_center.lan_automation.devices.discovery_level, null)
  discovery_devices               = try(each.value.discovery_devices, local.defaults.catalyst_center.lan_automation.devices.discovery_devices, null)
  discovery_timeout               = try(each.value.discovery_timeout, local.defaults.catalyst_center.lan_automation.devices.discovery_timeout, null)

  depends_on = [catalystcenter_ip_pool_reservation.pool_reservation]
}
