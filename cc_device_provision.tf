locals {
  device_ip_to_id = {
    for device in coalesce(data.catalystcenter_network_devices.all_devices.devices, []) :
    device.management_ip_address => device.id
    if device.management_ip_address != null
    && device.management_ip_address != ""
    && !startswith(device.platform_id, "C91")
    && !startswith(device.platform_id, "CW91")
  }

  # Access points get their hostname from Catalyst Center at claim time and use
  # an ephemeral management IP — which is why AP platforms are excluded from
  # device_ip_to_id above. Serial number is their only stable, pre-known identifier.
  device_serial_to_id = {
    for device in coalesce(data.catalystcenter_network_devices.all_devices.devices, []) :
    device.serial_number => device.id
    if try(device.serial_number, null) != null
    && try(device.serial_number, "") != ""
  }

  # The Configure Access Points API selects APs by their ETHERNET MAC. This is
  # not `mac_address`, which on an AP is the base radio MAC and is rejected with
  # "There are no Access points with the specified ethernet mac addresses".
  # Requires catalystcenter provider 0.6.1 or later.
  device_serial_to_ap_eth_mac = {
    for device in coalesce(data.catalystcenter_network_devices.all_devices.devices, []) :
    device.serial_number => device.ap_ethernet_mac_address
    if try(device.serial_number, "") != ""
    && try(device.ap_ethernet_mac_address, null) != null
    && try(device.ap_ethernet_mac_address, "") != ""
  }

  name_to_fqdn_mapping = try({
    for device in local.catalyst_center.inventory.devices : device.name => try(device.fqdn_name, device.name, null)
  }, {})

  all_devices = {
    for device in try(local.catalyst_center.inventory.devices, []) : device.name => merge(device,
      {
        dayn_templates_map = merge(
          {
            for template in try(device.dayn_templates.regular, []) : try("${template.project_name}#${template.name}", template.name) => {
              name                = try(template.name, null)
              variables           = try(template.variables, [])
              copying_config      = try(template.copying_config, null)
              force_push_template = try(template.force_push_template, null)
            }
          },
          {
            for template in try(device.dayn_templates.composite, []) : try("${template.project_name}#${template.name}", template.name) => {
              name                = try(template.name, null)
              variables           = try(template.variables, [])
              copying_config      = try(template.copying_config, null)
              force_push_template = try(template.force_push_template, null)
            }
          }
        )
      }
    )
  }

  provisioned_devices = [
    for device in try(local.catalyst_center.inventory.devices, []) : device if(strcontains(device.state, "PROVISION")) && ((try(device.primary_managed_ap_locations, null) == null && try(device.secondary_managed_ap_locations, null) == null && !contains(try(device.fabric_roles, []), "WIRELESS_CONTROLLER_NODE") && !contains(try(device.fabric_roles, []), "EMBEDDED_WIRELESS_CONTROLLER_NODE")) || ((try(device.primary_managed_ap_locations, null) != null || try(device.secondary_managed_ap_locations, null) != null) && contains(try(device.fabric_roles, []), "EMBEDDED_WIRELESS_CONTROLLER_NODE"))) && contains(local.sites, try(device.site, "NONE"))
  ]

  all_provisioned_devices = [
    for device in try(local.catalyst_center.inventory.devices, []) : device if(strcontains(device.state, "PROVISION")) && try(device.primary_managed_ap_locations, null) == null
  ]

  provisioned_devices_filtered = [
    for d in local.provisioned_devices : d
    if var.bulk_site_provisioning == null || d.site == var.bulk_site_provisioning || (var.bulk_site_provisioning != null ? startswith(d.site, format("%s/", var.bulk_site_provisioning)) : false)
  ]

  grouping_mode = (
    var.bulk_site_provisioning != null ? "bulk" :
    length(var.managed_sites) > 0 ? "managed" :
    "default"
  )

  provisioned_devices_by_site = {
    for site in distinct([
      for d in local.provisioned_devices_filtered :
      local.grouping_mode == "bulk" ? var.bulk_site_provisioning :
      local.grouping_mode == "managed" ? one([
        for ms in var.managed_sites :
        ms if startswith(d.site, ms)
      ]) :
      d.site
    ]) :
    site => [
      for d in local.provisioned_devices_filtered :
      d if
      local.grouping_mode == "bulk" ? true :
      local.grouping_mode == "managed" ?
      anytrue([
        for ms in var.managed_sites :
        startswith(d.site, ms) && ms == site
      ]) :
      d.site == site
    ]
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
      device_ip = try(d.device_ip, null)
    }... if d.state == "ASSIGN" && contains(local.sites, try(d.site, "NONE")) && try(d.type, null) != "AccessPoint"
    && (
      lookup(local.device_name_to_id, d.name, null) != null ||
      lookup(local.device_name_to_id, try(d.fqdn_name, ""), null) != null ||
      lookup(local.device_ip_to_id, try(d.device_ip, ""), null) != null
    )
  }

  assigned_access_points_map = {
    for d in try(local.catalyst_center.inventory.devices, []) :
    d.site => {
      name          = d.name
      fqdn_name     = try(d.fqdn_name, null)
      device_ip     = try(d.device_ip, null)
      serial_number = try(d.serial_number, null)
    }... if(strcontains(d.state, "PROVISION") || d.state == "ASSIGN") && contains(local.sites, try(d.site, "NONE")) && try(d.type, null) == "AccessPoint"
    && (
      lookup(local.device_serial_to_id, try(d.serial_number, ""), null) != null ||
      lookup(local.device_name_to_id, d.name, null) != null ||
      lookup(local.device_name_to_id, try(d.fqdn_name, ""), null) != null ||
      lookup(local.device_ip_to_id, try(d.device_ip, ""), null) != null
    )
  }

  wireless_devices_map = {
    for d in try(local.catalyst_center.inventory.devices, []) :
    d.site => {
      name      = d.name
      fqdn_name = d.fqdn_name
      device_ip = try(d.device_ip, null)
    }... if(strcontains(d.state, "PROVISION")) && (try(d.primary_managed_ap_locations, null) != null || try(d.secondary_managed_ap_locations, null) != null) && !contains(try(d.fabric_roles, []), "EMBEDDED_WIRELESS_CONTROLLER_NODE") && contains(local.sites, try(d.site, "NONE"))
    && (
      lookup(local.device_name_to_id, d.name, null) != null ||
      lookup(local.device_name_to_id, try(d.fqdn_name, ""), null) != null ||
      lookup(local.device_ip_to_id, try(d.device_ip, ""), null) != null
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
    && lookup(local.device_ip_to_id, try(device.device_ip, ""), null) == null
  ]

  missing_devices_error = length(local.missing_devices) > 0 ? "❌ The following devices are not found in Catalyst Center inventory:\n\n${join("\n", [for d in local.missing_devices : "  • ${d.name} (IP: ${try(d.device_ip, "N/A")}, FQDN: ${try(d.fqdn_name, "N/A")}, Site: ${d.site})"])}\n\nAction required: Ensure all devices are discovered in Catalyst Center before running Terraform." : ""

  missing_access_points = [
    for device in try(local.catalyst_center.inventory.devices, []) :
    device
    if(strcontains(device.state, "PROVISION") || device.state == "ASSIGN")
    && try(device.type, null) == "AccessPoint"
    && contains(local.sites, try(device.site, "NONE"))
    && lookup(local.device_serial_to_id, try(device.serial_number, ""), null) == null
    && lookup(local.device_name_to_id, device.name, null) == null
    && lookup(local.device_name_to_id, try(device.fqdn_name, ""), null) == null
    && lookup(local.device_ip_to_id, try(device.device_ip, ""), null) == null
  ]

  missing_access_points_error = length(local.missing_access_points) > 0 ? "❌ The following access points are not found in Catalyst Center inventory:\n\n${join("\n", [for d in local.missing_access_points : "  • ${d.name} (Serial: ${try(d.serial_number, "N/A")}, FQDN: ${try(d.fqdn_name, "N/A")}, Site: ${d.site})"])}\n\nAn access point is resolved by `serial_number` first, then `name` / `fqdn_name`. Resolution by `device_ip` does not apply to Catalyst 9100-series (C91xx) or Cisco Wireless (CW91xx) access points, whose management IPs are ephemeral and deliberately excluded from IP-based lookup. Because Catalyst Center also assigns AP hostnames at claim time, `serial_number` is the recommended identifier.\n\nAction required: Add `serial_number` to these access points in the data model, or ensure they are claimed and present in Catalyst Center inventory before running Terraform." : ""

  # Devices Terraform will actually provision — same scope as the AP-location /
  # controller resources, so the guard fires only when the destructive delete is
  # possible.
  provisioned_wireless_candidate_devices = [
    for device in try(local.catalyst_center.inventory.devices, []) : device
  if strcontains(try(device.state, ""), "PROVISION")]

  # Per-device wireless facts, computed once to avoid repeating the
  # contains(coalesce(try(...))) role lookups.
  wireless_device_facts = [
    for device in local.provisioned_wireless_candidate_devices : {
      name         = device.name
      roles        = coalesce(try(device.fabric_roles, []), [])
      has_embedded = contains(coalesce(try(device.fabric_roles, []), []), "EMBEDDED_WIRELESS_CONTROLLER_NODE")
      has_wlc      = contains(coalesce(try(device.fabric_roles, []), []), "WIRELESS_CONTROLLER_NODE")
      has_ap_locs  = try(device.primary_managed_ap_locations, null) != null || try(device.secondary_managed_ap_locations, null) != null
      is_fabric    = length(coalesce(try(device.fabric_roles, []), [])) > 0
    }
  ]

  # Rule: a FABRIC device (has any fabric_roles) WITH managed AP locations must
  # carry EXACTLY ONE wireless-controller role — EMBEDDED_WIRELESS_CONTROLLER_NODE
  # or WIRELESS_CONTROLLER_NODE, never both and never neither.
  # `has_embedded == has_wlc` is true when the device carries both roles or
  # neither, both of which are invalid for a fabric device managing APs.
  # Non-fabric devices (no fabric_roles, e.g. a standalone C9800 in ACCESS role)
  # legitimately manage AP locations without any fabric controller role and are
  # therefore exempt from this rule.
  wireless_devices_with_invalid_controller_role = [
    for d in local.wireless_device_facts : d
    if d.has_ap_locs && d.is_fabric && (d.has_embedded == d.has_wlc)
  ]

  wireless_invalid_controller_role_error = length(local.wireless_devices_with_invalid_controller_role) > 0 ? "❌ The following fabric devices have managed AP locations but do not carry exactly one wireless-controller role:\n\n${join("\n", [for d in local.wireless_devices_with_invalid_controller_role : "  • ${d.name} (roles: ${join(", ", d.roles)})"])}\n\nA fabric device (one with fabric_roles) that has primary_managed_ap_locations or secondary_managed_ap_locations MUST contain exactly one of EMBEDDED_WIRELESS_CONTROLLER_NODE or WIRELESS_CONTROLLER_NODE (never both, never neither).\n\nAction required: Add the appropriate wireless-controller role (or remove the managed AP locations), so each fabric wireless device is exactly one kind of controller. Non-fabric wireless controllers must have no fabric_roles at all." : ""

  # Rule: a device WITH a controller role must have at least one managed AP
  # location.
  wireless_controller_missing_ap_locations = [
    for d in local.wireless_device_facts : d
    if(d.has_embedded || d.has_wlc) && !d.has_ap_locs
  ]

  wireless_controller_missing_ap_locations_error = length(local.wireless_controller_missing_ap_locations) > 0 ? "❌ The following devices carry a wireless-controller role but have no managed AP locations:\n\n${join("\n", [for d in local.wireless_controller_missing_ap_locations : "  • ${d.name} (roles: ${join(", ", d.roles)})"])}\n\nA device with EMBEDDED_WIRELESS_CONTROLLER_NODE or WIRELESS_CONTROLLER_NODE MUST have at least one of primary_managed_ap_locations or secondary_managed_ap_locations.\n\nAction required: Add primary_managed_ap_locations (and/or secondary_managed_ap_locations), or remove the wireless-controller role if the device is not a controller." : ""
}

