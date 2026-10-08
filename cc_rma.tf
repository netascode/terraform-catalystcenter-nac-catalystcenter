# RMA (Return Material Authorization) device replacement — 3-step workflow.
#
# Driven by the optional `rma` block on an inventory device; the device `state`
# stays `PROVISION` throughout, so none of the device's existing resources
# (provisioning, fabric roles, templates, port assignments) are torn down while
# a replacement is in flight. Every `for_each` key derives from static
# data-model values (device name + `rma.action`), so plan/`terraform import`
# never hit the "Invalid for_each argument" error that the previous
# state-driven design produced (netascode/nac-catalystcenter#530).
#
#   Step 1 — mark:    rma.action = MARK_FOR_REPLACEMENT
#   Step 2 — replace: rma.action = REPLACE, rma.replacement_serial_number = <new SN>
#   Step 3 — cleanup: remove the rma block (device is un-marked, back to normal)

resource "catalystcenter_device_replacement" "mark" {
  for_each = {
    for device in try(local.catalyst_center.inventory.devices, []) :
    device.name => device
    if contains(["MARK_FOR_REPLACEMENT", "REPLACE"], try(device.rma.action, "NONE"))
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
    if try(device.rma.action, "NONE") == "REPLACE"
    && try(device.rma.replacement_serial_number, null) != null
    && try(device.serial_number, null) != null
    && try(device.rma.replacement_serial_number, "") != try(device.serial_number, "")
    && contains(local.sites, try(device.site, "NONE"))
  }

  faulty_device_serial_number      = each.value.serial_number
  replacement_device_serial_number = each.value.rma.replacement_serial_number

  depends_on = [data.catalystcenter_network_devices.all_devices, catalystcenter_device_replacement.mark]
}
