locals {
  device_ip_to_id = try({
    for device in data.catalystcenter_network_devices.all_devices.devices : device.management_ip_address => device.id
  }, {})

  all_devices = {
    for device in try(local.catalyst_center.inventory.devices, []) : device.name => merge(device,
      {
        dayn_templates_map = merge(
          tomap({
            for template in try(device.dayn_templates.regular, []) : template.name => merge(
              template,
              {
                variables           = try(template.variables, []),
                copying_config      = try(template.copying_config, null)
                force_push_template = try(template.force_push_template, null)
              }
          ) }),
          tomap({
            for template in try(device.dayn_templates.composite, []) : template.name => merge(template, { variables = try(template.variables, []) })
          })
        )
      }
    )
  }

  provisioned_devices = [
    for device in try(local.catalyst_center.inventory.devices, []) : device if strcontains(device.state, "PROVISION")
  ]

  assigned_devices_map = {
    for d in try(local.catalyst_center.inventory.devices, []) :
    d.site => {
      name     = d.name
      hostname = d.hostname
    }... if d.state == "ASSIGN"
  }

  wireless_devices_map = {
    for d in try(local.catalyst_center.inventory.devices, []) :
    d.site => {
      name     = d.name
      hostname = d.hostname
    }... if strcontains(d.state, "PROVISION") && try(d.primary_managed_ap_locations, null) != null
  }
}

data "catalystcenter_network_devices" "all_devices" {
}

resource "catalystcenter_assign_device_to_site" "devices_to_site" {
  for_each = local.assigned_devices_map

  device_ids = [for device in each.value : try(local.device_name_to_id[device.name], local.device_name_to_id[device.hostname])]
  site_id    = local.site_id_list[each.key]
}

resource "catalystcenter_device_role" "role" {
  for_each = { for device in try(local.catalyst_center.inventory.devices, []) : device.name => device if strcontains(device.state, "PROVISION") || device.state == "ASSIGN" }

  device_id   = lookup(local.device_ip_to_id, each.value.device_ip, null)
  role        = try(each.value.device_role, local.defaults.catalyst_center.inventory.devices.device_role, null)
  role_source = try(each.value.role_source, local.defaults.catalyst_center.inventory.devices.role_source, null)

  depends_on = [data.catalystcenter_network_devices.all_devices, catalystcenter_floor.floor, catalystcenter_building.building, catalystcenter_area.area_0, catalystcenter_area.area_1, catalystcenter_area.area_2]
}

resource "catalystcenter_fabric_provision_device" "provision_device" {
  for_each = { for device in try(local.catalyst_center.inventory.devices, []) : device.name => device if strcontains(device.state, "PROVISION") && try(device.primary_managed_ap_locations, null) == null }

  site_id           = try(local.site_id_list[each.value.site], null)
  network_device_id = try(local.device_ip_to_id[each.value.device_ip], "")
  reprovision       = try(each.value.state, null) == "REPROVISION" ? true : false

  depends_on = [catalystcenter_device_role.role, catalystcenter_assign_device_to_site.devices_to_site]
}

resource "catalystcenter_assign_device_to_site" "wireless_devices_to_site" {
  for_each = local.wireless_devices_map

  device_ids = [for device in each.value : try(local.device_name_to_id[device.name], local.device_name_to_id[device.hostname])]
  site_id    = local.site_id_list[each.key]
}

resource "catalystcenter_wireless_device_provision" "wireless_controller" {
  for_each = { for device in try(local.catalyst_center.inventory.devices, []) : device.name => device if strcontains(device.state, "PROVISION") && (contains(try(device.fabric_roles, []), "WIRELESS_CONTROLLER_NODE") || try(device.primary_managed_ap_locations, null) != null) }

  network_device_id = lookup(local.device_ip_to_id, each.value.device_ip, null)
  reprovision       = try(each.value.state, null) == "REPROVISION" ? true : false

  depends_on = [catalystcenter_building.building, catalystcenter_floor.floor, catalystcenter_area.area_0, catalystcenter_area.area_1, catalystcenter_area.area_2, catalystcenter_assign_managed_ap_locations.managed_ap_locations, catalystcenter_assign_device_to_site.wireless_devices_to_site, catalystcenter_wireless_ssid.ssid, catalystcenter_wireless_profile.wireless_profile]
}

resource "catalystcenter_assign_managed_ap_locations" "managed_ap_locations" {
  for_each = { for device in try(local.catalyst_center.inventory.devices, []) : device.name => device if strcontains(device.state, "PROVISION") && (contains(try(device.fabric_roles, []), "WIRELESS_CONTROLLER_NODE") || try(device.primary_managed_ap_locations, null) != null) }

  primary_managed_ap_locations_site_ids   = [for site in try(each.value.primary_managed_ap_locations, []) : try(local.site_id_list[each.value.primary_managed_ap_locations], local.site_id_list[site], null)]
  secondary_managed_ap_locations_site_ids = [for site in try(each.value.secondary_managed_ap_locations, []) : try(local.site_id_list[each.value.secondary_managed_ap_locations], local.site_id_list[each.value.site], null)]
  device_id                               = try(local.device_ip_to_id[each.value.device_ip], "")

  depends_on = [catalystcenter_assign_device_to_site.wireless_devices_to_site]
}

resource "time_sleep" "provision_device_wait" {
  count = length(try(local.provisioned_devices, [])) > 0 ? 1 : 0

  create_duration = "10s"

  depends_on = [catalystcenter_fabric_provision_device.provision_device, catalystcenter_wireless_device_provision.wireless_controller]
}