check "device_discovery_validation" {
  assert {
    condition     = length(local.missing_devices) == 0
    error_message = local.missing_devices_error
  }
}

check "access_point_discovery_validation" {
  assert {
    condition     = length(local.missing_access_points) == 0
    error_message = local.missing_access_points_error
  }
}

resource "terraform_data" "wireless_validation" {
  lifecycle {
    precondition {
      condition     = length(local.wireless_devices_with_invalid_controller_role) == 0
      error_message = local.wireless_invalid_controller_role_error
    }
    precondition {
      condition     = length(local.wireless_controller_missing_ap_locations) == 0
      error_message = local.wireless_controller_missing_ap_locations_error
    }
  }
}

resource "terraform_data" "bulk_site_provisioning_validation" {
  count = var.bulk_site_provisioning != null && var.use_bulk_api ? 1 : 0

  lifecycle {
    precondition {
      condition     = contains(local.sites, var.bulk_site_provisioning)
      error_message = <<-EOT
        ❌ The bulk_site_provisioning site '${var.bulk_site_provisioning}' is not defined in your YAML configuration.

        Available sites in your configuration:
        ${join("\n  ", sort(local.sites))}

        Action required: Ensure the site exists in your YAML configuration or adjust the bulk_site_provisioning variable.
      EOT
    }
  }
}

