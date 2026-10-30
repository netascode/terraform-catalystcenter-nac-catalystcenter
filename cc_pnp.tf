data "catalystcenter_images" "all_images" {
}

locals {
  image_name_to_id = {
    for name, images in {
      for image in coalesce(data.catalystcenter_images.all_images.images, []) : image.name => image...
    } : name => images[0].id
  }

  pnp_devices = {
    for device in try(local.catalyst_center.inventory.devices, []) : device.name => device
    if device.state == "PNP"
  }

  # A Catalyst 9800 registers in PnP as deviceType "Catalyst WLC" and is claimed
  # as CatalystWLC; any other claim type is rejected with NCOB01296. An embedded
  # controller is a Catalyst 9000 switch and claims as Default. Every non-embedded
  # controller carries type: WirelessController, but the validation enforcing that
  # covers only the *PROVISION states, so WIRELESS_CONTROLLER_NODE is honoured too
  # and a fabric controller is still claimed correctly while in state PNP.
  pnp_wireless_controllers = {
    for name, device in local.pnp_devices : name => device
    if(try(device.type, null) == "WirelessController" || contains(try(device.fabric_roles, []), "WIRELESS_CONTROLLER_NODE"))
    && !contains(try(device.fabric_roles, []), "EMBEDDED_WIRELESS_CONTROLLER_NODE")
  }

  # inventory.devices[].type also carries the provisioning device class
  # (WirelessController), which the claim endpoint does not accept. Values the
  # endpoint knows are passed through, anything else falls back to the default.
  pnp_claim_types = ["Default", "StackSwitch", "AccessPoint", "Sensor", "MobilityExpress"]

  # SVL devices are excluded: they carry their serials under svl.members[] and
  # have no top-level serial_number, and they are claimed with a fixed device
  # type by catalystcenter_pnp_network_device_claim rather than from this map.
  pnp_device_types = {
    for name, device in local.pnp_standard_devices : name => (
      contains(keys(local.pnp_wireless_controllers), name) ? "CatalystWLC" : (
        length(split(",", device.serial_number)) > 1 ? "StackSwitch" : (
          contains(local.pnp_claim_types, try(device.type, local.defaults.catalyst_center.pnp.devices.type, "")) ?
          try(device.type, local.defaults.catalyst_center.pnp.devices.type, null) :
          try(local.defaults.catalyst_center.pnp.devices.type, null)
        )
      )
    )
  }

  # Catalyst Center rejects a CatalystWLC claim that omits the static IP, subnet
  # mask or gateway with NCOB01330, after the device has already been added to
  # PnP by catalystcenter_pnp_device. It does not check interface_name at all:
  # the claim returns success and the Day-0 workflow then fails asynchronously
  # with NCOB02093 "configuration generation error", because the management
  # interface configuration cannot be generated without it. vlan_id is left out
  # of this check: both the claim and the Day-0 workflow complete without it,
  # management then being untagged on interface_name.
  pnp_controllers_missing_wireless_management = [
    for name, device in local.pnp_wireless_controllers : name
    if contains(local.sites, try(device.site, "NONE")) && (
      try(device.wireless_management.ip_address, local.defaults.catalyst_center.inventory.devices.wireless_management.ip_address, null) == null ||
      try(device.wireless_management.subnet_mask, local.defaults.catalyst_center.inventory.devices.wireless_management.subnet_mask, null) == null ||
      try(device.wireless_management.gateway, local.defaults.catalyst_center.inventory.devices.wireless_management.gateway, null) == null ||
      try(device.wireless_management.interface_name, local.defaults.catalyst_center.inventory.devices.wireless_management.interface_name, null) == null
    )
  ]

  pnp_controllers_missing_wireless_management_error = length(local.pnp_controllers_missing_wireless_management) > 0 ? "❌ The following wireless controllers are onboarded through Plug and Play but have incomplete wireless management settings:\n\n${join("\n", [for name in local.pnp_controllers_missing_wireless_management : "  • ${name}"])}\n\nA wireless controller with state: PNP is claimed as CatalystWLC. Catalyst Center accepts that claim only with a static IP, subnet mask and gateway (NCOB01330), and generates its Day-0 configuration only with a management interface name (NCOB02093, raised by the workflow after the claim itself has succeeded).\n\nAction required: Add a wireless_management block with ip_address, subnet_mask, gateway and interface_name to each device above." : ""

  pnp_managed_devices = {
    for name, device in local.pnp_devices : name => device
    if contains(local.sites, try(device.site, "NONE"))
  }

  pnp_standard_devices = { for name, device in local.pnp_managed_devices : name => device if try(device.svl, null) == null }
  pnp_svl_devices      = { for name, device in local.pnp_managed_devices : name => device if try(device.svl, null) != null }

  # Only the ACTIVE member is registered. Catalyst Center merges the pair into one
  # Plug and Play record under the ACTIVE serial once the SVL claim succeeds, so a
  # STANDBY `catalystcenter_pnp_device` would be dropped from state on the next
  # refresh and re-created on every apply.
  pnp_svl_member_registrations = merge([
    for name, device in local.pnp_svl_devices : {
      for member in device.svl.members : "${name}::${member.serial_number}" => {
        device_name   = name
        serial_number = member.serial_number
        pid           = try(device.pid, null)
      }
      if member.role == "ACTIVE"
    }
  ]...)

  pnp_svl_member_serials = merge([
    for name, device in local.pnp_svl_devices : {
      for member in device.svl.members : "${name}::${member.serial_number}" => {
        device_name   = name
        serial_number = member.serial_number
        role          = member.role
      }
    }
  ]...)

  # A serial absent from Plug and Play returns HTTP 200 with an empty array
  # rather than 404, so the data source reads successfully and leaves every
  # attribute null. A null id is therefore "not in the PnP database".
  #
  # Once the claim converges, Catalyst Center deletes the STANDBY member's Plug
  # and Play record and folds both serials into a single inventory device whose
  # serial_number is the comma-separated pair, so a member that has already been
  # onboarded is no longer in Plug and Play and must be matched there instead.
  # Without that second test this check fails every plan after a successful
  # onboarding.
  # Inventory entries without a usable serial number are skipped rather than
  # defaulted: coalesce() rejects an empty string as a fallback candidate, so
  # coalesce(serial_number, "") fails the whole plan on the first such entry,
  # anywhere in the inventory. Matches device_serial_to_id in
  # cc_device_provision.tf.
  pnp_svl_onboarded_serials = toset(flatten([
    for device in coalesce(data.catalystcenter_network_devices.all_devices.devices, []) :
    [for serial_number in split(",", device.serial_number) : trimspace(serial_number)]
    if try(device.serial_number, null) != null && try(device.serial_number, "") != ""
  ]))

  pnp_svl_members_missing_from_pnp = [
    for key, member in local.pnp_svl_member_serials : "${member.device_name} (${member.role}: ${member.serial_number})"
    if data.catalystcenter_pnp_device.svl_member[key].id == null
    && !contains(local.pnp_svl_onboarded_serials, member.serial_number)
  ]

  pnp_svl_members_missing_from_pnp_error = length(local.pnp_svl_members_missing_from_pnp) > 0 ? "❌ The following StackWise Virtual member switches are not present in the Catalyst Center Plug and Play database, and have not already been onboarded:\n\n${join("\n", [for member in local.pnp_svl_members_missing_from_pnp : "  • ${member}"])}\n\nAn SVL pair is claimed as a single logical device, so both member switches must already have contacted Catalyst Center and be listed under Plug and Play before the claim can succeed. Only the ACTIVE member is registered by this module; the STANDBY member is never registered and must appear on its own.\n\nAction required: Power on and cable each switch above so it registers with Plug and Play, and verify the serial number matches svl.members[].serial_number exactly (serials are case sensitive)." : ""

  pnp_svl_active_registration_key_by_name = {
    for name, device in local.pnp_svl_devices : name => "${name}::${[for m in device.svl.members : m.serial_number if m.role == "ACTIVE"][0]}"
  }
}

