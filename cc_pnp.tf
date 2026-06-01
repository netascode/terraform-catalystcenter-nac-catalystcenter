data "catalystcenter_images" "all_images" {
}

locals {
  image_name_to_id = try({
    for image in data.catalystcenter_images.all_images.images : image.name => image.id
  }, {})
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
  type                       = length(split(",", each.value.serial_number)) > 1 ? "StackSwitch" : try(each.value.type, local.defaults.catalyst_center.pnp.devices.type, null)
  rf_profile                 = try(each.value.rf_profile, local.defaults.catalyst_center.pnp.devices.rf_profile, null)
  image_id                   = try(each.value.image_id, local.image_name_to_id[each.value.image_name], local.defaults.catalyst_center.pnp.devices.image_id, length(split(",", each.value.serial_number)) > 1 ? "" : null)
  image_skip                 = try(each.value.image_skip, local.defaults.catalyst_center.pnp.devices.image_skip, null)
  config_id                  = try(catalystcenter_template.regular_template[each.value.onboarding_template.name].id, catalystcenter_template.regular_template[local.template_name_to_key[each.value.onboarding_template.name]].id, data.catalystcenter_template.template[each.value.onboarding_template.name].id, data.catalystcenter_template.template[local.resource_key_to_template_key[each.value.onboarding_template.name]].id, data.catalystcenter_template.template[local.resource_key_to_template_key[local.template_name_to_key[each.value.onboarding_template.name]]].id, length(split(",", each.value.serial_number)) > 1 ? "" : null)
  config_parameters          = try(each.value.onboarding_template.variables, local.defaults.catalyst_center.onboarding_templates.variables, null)
  top_of_stack_serial_number = try(each.value.stack.top_of_stack_serial_number, null)
  cabling_scheme             = try(each.value.stack.cabling_scheme, local.defaults.catalyst_center.pnp.devices.cabling_scheme, null)

  depends_on = [catalystcenter_network_profile.switching_network_profile]
}

resource "catalystcenter_pnp_config_preview" "config_preview" {
  for_each = { for device in try(local.catalyst_center.inventory.devices, []) : device.name => device if device.state == "PNP" && contains(local.sites, try(device.site, "NONE")) && try(device.type, local.defaults.catalyst_center.pnp.devices.type, "Default") != "AccessPoint" }

  device_id = catalystcenter_pnp_device.pnp_device[each.key].id
  site_id   = var.use_bulk_api ? coalesce(local.site_id_list_bulk[each.value.site], local.data_source_created_sites_list[each.value.site]) : local.site_id_list[each.value.site]
  type      = length(split(",", each.value.serial_number)) > 1 ? "StackSwitch" : try(each.value.type, local.defaults.catalyst_center.pnp.devices.type, null)

  depends_on = [catalystcenter_pnp_device_claim_site.claim_device]
}