resource "catalystcenter_update_device_management_address" "management_ip" {
  for_each = {
    for device in try(local.catalyst_center.inventory.devices, []) : device.name => device
    if try(device.device_ip, null) != null
    && try(device.type, null) != "AccessPoint"
    && contains(local.sites, try(device.site, "NONE"))
    && (
      lookup(local.device_name_to_id, device.name, null) != null ||
      lookup(local.device_name_to_id, try(device.fqdn_name, ""), null) != null
    )
    && lookup(local.device_ip_to_id, try(device.device_ip, ""), null) == null
  }

  device_id = coalesce(
    try(lookup(local.device_name_to_id, each.value.name, null), null),
    try(lookup(local.device_name_to_id, each.value.fqdn_name, null), null)
  )
  new_ip = try(each.value.device_ip, null)
}

resource "catalystcenter_assign_device_to_site" "devices_to_site" {
  for_each = local.assigned_devices_map

  device_ids = [
    for device in each.value :
    try(local.device_name_to_id[device.name], local.device_name_to_id[device.fqdn_name], local.device_ip_to_id[device.device_ip])
    if(
      lookup(local.device_name_to_id, device.name, null) != null ||
      lookup(local.device_name_to_id, try(device.fqdn_name, ""), null) != null ||
      lookup(local.device_ip_to_id, try(device.device_ip, ""), null) != null
    )
  ]
  site_id = var.use_bulk_api ? coalesce(local.site_id_list_bulk[each.key], local.data_source_created_sites_list[each.key]) : local.site_id_list[each.key]
}

resource "catalystcenter_assign_device_to_site" "access_points_to_site" {
  for_each = local.assigned_access_points_map

  device_ids = [
    for device in each.value :
    try(local.device_serial_to_id[device.serial_number], local.device_name_to_id[device.name], local.device_name_to_id[device.fqdn_name], local.device_ip_to_id[device.device_ip])
    if(
      lookup(local.device_serial_to_id, try(device.serial_number, ""), null) != null ||
      lookup(local.device_name_to_id, device.name, null) != null ||
      lookup(local.device_name_to_id, try(device.fqdn_name, ""), null) != null ||
      lookup(local.device_ip_to_id, try(device.device_ip, ""), null) != null
    )
  ]
  site_id = var.use_bulk_api ? coalesce(local.site_id_list_bulk[each.key], local.data_source_created_sites_list[each.key]) : local.site_id_list[each.key]
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
      lookup(local.device_ip_to_id, try(device.device_ip, ""), null) != null
    )
  }

  device_id = coalesce(
    try(lookup(local.device_name_to_id, each.value.name, null), null),
    try(lookup(local.device_name_to_id, each.value.fqdn_name, null), null),
    try(lookup(local.device_ip_to_id, each.value.device_ip, null), null)
  )
  role        = try(each.value.device_role, local.defaults.catalyst_center.inventory.devices.device_role, null)
  role_source = try(each.value.role_source, local.defaults.catalyst_center.inventory.devices.role_source, null)

  depends_on = [data.catalystcenter_network_devices.all_devices, catalystcenter_floor.floor, catalystcenter_building.building, catalystcenter_area.area_0, catalystcenter_area.area_1, catalystcenter_area.area_2, catalystcenter_area.area_3, catalystcenter_area.area_4, catalystcenter_area.area_5, catalystcenter_area.area_6, catalystcenter_area.area_7, catalystcenter_area.area_8, catalystcenter_area.area_9, data.catalystcenter_sites.created_sites]
}

resource "catalystcenter_provision_device" "provision_device" {
  for_each = { for device in try(local.catalyst_center.inventory.devices, []) : device.name => device if(strcontains(device.state, "PROVISION")) && ((try(device.primary_managed_ap_locations, null) == null && try(device.secondary_managed_ap_locations, null) == null && !contains(try(device.fabric_roles, []), "WIRELESS_CONTROLLER_NODE") && !contains(try(device.fabric_roles, []), "EMBEDDED_WIRELESS_CONTROLLER_NODE")) || ((try(device.primary_managed_ap_locations, null) != null || try(device.secondary_managed_ap_locations, null) != null) && contains(try(device.fabric_roles, []), "EMBEDDED_WIRELESS_CONTROLLER_NODE"))) && contains(local.sites, try(device.site, "NONE")) && var.use_bulk_api == false && try(device.type, null) != "AccessPoint" }

  site_id           = var.use_bulk_api ? coalesce(local.site_id_list_bulk[each.value.site], local.data_source_created_sites_list[each.value.site]) : local.site_id_list[each.value.site]
  network_device_id = try(local.device_name_to_id[each.value.name], local.device_name_to_id[each.value.fqdn_name], local.device_ip_to_id[each.value.device_ip])
  reprovision       = try(each.value.state, null) == "REPROVISION" ? true : false
  clean_up_config   = try(each.value.clean_up_config, local.defaults.catalyst_center.inventory.devices.clean_up_config, null)
  depends_on        = [catalystcenter_device_role.role, catalystcenter_assign_device_to_site.devices_to_site]
}

