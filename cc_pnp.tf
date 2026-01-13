resource "catalystcenter_pnp_device" "pnp_device" {
  for_each = { for device in try(local.catalyst_center.inventory.devices, []) : device.name => device if device.state == "PNP" && contains(local.sites, try(device.site, "NONE")) }

  serial_number = each.value.serial_number
  hostname      = each.value.name
  pid           = each.value.pid

  lifecycle {
    ignore_changes = [hostname]
  }
}

resource "catalystcenter_pnp_device_claim_site" "claim_device" {
  for_each = { for device in try(local.catalyst_center.inventory.devices, []) : device.name => device if device.state == "PNP" && contains(local.sites, try(device.site, "NONE")) && (var.use_bulk_api ? try(local.site_id_list_bulk[device.site], null) != null : try(local.site_id_list[device.site], null) != null) }

  device_id         = catalystcenter_pnp_device.pnp_device[each.key].id
  site_id           = var.use_bulk_api ? local.site_id_list_bulk[each.value.site] : local.site_id_list[each.value.site]
  type              = try(each.value.type, local.defaults.catalyst_center.pnp.devices.type, null)
  rf_profile        = try(each.value.rf_profile, local.defaults.catalyst_center.pnp.devices.rf_profile, null)
  image_id          = try(each.value.image_id, local.defaults.catalyst_center.pnp.devices.image_id, null)
  image_skip        = try(each.value.image_skip, local.defaults.catalyst_center.pnp.devices.image_skip, null)
  config_id         = try(catalystcenter_template.regular_template[each.value.onboarding_template.name].id, data.catalystcenter_template.template[each.value.onboarding_template.name].id, null)
  config_parameters = try(each.value.onboarding_template.variables, local.defaults.catalyst_center.onboarding_templates.variables, null)

  depends_on = [catalystcenter_network_profile.switching_network_profile]
}

resource "catalystcenter_pnp_config_preview" "config_preview" {
  for_each = { for device in try(local.catalyst_center.inventory.devices, []) : device.name => device if device.state == "PNP" && contains(local.sites, try(device.site, "NONE")) && try(device.type, local.defaults.catalyst_center.pnp.devices.type, "Default") != "AccessPoint" && (var.use_bulk_api ? try(local.site_id_list_bulk[device.site], null) != null : try(local.site_id_list[device.site], null) != null) }

  device_id = catalystcenter_pnp_device.pnp_device[each.key].id
  site_id   = var.use_bulk_api ? local.site_id_list_bulk[each.value.site] : local.site_id_list[each.value.site]
  type      = try(each.value.type, local.defaults.catalyst_center.pnp.devices.type, null)

  depends_on = [catalystcenter_pnp_device_claim_site.claim_device]
}