
locals {
  rma_devices = {
    for device in try(local.catalyst_center.inventory.devices, []) :
    device.name => {
      state         = try(device.state, "")
      serial_number = try(device.serial_number, null)
      faulty_device_id = coalesce(
        try(lookup(local.device_name_to_id, device.name, null), null),
        try(lookup(local.device_name_to_id, try(device.fqdn_name, ""), null), null),
        try(lookup(local.device_ip_to_id, try(device.device_ip, ""), null), null),
      )
    }
    if try(device.state, "") == "MARK_FOR_REPLACEMENT"
    && contains(local.sites, try(device.site, "NONE"))
    && (
      lookup(local.device_name_to_id, device.name, null) != null ||
      lookup(local.device_name_to_id, try(device.fqdn_name, ""), null) != null ||
      lookup(local.device_ip_to_id, try(device.device_ip, ""), null) != null
    )
  }
}

resource "catalystcenter_device_replacement" "mark" {
  for_each = local.rma_devices

  faulty_device_id = each.value.faulty_device_id
  inventory_state  = each.value.state

  depends_on = [data.catalystcenter_network_devices.all_devices]
}

resource "catalystcenter_device_replacement_workflow" "rma" {
  for_each = local.rma_devices

  faulty_device_id                 = each.value.faulty_device_id
  replacement_device_serial_number = each.value.serial_number

  depends_on = [data.catalystcenter_network_devices.all_devices, catalystcenter_device_replacement.mark]
}
