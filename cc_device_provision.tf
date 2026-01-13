locals {
  device_ip_to_id = {
    for device in coalesce(data.catalystcenter_network_devices.all_devices.devices, []) :
    device.management_ip_address => device.id
    if device.management_ip_address != null
    && device.management_ip_address != ""
    && !startswith(device.platform_id, "C91")
    && !startswith(device.platform_id, "CW91")
  }

  name_to_fqdn_mapping = try({
    for device in local.catalyst_center.inventory.devices : device.name => try(device.fqdn_name, device.name, null)
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
    for device in try(local.catalyst_center.inventory.devices, []) : device if strcontains(device.state, "PROVISION") && try(device.primary_managed_ap_locations, null) == null && !contains(try(device.fabric_roles, []), "WIRELESS_CONTROLLER_NODE") && !contains(try(device.fabric_roles, []), "EMBEDDED_WIRELESS_CONTROLLER_NODE") && contains(local.sites, try(device.site, "NONE"))
  ]

  all_provisioned_devices = [
    for device in try(local.catalyst_center.inventory.devices, []) : device if strcontains(device.state, "PROVISION") && try(device.primary_managed_ap_locations, null) == null
  ]

  provisioned_devices_filtered = var.bulk_site_provisioning != null ? [
    for d in local.provisioned_devices : d
    if d.site == var.bulk_site_provisioning || startswith(d.site, "${var.bulk_site_provisioning}/")
  ] : local.provisioned_devices

  provisioned_devices_by_site = {
    for site in distinct([for d in local.provisioned_devices_filtered : var.bulk_site_provisioning != null ? var.bulk_site_provisioning : d.site]) :
    site => [for d in local.provisioned_devices_filtered : d if var.bulk_site_provisioning != null ? true : d.site == site]
  }

  provisioned_sda_transit_cp_devices = flatten([
    for transit in try(local.catalyst_center.fabric.transits, []) : [
      for device in try(transit.control_plane_devices, []) :
      device
      if anytrue([
        for prov in local.all_provisioned_devices :
        prov.name == device && prov.state == "PROVISION"
      ])
    ]
  ])

  assigned_devices_map = {
    for d in try(local.catalyst_center.inventory.devices, []) :
    d.site => {
      name      = d.name
      fqdn_name = d.fqdn_name
      device_ip = d.device_ip
    }... if d.state == "ASSIGN" && contains(local.sites, try(d.site, "NONE")) && try(d.type, null) != "AccessPoint"
    && (
      lookup(local.device_name_to_id, d.name, null) != null ||
      lookup(local.device_name_to_id, try(d.fqdn_name, ""), null) != null ||
      lookup(local.device_ip_to_id, d.device_ip, null) != null
    )
  }

  assigned_access_points_map = {
    for d in try(local.catalyst_center.inventory.devices, []) :
    d.site => {
      name      = d.name
      fqdn_name = d.fqdn_name
      device_ip = d.device_ip
    }... if(d.state == "ASSIGN" || (strcontains(d.state, "PROVISION"))) && contains(local.sites, try(d.site, "NONE")) && try(d.type, null) == "AccessPoint"
    && (
      lookup(local.device_name_to_id, d.name, null) != null ||
      lookup(local.device_name_to_id, try(d.fqdn_name, ""), null) != null ||
      lookup(local.device_ip_to_id, d.device_ip, null) != null
    )
  }

  wireless_devices_map = {
    for d in try(local.catalyst_center.inventory.devices, []) :
    d.site => {
      name      = d.name
      fqdn_name = d.fqdn_name
      device_ip = d.device_ip
    }... if strcontains(d.state, "PROVISION") && try(d.primary_managed_ap_locations, null) != null && !contains(try(d.fabric_roles, []), "EMBEDDED_WIRELESS_CONTROLLER_NODE") && contains(local.sites, try(d.site, "NONE"))
    && (
      lookup(local.device_name_to_id, d.name, null) != null ||
      lookup(local.device_name_to_id, try(d.fqdn_name, ""), null) != null ||
      lookup(local.device_ip_to_id, d.device_ip, null) != null
    )
  }
}

data "catalystcenter_network_devices" "all_devices" {
}

locals {
  missing_devices = [
    for device in try(local.catalyst_center.inventory.devices, []) :
    device
    if(strcontains(device.state, "PROVISION") || device.state == "ASSIGN")
    && try(device.type, null) != "AccessPoint"
    && lookup(local.device_name_to_id, device.name, null) == null
    && lookup(local.device_name_to_id, try(device.fqdn_name, ""), null) == null
    && lookup(local.device_ip_to_id, device.device_ip, null) == null
  ]

  missing_devices_error = length(local.missing_devices) > 0 ? "❌ The following devices are not found in Catalyst Center inventory:\n\n${join("\n", [for d in local.missing_devices : "  • ${d.name} (IP: ${d.device_ip}, FQDN: ${try(d.fqdn_name, "N/A")}, Site: ${d.site})"])}\n\nAction required: Ensure all devices are discovered in Catalyst Center before running Terraform." : ""
}

check "device_discovery_validation" {
  assert {
    condition     = length(local.missing_devices) == 0
    error_message = local.missing_devices_error
  }
}

resource "catalystcenter_assign_device_to_site" "devices_to_site" {
  for_each = { for k, v in local.assigned_devices_map : k => v if(var.use_bulk_api ? try(local.site_id_list_bulk[k], null) != null : try(local.site_id_list[k], null) != null) }

  device_ids = [
    for device in each.value :
    try(local.device_name_to_id[device.name], local.device_name_to_id[device.fqdn_name], local.device_ip_to_id[device.device_ip])
    if(
      lookup(local.device_name_to_id, device.name, null) != null ||
      lookup(local.device_name_to_id, try(device.fqdn_name, ""), null) != null ||
      lookup(local.device_ip_to_id, device.device_ip, null) != null
    )
  ]
  site_id = var.use_bulk_api ? local.site_id_list_bulk[each.key] : local.site_id_list[each.key]
}

resource "catalystcenter_assign_device_to_site" "access_points_to_site" {
  for_each = { for k, v in local.assigned_access_points_map : k => v if(var.use_bulk_api ? try(local.site_id_list_bulk[k], null) != null : try(local.site_id_list[k], null) != null) }

  device_ids = [
    for device in each.value :
    try(local.device_name_to_id[device.name], local.device_name_to_id[device.fqdn_name], local.device_ip_to_id[device.device_ip])
    if(
      lookup(local.device_name_to_id, device.name, null) != null ||
      lookup(local.device_name_to_id, try(device.fqdn_name, ""), null) != null ||
      lookup(local.device_ip_to_id, device.device_ip, null) != null
    )
  ]
  site_id = var.use_bulk_api ? local.site_id_list_bulk[each.key] : local.site_id_list[each.key]
}

resource "catalystcenter_device_role" "role" {
  for_each = {
    for device in try(local.catalyst_center.inventory.devices, []) :
    device.name => device
    if(strcontains(device.state, "PROVISION") || device.state == "ASSIGN")
    && contains(local.sites, try(device.site, "NONE"))
    && try(device.type, null) != "AccessPoint"
    && (
      lookup(local.device_name_to_id, device.name, null) != null ||
      lookup(local.device_name_to_id, try(device.fqdn_name, ""), null) != null ||
      lookup(local.device_ip_to_id, device.device_ip, null) != null
    )
  }

  device_id = coalesce(
    try(lookup(local.device_name_to_id, each.value.name, null), null),
    try(lookup(local.device_name_to_id, each.value.fqdn_name, null), null),
    try(lookup(local.device_ip_to_id, each.value.device_ip, null), null)
  )
  role        = try(each.value.device_role, local.defaults.catalyst_center.inventory.devices.device_role, null)
  role_source = try(each.value.role_source, local.defaults.catalyst_center.inventory.devices.role_source, null)

  depends_on = [data.catalystcenter_network_devices.all_devices, catalystcenter_floor.floor, catalystcenter_building.building, catalystcenter_area.area_0, catalystcenter_area.area_1, catalystcenter_area.area_2, catalystcenter_area.area_3]
}

resource "catalystcenter_provision_device" "provision_device" {
  for_each = { for device in try(local.catalyst_center.inventory.devices, []) : device.name => device if strcontains(device.state, "PROVISION") && ((try(device.primary_managed_ap_locations, null) == null && !contains(try(device.fabric_roles, []), "WIRELESS_CONTROLLER_NODE") && !contains(try(device.fabric_roles, []), "EMBEDDED_WIRELESS_CONTROLLER_NODE")) || (try(device.primary_managed_ap_locations, null) != null && contains(try(device.fabric_roles, []), "EMBEDDED_WIRELESS_CONTROLLER_NODE"))) && contains(local.sites, try(device.site, "NONE")) && var.use_bulk_api == false && try(device.type, null) != "AccessPoint" }

  site_id           = try(local.site_id_list[each.value.site], null)
  network_device_id = try(local.device_name_to_id[each.value.name], local.device_name_to_id[each.value.fqdn_name], local.device_ip_to_id[each.value.device_ip])
  reprovision       = try(each.value.state, null) == "REPROVISION" ? true : false

  depends_on = [catalystcenter_device_role.role, catalystcenter_assign_device_to_site.devices_to_site]
}

resource "catalystcenter_provision_devices" "provision_devices" {
  for_each = { for site, devices in try(local.provisioned_devices_by_site, {}) : site => devices if length(devices) > 0 && var.use_bulk_api && try(local.site_id_list_bulk[site], null) != null }

  site_id = try(local.site_id_list_bulk[each.key], null)
  provision_devices = [
    for device in each.value : {
      network_device_id = coalesce(
        try(lookup(local.device_name_to_id, device.name, null), null),
        try(lookup(local.device_name_to_id, device.fqdn_name, null), null),
        try(lookup(local.device_ip_to_id, device.device_ip, null), null)
      )
      site_id     = try(local.site_id_list_bulk[device.site], null)
      reprovision = try(device.state, null) == "REPROVISION" ? true : false
    }
    if(
      lookup(local.device_name_to_id, device.name, null) != null ||
      lookup(local.device_name_to_id, try(device.fqdn_name, ""), null) != null ||
      lookup(local.device_ip_to_id, device.device_ip, null) != null
    )
  ]

  depends_on = [catalystcenter_device_role.role, catalystcenter_assign_device_to_site.devices_to_site]
}

resource "catalystcenter_assign_device_to_site" "wireless_devices_to_site" {
  for_each = { for k, v in local.wireless_devices_map : k => v if(var.use_bulk_api ? try(local.site_id_list_bulk[k], null) != null : try(local.site_id_list[k], null) != null) }

  device_ids = [
    for device in each.value :
    try(local.device_name_to_id[device.name], local.device_name_to_id[device.fqdn_name], local.device_ip_to_id[device.device_ip])
    if(
      lookup(local.device_name_to_id, device.name, null) != null ||
      lookup(local.device_name_to_id, try(device.fqdn_name, ""), null) != null ||
      lookup(local.device_ip_to_id, device.device_ip, null) != null
    )
  ]

  site_id = var.use_bulk_api ? local.site_id_list_bulk[each.key] : local.site_id_list[each.key]
}

resource "catalystcenter_wireless_device_provision" "wireless_controller" {
  for_each = { for device in try(local.catalyst_center.inventory.devices, []) : device.name => device if strcontains(device.state, "PROVISION") && (contains(try(device.fabric_roles, []), "WIRELESS_CONTROLLER_NODE") || (try(device.primary_managed_ap_locations, null) != null) && !contains(try(device.fabric_roles, []), "EMBEDDED_WIRELESS_CONTROLLER_NODE")) && contains(local.sites, try(device.site, "NONE")) }

  network_device_id = coalesce(
    try(lookup(local.device_name_to_id, each.value.name, null), null),
    try(lookup(local.device_name_to_id, each.value.fqdn_name, null), null),
    try(lookup(local.device_ip_to_id, each.value.device_ip, null), null)
  )
  reprovision = try(each.value.state, null) == "REPROVISION" ? true : false

  depends_on = [catalystcenter_building.building, catalystcenter_floor.floor, catalystcenter_area.area_0, catalystcenter_area.area_1, catalystcenter_area.area_2, catalystcenter_area.area_3, catalystcenter_assign_managed_ap_locations.managed_ap_locations, catalystcenter_assign_device_to_site.wireless_devices_to_site, catalystcenter_wireless_ssid.ssid, catalystcenter_wireless_profile.wireless_profile]
}

resource "catalystcenter_assign_managed_ap_locations" "managed_ap_locations" {
  for_each = { for device in try(local.catalyst_center.inventory.devices, []) : device.name => device if strcontains(device.state, "PROVISION") && (contains(try(device.fabric_roles, []), "WIRELESS_CONTROLLER_NODE") || try(device.primary_managed_ap_locations, null) != null) && contains(local.sites, try(device.site, "NONE")) }

  primary_managed_ap_locations_site_ids   = [for site in try(each.value.primary_managed_ap_locations, []) : try(local.site_id_list[each.value.primary_managed_ap_locations], local.site_id_list[site], local.site_id_list_bulk[site], null)]
  secondary_managed_ap_locations_site_ids = [for site in try(each.value.secondary_managed_ap_locations, []) : try(local.site_id_list[each.value.secondary_managed_ap_locations], local.site_id_list[each.value.site], local.site_id_list_bulk[each.value.site], null)]
  device_id = coalesce(
    try(lookup(local.device_name_to_id, each.value.name, null), null),
    try(lookup(local.device_name_to_id, each.value.fqdn_name, null), null),
    try(lookup(local.device_ip_to_id, each.value.device_ip, null), null)
  )

  depends_on = [catalystcenter_assign_device_to_site.wireless_devices_to_site]
}
locals {
  provisioned_access_points = [
    for device in try(local.catalyst_center.inventory.devices, []) : device if strcontains(device.state, "PROVISION") && try(device.type, null) == "AccessPoint" && contains(local.sites, try(device.site, "NONE"))
  ]

  provisioned_access_points_by_site = {
    for site in distinct([for d in local.provisioned_access_points : d.site]) :
    site => [for d in local.provisioned_access_points : d if d.site == site]
  }
}


resource "catalystcenter_provision_access_points" "access_points" {
  for_each = { for site, devices in try(local.provisioned_access_points_by_site, {}) : site => devices if length(devices) > 0 && (var.use_bulk_api ? try(local.site_id_list_bulk[site], null) != null : try(local.site_id_list[site], null) != null) }

  network_devices = [for device in each.value : {
    device_id = coalesce(
      try(lookup(local.device_name_to_id, device.name, null), null),
      try(lookup(local.device_name_to_id, device.fqdn_name, null), null),
      try(lookup(local.device_ip_to_id, device.device_ip, null), null)
    )
    reprovision = try(device.state, null) == "REPROVISION" ? true : false
  }]
  rf_profile_name = try(each.value[0].rf_profile)
  site_id         = try(var.use_bulk_api ? local.site_id_list_bulk[each.key] : local.site_id_list[each.key], null)

  depends_on = [catalystcenter_assign_device_to_site.access_points_to_site]
}



resource "time_sleep" "provision_device_wait" {
  count = length(try(local.provisioned_devices, [])) > 0 && !var.manage_global_settings ? 1 : 0

  create_duration = "10s"

  depends_on = [catalystcenter_provision_device.provision_device, catalystcenter_provision_devices.provision_devices, catalystcenter_wireless_device_provision.wireless_controller]
}