resource "catalystcenter_provision_devices" "provision_devices" {
  for_each = { for site, devices in try(local.provisioned_devices_by_site, {}) : site => devices if length(devices) > 0 && var.use_bulk_api }

  site_id = coalesce(local.site_id_list_bulk[each.key], local.data_source_created_sites_list[each.key])
  provision_devices = [
    for device in each.value : {
      network_device_id = coalesce(
        try(lookup(local.device_name_to_id, device.name, null), null),
        try(lookup(local.device_name_to_id, device.fqdn_name, null), null),
        try(lookup(local.device_ip_to_id, device.device_ip, null), null)
      )
      site_id         = coalesce(local.site_id_list_bulk[device.site], local.data_source_created_sites_list[device.site])
      reprovision     = try(device.state, null) == "REPROVISION" ? true : false
      clean_up_config = try(device.clean_up_config, local.defaults.catalyst_center.inventory.devices.clean_up_config, null)
    }
    if(
      lookup(local.device_name_to_id, device.name, null) != null ||
      lookup(local.device_name_to_id, try(device.fqdn_name, ""), null) != null ||
      lookup(local.device_ip_to_id, try(device.device_ip, ""), null) != null
    )
  ]

  depends_on = [catalystcenter_device_role.role, catalystcenter_assign_device_to_site.devices_to_site]
}

resource "catalystcenter_assign_device_to_site" "wireless_devices_to_site" {
  for_each = local.wireless_devices_map

  device_ids = [
    for device in each.value :
    try(local.device_name_to_id[device.name], local.device_name_to_id[device.fqdn_name], local.device_ip_to_id[device.device_ip])
    if(
      lookup(local.device_name_to_id, device.name, null) != null ||
      lookup(local.device_name_to_id, try(device.fqdn_name, ""), null) != null ||
      lookup(local.device_ip_to_id, try(device.device_ip, ""), null) != null
    )
  ]

  site_id = var.use_bulk_api ? coalesce(local.site_id_list_bulk[each.key], local.data_source_created_sites_list[each.key]) : local.site_id_list[each.key]
}

resource "catalystcenter_wireless_device_provision" "wireless_controller" {
  for_each = { for device in try(local.catalyst_center.inventory.devices, []) : device.name => device if(strcontains(device.state, "PROVISION")) && (contains(try(device.fabric_roles, []), "WIRELESS_CONTROLLER_NODE") || try(device.primary_managed_ap_locations, null) != null || try(device.secondary_managed_ap_locations, null) != null) && !contains(try(device.fabric_roles, []), "EMBEDDED_WIRELESS_CONTROLLER_NODE") && contains(local.sites, try(device.site, "NONE")) }

  network_device_id = coalesce(
    try(lookup(local.device_name_to_id, each.value.name, null), null),
    try(lookup(local.device_name_to_id, each.value.fqdn_name, null), null),
    try(lookup(local.device_ip_to_id, each.value.device_ip, null), null)
  )
  reprovision = try(each.value.state, null) == "REPROVISION" ? true : false

  depends_on = [catalystcenter_building.building, catalystcenter_floor.floor, catalystcenter_area.area_0, catalystcenter_area.area_1, catalystcenter_area.area_2, catalystcenter_area.area_3, catalystcenter_area.area_4, catalystcenter_area.area_5, catalystcenter_area.area_6, catalystcenter_area.area_7, catalystcenter_area.area_8, catalystcenter_area.area_9, time_sleep.wait_for_managed_ap_locations, catalystcenter_assign_managed_ap_locations.managed_ap_locations, catalystcenter_assign_device_to_site.wireless_devices_to_site, catalystcenter_wireless_ssid.ssid, catalystcenter_wireless_profile.wireless_profile, data.catalystcenter_sites.created_sites]
}

resource "catalystcenter_assign_managed_ap_locations" "managed_ap_locations" {
  for_each = { for device in try(local.catalyst_center.inventory.devices, []) : device.name => device if(strcontains(device.state, "PROVISION")) && (contains(try(device.fabric_roles, []), "WIRELESS_CONTROLLER_NODE") || try(device.primary_managed_ap_locations, null) != null || try(device.secondary_managed_ap_locations, null) != null) && contains(local.sites, try(device.site, "NONE")) }

  primary_managed_ap_locations_site_ids   = [for site in try(each.value.primary_managed_ap_locations, []) : try(local.site_id_list[each.value.primary_managed_ap_locations], local.site_id_list[site], coalesce(local.site_id_list_bulk[site], local.data_source_created_sites_list[site]), null)]
  secondary_managed_ap_locations_site_ids = [for site in try(each.value.secondary_managed_ap_locations, []) : try(local.site_id_list[each.value.secondary_managed_ap_locations], local.site_id_list[site], coalesce(local.site_id_list_bulk[site], local.data_source_created_sites_list[site]), null)]
  device_id = coalesce(
    try(lookup(local.device_name_to_id, each.value.name, null), null),
    try(lookup(local.device_name_to_id, each.value.fqdn_name, null), null),
    try(lookup(local.device_ip_to_id, each.value.device_ip, null), null)
  )

  depends_on = [catalystcenter_assign_device_to_site.wireless_devices_to_site, catalystcenter_network_profile_for_sites_assignments.site_to_wireless_network_profile, catalystcenter_provision_devices.provision_devices, catalystcenter_provision_device.provision_device]
}

resource "time_sleep" "wait_for_managed_ap_locations" {
  depends_on = [catalystcenter_assign_managed_ap_locations.managed_ap_locations]

  create_duration = "10s"
}

locals {
  provisioned_access_points = [
    for device in try(local.catalyst_center.inventory.devices, []) : device
    if(strcontains(device.state, "PROVISION"))
    && try(device.type, null) == "AccessPoint"
    && contains(local.sites, try(device.site, "NONE"))
    && (
      lookup(local.device_serial_to_id, try(device.serial_number, ""), null) != null ||
      lookup(local.device_name_to_id, device.name, null) != null ||
      lookup(local.device_name_to_id, try(device.fqdn_name, ""), null) != null ||
      lookup(local.device_ip_to_id, try(device.device_ip, ""), null) != null
    )
  ]

  provisioned_access_points_by_site = {
    for d in local.provisioned_access_points : d.site => d...
  }
}