data "catalystcenter_pnp_device" "svl_member" {
  for_each = local.pnp_svl_member_serials

  serial_number = each.value.serial_number
}

resource "terraform_data" "pnp_svl_validation" {
  lifecycle {
    precondition {
      condition     = length(local.pnp_svl_members_missing_from_pnp) == 0
      error_message = local.pnp_svl_members_missing_from_pnp_error
    }
  }
}

resource "terraform_data" "pnp_wireless_validation" {
  lifecycle {
    precondition {
      condition     = length(local.pnp_controllers_missing_wireless_management) == 0
      error_message = local.pnp_controllers_missing_wireless_management_error
    }
  }
}

resource "catalystcenter_pnp_device" "pnp_device" {
  for_each = local.pnp_standard_devices

  serial_number = split(",", each.value.serial_number)[0]
  hostname      = each.value.name
  pid           = each.value.pid
  stack         = length(split(",", each.value.serial_number)) > 1 ? true : null

  lifecycle {
    ignore_changes = [hostname]
  }
}

resource "catalystcenter_pnp_device_claim_site" "claim_device" {
  for_each = local.pnp_standard_devices

  device_id                  = catalystcenter_pnp_device.pnp_device[each.key].id
  site_id                    = var.use_bulk_api ? coalesce(local.site_id_list_bulk[each.value.site], local.data_source_created_sites_list[each.value.site]) : local.site_id_list[each.value.site]
  type                       = local.pnp_device_types[each.key]
  hostname                   = try(each.value.name, each.value.fqdn_name, local.defaults.catalyst_center.pnp.devices.hostname, null)
  rf_profile                 = try(each.value.rf_profile, local.defaults.catalyst_center.pnp.devices.rf_profile, null)
  image_id                   = try(each.value.image_id, local.image_name_to_id[each.value.image_name], local.defaults.catalyst_center.pnp.devices.image_id, length(split(",", each.value.serial_number)) > 1 ? "" : null)
  image_skip                 = try(each.value.image_skip, local.defaults.catalyst_center.pnp.devices.image_skip, null)
  config_id                  = try(catalystcenter_template.regular_template[each.value.onboarding_template.name].id, catalystcenter_template.regular_template[local.template_name_to_key[each.value.onboarding_template.name]].id, data.catalystcenter_template.template[each.value.onboarding_template.name].id, data.catalystcenter_template.template[local.resource_key_to_template_key[each.value.onboarding_template.name]].id, data.catalystcenter_template.template[local.resource_key_to_template_key[local.template_name_to_key[each.value.onboarding_template.name]]].id, data.catalystcenter_template.unmanaged[each.value.onboarding_template.name].id, length(split(",", each.value.serial_number)) > 1 ? "" : null)
  config_parameters          = try(each.value.onboarding_template.variables, local.defaults.catalyst_center.onboarding_templates.variables, null)
  top_of_stack_serial_number = try(each.value.stack.top_of_stack_serial_number, null)
  cabling_scheme             = try(each.value.stack.cabling_scheme, local.defaults.catalyst_center.pnp.devices.cabling_scheme, null)
  static_ip                  = try(each.value.wireless_management.ip_address, local.defaults.catalyst_center.inventory.devices.wireless_management.ip_address, null)
  subnet_mask                = try(each.value.wireless_management.subnet_mask, local.defaults.catalyst_center.inventory.devices.wireless_management.subnet_mask, null)
  gateway                    = try(each.value.wireless_management.gateway, local.defaults.catalyst_center.inventory.devices.wireless_management.gateway, null)
  vlan_id                    = try(tostring(each.value.wireless_management.vlan_id), tostring(local.defaults.catalyst_center.inventory.devices.wireless_management.vlan_id), null)
  ip_interface_name          = try(each.value.wireless_management.interface_name, local.defaults.catalyst_center.inventory.devices.wireless_management.interface_name, null)

  depends_on = [catalystcenter_network_profile.switching_network_profile]
}

