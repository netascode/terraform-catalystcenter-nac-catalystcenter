data "catalystcenter_device_detail" "rma_device" {
  for_each = {
    for device in try(local.catalyst_center.inventory.devices, []) :
    device.name => device
    if(strcontains(device.state, "PROVISION") || device.state == "MARK_FOR_REPLACEMENT")
    && try(device.serial_number, null) != null
    && contains(local.sites, try(device.site, "NONE"))
    && (
      lookup(local.device_name_to_id, device.name, null) != null ||
      lookup(local.device_name_to_id, try(device.fqdn_name, ""), null) != null ||
      lookup(local.device_ip_to_id, try(device.device_ip, ""), null) != null
    )
  }

  id = coalesce(
    try(lookup(local.device_name_to_id, each.value.name, null), null),
    try(lookup(local.device_name_to_id, each.value.fqdn_name, null), null),
    try(lookup(local.device_ip_to_id, each.value.device_ip, null), null)
  )
}

resource "catalystcenter_device_replacement" "mark" {
  for_each = {
    for device in try(local.catalyst_center.inventory.devices, []) :
    device.name => device
    if device.state == "MARK_FOR_REPLACEMENT"
    && contains(local.sites, try(device.site, "NONE"))
    && (
      lookup(local.device_name_to_id, device.name, null) != null ||
      lookup(local.device_name_to_id, try(device.fqdn_name, ""), null) != null ||
      lookup(local.device_ip_to_id, try(device.device_ip, ""), null) != null
    )
  }

  faulty_device_id = coalesce(
    try(lookup(local.device_name_to_id, each.value.name, null), null),
    try(lookup(local.device_name_to_id, each.value.fqdn_name, null), null),
    try(lookup(local.device_ip_to_id, each.value.device_ip, null), null)
  )
  replacement_status = "MARKED-FOR-REPLACEMENT"

  depends_on = [data.catalystcenter_network_devices.all_devices]
}

resource "catalystcenter_device_replacement_workflow" "rma" {
  for_each = {
    for device in try(local.catalyst_center.inventory.devices, []) :
    device.name => device
    if strcontains(device.state, "PROVISION")
    && try(device.serial_number, null) != null
    && contains(local.sites, try(device.site, "NONE"))
    && try(data.catalystcenter_device_detail.rma_device[device.name].serial_number, null) != null
    && device.serial_number != data.catalystcenter_device_detail.rma_device[device.name].serial_number
  }

  faulty_device_serial_number      = data.catalystcenter_device_detail.rma_device[each.key].serial_number
  replacement_device_serial_number = each.value.serial_number

  depends_on = [data.catalystcenter_network_devices.all_devices, catalystcenter_device_replacement.mark]
}