resource "catalystcenter_provision_access_points" "access_points" {
  for_each = { for site, devices in try(local.provisioned_access_points_by_site, {}) : site => devices if length(devices) > 0 }

  network_devices = [for device in each.value : {
    device_id = coalesce(
      try(lookup(local.device_serial_to_id, device.serial_number, null), null),
      try(lookup(local.device_name_to_id, device.name, null), null),
      try(lookup(local.device_name_to_id, device.fqdn_name, null), null),
      try(lookup(local.device_ip_to_id, device.device_ip, null), null)
    )
    reprovision = try(device.state, null) == "REPROVISION" ? true : false
  }]
  rf_profile_name = try(each.value[0].rf_profile)
  site_id         = try(var.use_bulk_api ? coalesce(local.site_id_list_bulk[each.key], local.data_source_created_sites_list[each.key]) : local.site_id_list[each.key], null)

  depends_on = [catalystcenter_assign_device_to_site.access_points_to_site]
}



resource "time_sleep" "provision_device_wait" {
  count = length(try(local.provisioned_devices, [])) > 0 && !var.manage_global_settings ? 1 : 0

  create_duration = "10s"

  depends_on = [catalystcenter_provision_device.provision_device, catalystcenter_provision_devices.provision_devices, catalystcenter_wireless_device_provision.wireless_controller]
}
# ---------------------------------------------------------------------------
# Access point configuration
#
# Applies the optional `inventory.devices[].access_point` block and reconciles
# AP hostnames to `inventory.devices[].name`. Two independent opt-ins, both
# default false so brownfield estates are never touched implicitly:
#   var.manage_ap_configuration -> apply the `access_point` settings block
#   var.manage_ap_hostname      -> rename the AP to its data-model `name`
#
# Named configurations are read from `wireless.access_point_configurations` and
# referenced by `inventory.devices[].access_point_configuration` — reusable radio
# and controller intent sits with the other wireless constructs, the per-device
# records that consume it stay in `inventory`.
#
# GROUPING: in the Configure Access Points API only `mac_address`, `ap_name` and
# `ap_name_new` are per-AP. Every other setting — including the whole
# `radio_configurations` list — is top-level and applies to every AP in
# `ap_list`. Access points are therefore grouped by resolved configuration, one
# resource instance per group, keyed by the named configuration where possible.
#
# FOR_EACH KEYS derive only from the data model. MAC and current hostname come
# from a data source and are apply-time unknown, so they appear only as values
# inside `ap_list`, never in a key. Putting them in a key reproduces the
# "Invalid for_each argument" failure that forced the RMA rework
# (netascode/nac-catalystcenter#530).
#
# IDEMPOTENCY: `ap_list` must never be derived from a value this resource itself
# mutates, or a successful apply changes its own arguments and costs a second
# apply to settle. So `ap_name_new` is always the desired data-model name, never
# the result of comparing against the live hostname, and `ap_name` stays null —
# the API keys on `mac_address`. Renaming an AP to the name it already holds is a
# no-op, which is what makes sending it unconditionally safe.
# ---------------------------------------------------------------------------
locals {
  ap_mode_map            = { LOCAL = 0, MONITOR = 1, SNIFFER = 4, BRIDGE = 5 }
  ap_failover_map        = { LOW = 1, MEDIUM = 2, HIGH = 3, CRITICAL = 4 }
  ap_assignment_mode_map = { GLOBAL = 1, CUSTOM = 2 }
  ap_channel_width_map   = { "20" = 3, "40" = 4, "80" = 5, "160" = 6, "320" = 7 }
  ap_radio_band_map      = { "2.4" = "RADIO24", "5" = "RADIO5", "6" = "RADIO6", "XOR" = "RADIO5" }
  ap_radio_type_map      = { "2.4" = 1, "5" = 2, "XOR" = 3, "6" = 6 }

  ap_serial_to_desired_name = {
    for d in local.provisioned_access_points :
    d.serial_number => d.name
    if try(d.serial_number, null) != null
  }

  ap_hostname_managed = {
    for d in local.provisioned_access_points :
    d.serial_number => true
    if var.manage_ap_hostname
    && try(d.serial_number, null) != null
    && try(d.name, null) != null
  }

  ap_named_configs = {
    for c in try(local.catalyst_center.wireless.access_point_configurations, []) :
    c.name => c
  }

  ap_config_defaults = try(local.defaults.catalyst_center.inventory.devices.access_point, {})

  ap_candidates = [
    for d in local.provisioned_access_points : d
    if try(d.serial_number, null) != null
    && (
      (
        var.manage_ap_configuration
        && (try(d.access_point, null) != null || try(d.access_point_configuration, null) != null)
      )
      || lookup(local.ap_hostname_managed, try(d.serial_number, ""), false)
    )
  ]

  ap_unknown_config_refs = [
    for d in local.provisioned_access_points : d
    if var.manage_ap_configuration
    && try(d.access_point_configuration, null) != null
    && lookup(local.ap_named_configs, d.access_point_configuration, null) == null
  ]

  ap_unknown_config_refs_error = length(local.ap_unknown_config_refs) > 0 ? "❌ The following access points reference an `access_point_configuration` that is not defined:\n\n${join("\n", [for d in local.ap_unknown_config_refs : "  • ${d.name} -> `${d.access_point_configuration}`"])}\n\nNamed configurations are declared under `catalyst_center.wireless.access_point_configurations`.\n\nAction required: Define the missing configuration, or correct the reference on the device." : ""

  # Effective settings resolve inline > named configuration > module defaults.
  # `radios` overrides at list level rather than element level, so a device that
  # declares radios replaces the named configuration's radios outright.
  ap_config_resolved = {
    for d in local.ap_candidates : d.serial_number => {
      config_name = try(d.access_point_configuration, null)
      has_inline  = try(d.access_point, null) != null

      admin_status                 = try(d.access_point.admin_status, local.ap_named_configs[d.access_point_configuration].admin_status, local.ap_config_defaults.admin_status, null)
      ap_mode                      = try(d.access_point.ap_mode, local.ap_named_configs[d.access_point_configuration].ap_mode, local.ap_config_defaults.ap_mode, null)
      failover_priority            = try(d.access_point.failover_priority, local.ap_named_configs[d.access_point_configuration].failover_priority, local.ap_config_defaults.failover_priority, null)
      led_status                   = try(d.access_point.led_status, local.ap_named_configs[d.access_point_configuration].led_status, local.ap_config_defaults.led_status, null)
      led_brightness_level         = try(d.access_point.led_brightness_level, local.ap_named_configs[d.access_point_configuration].led_brightness_level, local.ap_config_defaults.led_brightness_level, null)
      location                     = try(d.access_point.location, local.ap_named_configs[d.access_point_configuration].location, local.ap_config_defaults.location, null)
      is_assigned_site_as_location = try(d.access_point.is_assigned_site_as_location, local.ap_named_configs[d.access_point_configuration].is_assigned_site_as_location, local.ap_config_defaults.is_assigned_site_as_location, null)
      primary_controller_name      = try(d.access_point.primary_controller_name, local.ap_named_configs[d.access_point_configuration].primary_controller_name, local.ap_config_defaults.primary_controller_name, null)
      primary_ip_address           = try(d.access_point.primary_ip_address, local.ap_named_configs[d.access_point_configuration].primary_ip_address, local.ap_config_defaults.primary_ip_address, null)
      secondary_controller_name    = try(d.access_point.secondary_controller_name, local.ap_named_configs[d.access_point_configuration].secondary_controller_name, local.ap_config_defaults.secondary_controller_name, null)
      secondary_ip_address         = try(d.access_point.secondary_ip_address, local.ap_named_configs[d.access_point_configuration].secondary_ip_address, local.ap_config_defaults.secondary_ip_address, null)
      tertiary_controller_name     = try(d.access_point.tertiary_controller_name, local.ap_named_configs[d.access_point_configuration].tertiary_controller_name, local.ap_config_defaults.tertiary_controller_name, null)
      tertiary_ip_address          = try(d.access_point.tertiary_ip_address, local.ap_named_configs[d.access_point_configuration].tertiary_ip_address, local.ap_config_defaults.tertiary_ip_address, null)
      radios                       = try(d.access_point.radios, local.ap_named_configs[d.access_point_configuration].radios, local.ap_config_defaults.radios, [])
    }
  }

  # configure_* flags are derived from value presence, never taken from the data
  # model — they are an API transport artefact, not user intent.
  ap_config_normalised = [
    for d in local.ap_candidates : {
      serial_number = d.serial_number

      # Devices resolving purely from a named configuration share that name as
      # their group key, which keeps plan output stable and readable. Any inline
      # override forces a payload hash so two differently-tuned devices never
      # collapse into one API call.
      group_key = (
        local.ap_config_resolved[d.serial_number].config_name != null
        ? (
          local.ap_config_resolved[d.serial_number].has_inline
          ? "${local.ap_config_resolved[d.serial_number].config_name}+${substr(md5(jsonencode(local.ap_config_resolved[d.serial_number])), 0, 6)}"
          : local.ap_config_resolved[d.serial_number].config_name
        )
        : substr(md5(jsonencode(local.ap_config_resolved[d.serial_number])), 0, 8)
      )

      settings = {
        configure_admin_status = local.ap_config_resolved[d.serial_number].admin_status != null
        admin_status           = local.ap_config_resolved[d.serial_number].admin_status

        configure_ap_mode = local.ap_config_resolved[d.serial_number].ap_mode != null
        ap_mode           = try(local.ap_mode_map[local.ap_config_resolved[d.serial_number].ap_mode], null)

        configure_failover_priority = local.ap_config_resolved[d.serial_number].failover_priority != null
        failover_priority           = try(local.ap_failover_map[local.ap_config_resolved[d.serial_number].failover_priority], null)

        configure_led_status = local.ap_config_resolved[d.serial_number].led_status != null
        led_status           = local.ap_config_resolved[d.serial_number].led_status

        configure_led_brightness_level = local.ap_config_resolved[d.serial_number].led_brightness_level != null
        led_brightness_level           = local.ap_config_resolved[d.serial_number].led_brightness_level

        # `is_assigned_site_as_location` has no configure_* flag of its own and
        # rides on configure_location, which is the gate telling the API to
        # change the location at all. Without this the site-derived option is
        # accepted and silently ignored.
        configure_location = local.ap_config_resolved[d.serial_number].location != null || local.ap_config_resolved[d.serial_number].is_assigned_site_as_location == true
        location           = local.ap_config_resolved[d.serial_number].location

        is_assigned_site_as_location = local.ap_config_resolved[d.serial_number].is_assigned_site_as_location

        configure_ha_controller   = local.ap_config_resolved[d.serial_number].primary_controller_name != null
        primary_controller_name   = local.ap_config_resolved[d.serial_number].primary_controller_name
        primary_ip_address        = local.ap_config_resolved[d.serial_number].primary_ip_address
        secondary_controller_name = local.ap_config_resolved[d.serial_number].secondary_controller_name
        secondary_ip_address      = local.ap_config_resolved[d.serial_number].secondary_ip_address
        tertiary_controller_name  = local.ap_config_resolved[d.serial_number].tertiary_controller_name
        tertiary_ip_address       = local.ap_config_resolved[d.serial_number].tertiary_ip_address

        radio_configurations = [
          for r in local.ap_config_resolved[d.serial_number].radios : {
            # Catalyst Center rejects a radio band sent alongside an AUTO or
            # MONITOR role (NCWL10967) — the band selects which band an XOR
            # radio serves and is only meaningful for SERVING. radio_type still
            # identifies which radio is being configured.
            radio_band = contains(["AUTO", "MONITOR"], try(r.role, "")) ? null : lookup(local.ap_radio_band_map, tostring(r.band), null)
            radio_type = lookup(local.ap_radio_type_map, tostring(r.band), null)

            configure_admin_status = try(r.admin_status, null) != null
            admin_status           = try(r.admin_status, null)

            configure_radio_role_assignment = try(r.role, null) != null
            radio_role_assignment           = try(r.role, null)

            configure_antenna_pattern_name = try(r.antenna_pattern_name, null) != null
            antenna_pattern_name           = try(r.antenna_pattern_name, null)
            antenna_gain                   = try(r.antenna_gain, null)

            configure_antenna_cable = try(r.antenna_cable_name, null) != null
            antenna_cable_name      = try(r.antenna_cable_name, null)
            cable_loss              = try(r.cable_loss, null)

            configure_channel       = try(r.channel_number, null) != null || try(r.channel_assignment_mode, null) != null
            channel_assignment_mode = try(local.ap_assignment_mode_map[r.channel_assignment_mode], null)
            channel_number          = try(r.channel_number, null)

            configure_channel_width = try(r.channel_width, null) != null
            channel_width           = lookup(local.ap_channel_width_map, tostring(try(r.channel_width, "")), null)

            configure_power       = try(r.power_level, null) != null || try(r.power_assignment_mode, null) != null
            power_assignment_mode = try(local.ap_assignment_mode_map[r.power_assignment_mode], null)
            power_level           = try(r.power_level, null)
          }
        ]
      }
    }
  ]

  ap_config_by_key = { for a in local.ap_config_normalised : a.group_key => a... }

  ap_config_groups = {
    for key, entries in local.ap_config_by_key : key => {
      settings = entries[0].settings
      serials  = [for a in entries : a.serial_number]
    }
  }

  ap_config_missing_mac = [
    for a in local.ap_config_normalised : a.serial_number
    if lookup(local.device_serial_to_ap_eth_mac, a.serial_number, null) == null
  ]

  ap_config_missing_mac_error = length(local.ap_config_missing_mac) > 0 ? "❌ The following access points cannot be configured because Catalyst Center returned no ethernet MAC address for them:\n\n${join("\n", [for s in local.ap_config_missing_mac : "  • serial ${s}"])}\n\nThe Configure Access Points intent API selects access points by their ethernet MAC address (`apEthernetMacAddress` in inventory) and accepts no other identifier. Note this is not the device `macAddress`, which on an access point is the base radio MAC. An ethernet MAC is only present once the access point has been claimed and is in inventory.\n\nAction required: Claim these access points, or remove their `access_point` block and set `manage_ap_hostname = false` for them." : ""

  ap_config_location_conflict = [
    for d in local.ap_candidates : d
    if local.ap_config_resolved[d.serial_number].location != null
    && local.ap_config_resolved[d.serial_number].is_assigned_site_as_location == true
  ]

  ap_config_location_conflict_error = length(local.ap_config_location_conflict) > 0 ? "❌ The following access points set both `location` and `is_assigned_site_as_location: true`:\n\n${join("\n", [for d in local.ap_config_location_conflict : "  • ${d.name} (serial: ${try(d.serial_number, "N/A")}, location: \"${local.ap_config_resolved[d.serial_number].location}\")"])}\n\nThese are two mutually exclusive sources for the same access point location attribute, and the Configure Access Points API does not define which one wins.\n\nNote that the access point location is a free-text label written onto the device; it is not the Catalyst Center site assignment, which is managed separately from `site`.\n\nAction required: Keep `is_assigned_site_as_location: true` to derive the label from the assigned site (recommended, since the site is already the source of truth), or remove it and set `location` explicitly." : ""

  ap_config_invalid_antenna_gain = [
    for d in local.ap_candidates : d
    if anytrue([
      for r in local.ap_config_resolved[d.serial_number].radios :
      try(r.antenna_gain, null) != null && lower(try(r.antenna_pattern_name, "")) != "other"
    ])
  ]

  ap_config_invalid_antenna_gain_error = length(local.ap_config_invalid_antenna_gain) > 0 ? "❌ The following access points set `antenna_gain` without `antenna_pattern_name: other`:\n\n${join("\n", [for d in local.ap_config_invalid_antenna_gain : "  • ${d.name} (serial: ${try(d.serial_number, "N/A")})"])}\n\nCatalyst Center only applies `antenna_gain` when `antenna_pattern_name` is set to `other`; otherwise the gain is derived from the named antenna pattern and the supplied value is silently ignored.\n\nAction required: Set `antenna_pattern_name: other` on those radios, or remove `antenna_gain`." : ""

  ap_config_invalid_cable_loss = [
    for d in local.ap_candidates : d
    if anytrue([
      for r in local.ap_config_resolved[d.serial_number].radios :
      try(r.cable_loss, null) != null && lower(try(r.antenna_cable_name, "")) != "other"
    ])
  ]

  ap_config_invalid_cable_loss_error = length(local.ap_config_invalid_cable_loss) > 0 ? "❌ The following access points set `cable_loss` without `antenna_cable_name: other`:\n\n${join("\n", [for d in local.ap_config_invalid_cable_loss : "  • ${d.name} (serial: ${try(d.serial_number, "N/A")})"])}\n\nCatalyst Center only applies `cable_loss` when `antenna_cable_name` is set to `other`.\n\nAction required: Set `antenna_cable_name: other` on those radios, or remove `cable_loss`." : ""

  ap_config_role_rf_conflict = [
    for d in local.ap_candidates : d
    if anytrue([
      for r in local.ap_config_resolved[d.serial_number].radios :
      (
        try(r.channel_number, null) != null
        || try(r.channel_assignment_mode, null) != null
        || try(r.channel_width, null) != null
        || try(r.power_level, null) != null
        || try(r.power_assignment_mode, null) != null
      )
      && try(r.role, "") != "SERVING"
    ])
  ]

  ap_config_role_rf_conflict_error = length(local.ap_config_role_rf_conflict) > 0 ? "❌ The following access points set channel or power parameters on a radio whose `role` is not `SERVING`:\n\n${join("\n", [for d in local.ap_config_role_rf_conflict : "  • ${d.name} (serial: ${try(d.serial_number, "N/A")})"])}\n\nCatalyst Center rejects this with `NCWL10977: Radio Role Assignment ... is not compatible with Channel Width / Power Assignment configuration. This configuration is only supported with Serving Radio Role Assignment.`\n\nOmitting `role` does not mean \"no role\" — it leaves the radio on its current role, which is typically `AUTO` and therefore still rejected. Any radio carrying `channel_number`, `channel_assignment_mode`, `channel_width`, `power_level` or `power_assignment_mode` must set `role: SERVING` explicitly in the same request.\n\nAction required: Add `role: SERVING` to those radios, or remove the channel and power parameters and let RRM manage them." : ""

  ap_config_width_on_24ghz = [
    for d in local.ap_candidates : d
    if anytrue([
      for r in local.ap_config_resolved[d.serial_number].radios :
      try(r.channel_width, null) != null && tostring(try(r.band, "")) == "2.4"
    ])
  ]

  ap_config_width_on_24ghz_error = length(local.ap_config_width_on_24ghz) > 0 ? "❌ The following access points set `channel_width` on a 2.4 GHz radio:\n\n${join("\n", [for d in local.ap_config_width_on_24ghz : "  • ${d.name} (serial: ${try(d.serial_number, "N/A")})"])}\n\nCatalyst Center rejects this with `NCWL10970: Channel Bandwidth is supported for A (5 GHz), 6GHz and XOR (Dual-Band) radios only.` The 2.4 GHz band operates at 20 MHz only; channel bonding is not supported there.\n\nAction required: Remove `channel_width` from the 2.4 GHz radio. `channel_number`, `power_level` and their `CUSTOM` assignment modes remain valid on that band." : ""

  ap_config_rf_mode_conflict = [
    for d in local.ap_candidates : d
    if anytrue([
      for r in local.ap_config_resolved[d.serial_number].radios :
      (
        (try(r.channel_width, null) != null || try(r.channel_number, null) != null)
        && try(r.channel_assignment_mode, "") != "CUSTOM"
      )
      || (
        try(r.power_level, null) != null
        && try(r.power_assignment_mode, "") != "CUSTOM"
      )
    ])
  ]

  ap_config_rf_mode_conflict_error = length(local.ap_config_rf_mode_conflict) > 0 ? "❌ The following access points set an explicit channel, channel width or power level without the matching assignment mode set to `CUSTOM`:\n\n${join("\n", [for d in local.ap_config_rf_mode_conflict : "  • ${d.name} (serial: ${try(d.serial_number, "N/A")})"])}\n\nCatalyst Center rejects this with `NCWL10959: Channel Width can be configured only when Channel Assignment is in Custom mode.` Under `GLOBAL` — which is also the behaviour when the mode is omitted — the controller's RRM algorithm owns the value, so an explicit one cannot be applied.\n\nAction required: Add `channel_assignment_mode: CUSTOM` alongside `channel_number` / `channel_width`, and `power_assignment_mode: CUSTOM` alongside `power_level`. Otherwise remove the explicit values and let RRM manage the radio." : ""
}

