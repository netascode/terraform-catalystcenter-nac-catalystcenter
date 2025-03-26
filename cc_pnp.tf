locals {
  # onboarding_template_sites = {
  #   for v in flatten([
  #     for profile in try(local.catalyst_center.network_profiles.switching, []) : [
  #       for template in try(profile.onboarding_templates, []) : [
  #         for site in profile.sites : {
  #           "onboarding_template" : try(template, null)
  #           "site" : try(site, null)
  #         }
  #     ]]
  # ]) : v.site => v }

  pnp_devices = [
    for device in try(local.catalyst_center.inventory.devices, []) : {
      "serial_number" : try(device.serial_number, null)
      "hostname" : try(device.name, null)
      "pid" : try(device.pid, null)
    } if device.state == "PNP"
  ]
}

resource "catalystcenter_pnp_import_devices" "pnp_devices" {
  count   = length(local.pnp_devices) != 0 ? 1 : 0
  devices = local.pnp_devices
}

data "catalystcenter_pnp_device" "pnp_device" {
  for_each = { for device in try(local.catalyst_center.inventory.devices, []) : device.name => device if device.state == "PNP" }

  serial_number = each.value.serial_number

  depends_on = [catalystcenter_pnp_import_devices.pnp_devices]
}

resource "catalystcenter_pnp_device_claim_site" "claim_device" {
  for_each = { for device in try(local.catalyst_center.inventory.devices, []) : device.name => device if device.state == "PNP" }

  device_id         = data.catalystcenter_pnp_device.pnp_device[each.key].id
  site_id           = local.site_id_list[each.value.site]
  type              = try(each.value.type, local.defaults.catalyst_center.pnp.devices.type, null)
  image_id          = try(each.value.image_id, local.defaults.catalyst_center.pnp.devices.image_id, null)
  image_skip        = try(each.value.image_skip, local.defaults.catalyst_center.pnp.devices.image_skip, null)
  config_id         = try(catalystcenter_template.regular_template[keys(each.value.onboarding_templates.regular)[0]].id, null)
  config_parameters = try(each.value.onboarding_templates.regular[keys(each.value.onboarding_templates.regular)[0]].variables, local.defaults.catalyst_center.onboarding_templates.variables, null)

  depends_on = [catalystcenter_network_profile.switching_network_profile]
}

resource "catalystcenter_pnp_config_preview" "config_preview" {
  for_each = { for device in try(local.catalyst_center.inventory.devices, []) : device.name => device if device.state == "PNP" }

  device_id = data.catalystcenter_pnp_device.pnp_device[each.key].id
  site_id   = local.site_id_list[each.value.site]
  type      = try(each.value.type, local.defaults.catalyst_center.pnp.devices.type, null)

  depends_on = [catalystcenter_pnp_device_claim_site.claim_device]
}