resource "catalystcenter_pnp_config_preview" "config_preview" {
  # Wireless controllers are excluded: site-config-preview has no CatalystWLC
  # type, so there is no preview to request for them. SVL devices are excluded
  # as well: they are claimed through catalystcenter_pnp_network_device_claim
  # and have no catalystcenter_pnp_device.pnp_device to preview against.
  for_each = { for name, device in local.pnp_standard_devices : name => device if try(device.type, local.defaults.catalyst_center.pnp.devices.type, "Default") != "AccessPoint" && !contains(keys(local.pnp_wireless_controllers), name) }

  device_id = catalystcenter_pnp_device.pnp_device[each.key].id
  site_id   = var.use_bulk_api ? coalesce(local.site_id_list_bulk[each.value.site], local.data_source_created_sites_list[each.value.site]) : local.site_id_list[each.value.site]
  type      = local.pnp_device_types[each.key]

  depends_on = [catalystcenter_pnp_device_claim_site.claim_device]
}

resource "catalystcenter_pnp_device" "pnp_svl_member" {
  for_each = local.pnp_svl_member_registrations

  serial_number = each.value.serial_number
  hostname      = each.value.device_name
  pid           = each.value.pid

  lifecycle {
    ignore_changes = [hostname]
  }
}

resource "catalystcenter_pnp_network_device_claim" "claim_svl" {
  for_each = local.pnp_svl_devices

  device_id   = catalystcenter_pnp_device.pnp_svl_member[local.pnp_svl_active_registration_key_by_name[each.key]].id
  device_type = "SVL"
  site_id     = var.use_bulk_api ? coalesce(local.site_id_list_bulk[each.value.site], local.data_source_created_sites_list[each.value.site]) : local.site_id_list[each.value.site]
  hostname    = try(each.value.name, each.value.fqdn_name, local.defaults.catalyst_center.pnp.devices.hostname, null)
  # Unlike the standard claim, this resource has no image_skip attribute, so
  # image_skip only selects whether image_id is sent at all.
  image_id            = try(each.value.image_skip, local.defaults.catalyst_center.pnp.devices.image_skip, true) ? null : try(each.value.image_id, local.image_name_to_id[each.value.image_name], local.defaults.catalyst_center.pnp.devices.image_id, null)
  template_id         = try(catalystcenter_template.regular_template[each.value.onboarding_template.name].id, catalystcenter_template.regular_template[local.template_name_to_key[each.value.onboarding_template.name]].id, data.catalystcenter_template.template[each.value.onboarding_template.name].id, data.catalystcenter_template.template[local.resource_key_to_template_key[each.value.onboarding_template.name]].id, data.catalystcenter_template.template[local.resource_key_to_template_key[local.template_name_to_key[each.value.onboarding_template.name]]].id, data.catalystcenter_template.unmanaged[each.value.onboarding_template.name].id, null)
  template_parameters = try(each.value.onboarding_template.variables, local.defaults.catalyst_center.onboarding_templates.variables, null)
  domain              = each.value.svl.domain

  svl_members = [
    for member in each.value.svl.members : {
      serial_number = member.serial_number
      role          = member.role
      svl_links = [
        for link in each.value.svl.svl_links : {
          local_interface  = member.role == "ACTIVE" ? link.active_interface : link.standby_interface
          remote_interface = member.role == "ACTIVE" ? link.standby_interface : link.active_interface
        }
      ]
      local_interface  = member.role == "ACTIVE" ? try(each.value.svl.dad_link.active_interface, null) : try(each.value.svl.dad_link.standby_interface, null)
      remote_interface = member.role == "ACTIVE" ? try(each.value.svl.dad_link.standby_interface, null) : try(each.value.svl.dad_link.active_interface, null)
    }
  ]

  depends_on = [catalystcenter_pnp_device.pnp_svl_member, catalystcenter_network_profile.switching_network_profile]
}
