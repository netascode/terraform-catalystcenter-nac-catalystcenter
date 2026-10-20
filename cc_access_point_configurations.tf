locals {
  access_point_configurations = {
    for configuration in try(local.catalyst_center.wireless.access_point_configurations, []) : configuration.name => configuration
    if length(try(configuration.access_points, [])) > 0
  }
}

resource "catalystcenter_access_point_configuration" "access_point_configuration" {
  for_each = local.access_point_configurations

  ap_list                        = [for mac_address in each.value.access_points : { mac_address = mac_address }]
  configure_admin_status         = try(each.value.admin_status, null) != null
  admin_status                   = try(each.value.admin_status, null)
  configure_led_status           = try(each.value.led_status, null) != null
  led_status                     = try(each.value.led_status, null)
  configure_led_brightness_level = try(each.value.led_brightness_level, null) != null
  led_brightness_level           = try(each.value.led_brightness_level, null)
  configure_failover_priority    = try(each.value.failover_priority, null) != null
  failover_priority              = try({ LOW = 1, MEDIUM = 2, HIGH = 3, CRITICAL = 4 }[each.value.failover_priority], null)
  configure_ap_mode              = try(each.value.ap_mode, null) != null
  ap_mode                        = try({ LOCAL = 0, MONITOR = 1, SNIFFER = 4, BRIDGE = 5 }[each.value.ap_mode], null)
  configure_location             = try(each.value.is_assigned_site_as_location, null) != null
  is_assigned_site_as_location   = try(each.value.is_assigned_site_as_location, null)
  configure_ha_controller        = try(each.value.primary_controller_name, null) != null || try(each.value.secondary_controller_name, null) != null
  primary_controller_name        = try(each.value.primary_controller_name, null)
  primary_ip_address             = try(each.value.primary_ip_address, null)
  secondary_controller_name      = try(each.value.secondary_controller_name, null)
  secondary_ip_address           = try(each.value.secondary_ip_address, null)
  radio_configurations           = []
}
