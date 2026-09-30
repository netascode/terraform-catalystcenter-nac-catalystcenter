data "catalystcenter_images" "all_images" {
}

locals {
  image_name_to_id = {
    for name, images in {
      for image in coalesce(data.catalystcenter_images.all_images.images, []) : image.name => image...
    } : name => images[0].id
  }

  pnp_managed_devices = {
    for device in try(local.catalyst_center.inventory.devices, []) : device.name => device
    if device.state == "PNP" && contains(local.sites, try(device.site, "NONE"))
  }

  pnp_standard_devices = { for name, device in local.pnp_managed_devices : name => device if try(device.svl, null) == null }
  pnp_svl_devices      = { for name, device in local.pnp_managed_devices : name => device if try(device.svl, null) != null }

  pnp_svl_member_registrations = merge([
    for name, device in local.pnp_svl_devices : {
      for member in device.svl.members : "${name}::${member.serial_number}" => {
        device_name   = name
        serial_number = member.serial_number
        pid           = try(device.pid, null)
      }
    }
  ]...)

  pnp_svl_active_registration_key_by_name = {
    for name, device in local.pnp_svl_devices : name => "${name}::${[for m in device.svl.members : m.serial_number if m.role == "ACTIVE"][0]}"
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
  type                       = length(split(",", each.value.serial_number)) > 1 ? "StackSwitch" : try(each.value.type, local.defaults.catalyst_center.pnp.devices.type, null)
  hostname                   = try(each.value.name, each.value.fqdn_name, local.defaults.catalyst_center.pnp.devices.hostname, null)
  rf_profile                 = try(each.value.rf_profile, local.defaults.catalyst_center.pnp.devices.rf_profile, null)
  image_id                   = try(each.value.image_id, local.image_name_to_id[each.value.image_name], local.defaults.catalyst_center.pnp.devices.image_id, length(split(",", each.value.serial_number)) > 1 ? "" : null)
  image_skip                 = try(each.value.image_skip, local.defaults.catalyst_center.pnp.devices.image_skip, null)
  config_id                  = try(catalystcenter_template.regular_template[each.value.onboarding_template.name].id, catalystcenter_template.regular_template[local.template_name_to_key[each.value.onboarding_template.name]].id, data.catalystcenter_template.template[each.value.onboarding_template.name].id, data.catalystcenter_template.template[local.resource_key_to_template_key[each.value.onboarding_template.name]].id, data.catalystcenter_template.template[local.resource_key_to_template_key[local.template_name_to_key[each.value.onboarding_template.name]]].id, data.catalystcenter_template.unmanaged[each.value.onboarding_template.name].id, length(split(",", each.value.serial_number)) > 1 ? "" : null)
  config_parameters          = try(each.value.onboarding_template.variables, local.defaults.catalyst_center.onboarding_templates.variables, null)
  top_of_stack_serial_number = try(each.value.stack.top_of_stack_serial_number, null)
  cabling_scheme             = try(each.value.stack.cabling_scheme, local.defaults.catalyst_center.pnp.devices.cabling_scheme, null)

  depends_on = [catalystcenter_network_profile.switching_network_profile]
}

resource "catalystcenter_pnp_config_preview" "config_preview" {
  for_each = { for name, device in local.pnp_standard_devices : name => device if try(device.type, local.defaults.catalyst_center.pnp.devices.type, "Default") != "AccessPoint" }

  device_id = catalystcenter_pnp_device.pnp_device[each.key].id
  site_id   = var.use_bulk_api ? coalesce(local.site_id_list_bulk[each.value.site], local.data_source_created_sites_list[each.value.site]) : local.site_id_list[each.value.site]
  type      = length(split(",", each.value.serial_number)) > 1 ? "StackSwitch" : try(each.value.type, local.defaults.catalyst_center.pnp.devices.type, null)

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

  device_id           = catalystcenter_pnp_device.pnp_svl_member[local.pnp_svl_active_registration_key_by_name[each.key]].id
  device_type         = "SVL"
  site_id             = var.use_bulk_api ? coalesce(local.site_id_list_bulk[each.value.site], local.data_source_created_sites_list[each.value.site]) : local.site_id_list[each.value.site]
  hostname            = try(each.value.name, each.value.fqdn_name, local.defaults.catalyst_center.pnp.devices.hostname, null)
  image_id            = try(each.value.image_id, local.image_name_to_id[each.value.image_name], local.defaults.catalyst_center.pnp.devices.image_id, null)
  remove_inactive     = try(each.value.image_skip, local.defaults.catalyst_center.pnp.devices.image_skip, null)
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
