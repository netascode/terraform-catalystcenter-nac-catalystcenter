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

  pnp_device_types = {
    for name, device in local.pnp_devices : name => (
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
  for_each = { for device in try(local.catalyst_center.inventory.devices, []) : device.name => device if device.state == "PNP" && contains(local.sites, try(device.site, "NONE")) }

  serial_number = split(",", each.value.serial_number)[0]
  hostname      = each.value.name
  pid           = each.value.pid
  stack         = length(split(",", each.value.serial_number)) > 1 ? true : null

  lifecycle {
    ignore_changes = [hostname]
  }
}

resource "catalystcenter_pnp_device_claim_site" "claim_device" {
  for_each = { for device in try(local.catalyst_center.inventory.devices, []) : device.name => device if device.state == "PNP" && contains(local.sites, try(device.site, "NONE")) }

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
  # type, so there is no preview to request for them.
  for_each = { for device in try(local.catalyst_center.inventory.devices, []) : device.name => device if device.state == "PNP" && contains(local.sites, try(device.site, "NONE")) && try(device.type, local.defaults.catalyst_center.pnp.devices.type, "Default") != "AccessPoint" && !contains(keys(local.pnp_wireless_controllers), device.name) }

  device_id = catalystcenter_pnp_device.pnp_device[each.key].id
  site_id   = var.use_bulk_api ? coalesce(local.site_id_list_bulk[each.value.site], local.data_source_created_sites_list[each.value.site]) : local.site_id_list[each.value.site]
  type      = local.pnp_device_types[each.key]

  depends_on = [catalystcenter_pnp_device_claim_site.claim_device]
}