resource "terraform_data" "ap_configuration_validation" {
  lifecycle {
    precondition {
      condition     = length(local.ap_unknown_config_refs) == 0
      error_message = local.ap_unknown_config_refs_error
    }
    precondition {
      condition     = length(local.ap_config_missing_mac) == 0
      error_message = local.ap_config_missing_mac_error
    }
    precondition {
      condition     = length(local.ap_config_location_conflict) == 0
      error_message = local.ap_config_location_conflict_error
    }
    precondition {
      condition     = length(local.ap_config_role_rf_conflict) == 0
      error_message = local.ap_config_role_rf_conflict_error
    }
    precondition {
      condition     = length(local.ap_config_rf_mode_conflict) == 0
      error_message = local.ap_config_rf_mode_conflict_error
    }
    precondition {
      condition     = length(local.ap_config_width_on_24ghz) == 0
      error_message = local.ap_config_width_on_24ghz_error
    }
  }
}

check "access_point_configuration_antenna_gain_validation" {
  assert {
    condition     = length(local.ap_config_invalid_antenna_gain) == 0
    error_message = local.ap_config_invalid_antenna_gain_error
  }
}

check "access_point_configuration_cable_loss_validation" {
  assert {
    condition     = length(local.ap_config_invalid_cable_loss) == 0
    error_message = local.ap_config_invalid_cable_loss_error
  }
}

resource "catalystcenter_access_point_configuration" "ap_config" {
  for_each = {
    for key, group in local.ap_config_groups : key => group
    if length([for s in group.serials : s if lookup(local.device_serial_to_ap_eth_mac, s, null) != null]) > 0
  }

  ap_list = [
    for s in each.value.serials : {
      mac_address = local.device_serial_to_ap_eth_mac[s]
      ap_name     = null
      ap_name_new = lookup(local.ap_hostname_managed, s, false) ? local.ap_serial_to_desired_name[s] : null
    }
    if lookup(local.device_serial_to_ap_eth_mac, s, null) != null
  ]

  configure_admin_status = each.value.settings.configure_admin_status
  admin_status           = each.value.settings.admin_status

  configure_ap_mode = each.value.settings.configure_ap_mode
  ap_mode           = each.value.settings.ap_mode

  configure_failover_priority = each.value.settings.configure_failover_priority
  failover_priority           = each.value.settings.failover_priority

  configure_led_status = each.value.settings.configure_led_status
  led_status           = each.value.settings.led_status

  configure_led_brightness_level = each.value.settings.configure_led_brightness_level
  led_brightness_level           = each.value.settings.led_brightness_level

  configure_location = each.value.settings.configure_location
  location           = each.value.settings.location

  is_assigned_site_as_location = each.value.settings.is_assigned_site_as_location

  configure_ha_controller   = each.value.settings.configure_ha_controller
  primary_controller_name   = each.value.settings.primary_controller_name
  primary_ip_address        = each.value.settings.primary_ip_address
  secondary_controller_name = each.value.settings.secondary_controller_name
  secondary_ip_address      = each.value.settings.secondary_ip_address
  tertiary_controller_name  = each.value.settings.tertiary_controller_name
  tertiary_ip_address       = each.value.settings.tertiary_ip_address

  radio_configurations = each.value.settings.radio_configurations

  depends_on = [catalystcenter_provision_access_points.access_points]
}
