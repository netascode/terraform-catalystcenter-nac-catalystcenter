locals {
  device_ip_to_id = try({
    for device in data.catalystcenter_network_devices.all_devices.devices :
    device.management_ip_address => device.id
  }, {})

  border_devices = { for device in try(local.catalyst_center.fabric.border_devices, []) : device.name => device }

  all_devices = {
    for device in try(local.catalyst_center.inventory.devices, []) : device.name => merge(device,
      {
        dayn_templates_map = merge(
          tomap({
            for template in try(device.dayn_templates.regular, []) : template.name => merge(template, { variables = try(template.variables, []) })
          }),
          tomap({
            for template in try(device.dayn_templates.composite, []) : template.name => merge(template, { variables = try(template.variables, []) })
          })
        )
      }
    )
  }

  l3_handoffs_ip_transit = flatten([
    for border_device in try(local.catalyst_center.fabric.border_devices, []) : [
      for transit in try(border_device.l3_handoffs, []) : [
        for vn in try(transit.virtual_networks) : {
          key                  = format("%s/%s/%s", vn.name, border_device.name, transit.name)
          transit_name         = try(transit.name, null)
          device_name          = try(border_device.name, null)
          device_ip            = try(local.all_devices[border_device.name].device_ip, null)
          interface_name       = try(transit.interface_name, null)
          virtual_network_name = try(vn.name, null)
          vlan_id              = try(vn.vlan, null)
          local_ip_address     = try(vn.local_ip_address, null)
          peer_ip_address      = try(vn.peer_ip_address, null)
          tcp_mss_adjustment   = try(vn.tcp_mss_adjustment, null)
        }
      ]
    ]
  ])

  l2_handoffs = flatten([
    for border_device in try(local.catalyst_center.fabric.border_devices, []) : [
      for vn in try(border_device.l2_handoffs.virtual_networks, []) : [
        for vlan in try(vn.vlans) : {
          key              = format("vlan%s/%s", vlan.external_vlan_id, border_device.name)
          device_name      = try(border_device.name, null)
          device_ip        = try(local.all_devices[border_device.name].device_ip, null)
          interface_name   = try(vn.interface_name, null)
          external_vlan_id = try(vlan.external_vlan_id, null)
          vlan_name        = try(vlan.vlan_name, null)
        }
      ]
    ]
  ])

  l2_handoff_vlan_id_map = {
    for item in local.anycast_gateways : item.vlan_name => catalystcenter_anycast_gateway.anycast_gateway[item.name].vlan_id if try(item.vlan_name, null) != null
  }
}

data "catalystcenter_network_devices" "all_devices" {
}

resource "catalystcenter_device_role" "role" {

  for_each = { for device in try(local.catalyst_center.inventory.devices, []) : device.name => device if strcontains(device.state, "PROVISION") }

  device_id   = lookup(local.device_ip_to_id, each.value.device_ip, "")
  role        = try(each.value.device_role, local.defaults.catalyst_center.inventory.devices.device_role, null)
  role_source = try(each.value.role_source, local.defaults.catalyst_center.inventory.devices.role_source, null)

  depends_on = [data.catalystcenter_network_devices.all_devices, catalystcenter_floor.floor, catalystcenter_building.building, catalystcenter_area.area_0, catalystcenter_area.area_1, catalystcenter_area.area_2]
}

resource "catalystcenter_fabric_provision_device" "border_device" {
  for_each = { for device in try(local.catalyst_center.inventory.devices, []) : device.name => device if strcontains(device.state, "PROVISION") && device.device_role == "BORDER ROUTER" }

  site_id           = try(local.site_id_list[each.value.site], null)
  network_device_id = lookup(local.device_ip_to_id, each.value.device_ip, "")
  reprovision       = try(each.value.state, null) == "REPROVISION" ? true : false

  depends_on = [catalystcenter_device_role.role]
}

resource "catalystcenter_fabric_device" "border_device" {
  for_each = { for device in try(local.catalyst_center.inventory.devices, []) : device.name => device if strcontains(device.state, "PROVISION") && device.device_role == "BORDER ROUTER" && try(device.fabric_roles, null) != null }

  network_device_id               = lookup(local.device_ip_to_id, each.value.device_ip, "")
  fabric_id                       = try(catalystcenter_fabric_site.fabric_site[each.value.fabric_site].id, null)
  device_roles                    = try(each.value.fabric_roles, local.defaults.catalyst_center.inventory.devices.fabric_roles, null)
  border_types                    = try(local.border_devices[each.key].border_types, local.defaults.catalyst_center.fabric.border_devices.border_types, null)
  local_autonomous_system_number  = try(local.border_devices[each.key].local_autonomous_system_number, local.defaults.catalyst_center.fabric.border_devices.local_autonomous_system_number, null)
  default_exit                    = try(local.border_devices[each.key].default_exit, local.defaults.catalyst_center.fabric.border_devices.default_exit, null)
  import_external_routes          = try(local.border_devices[each.key].import_external_routes, local.defaults.catalyst_center.fabric.border_devices.import_external_routes, null)
  border_priority                 = try(local.border_devices[each.key].border_priority, local.defaults.catalyst_center.fabric.border_devices.border_priority, null)
  prepend_autonomous_system_count = try(local.border_devices[each.key].prepend_autonomous_system_count, local.defaults.catalyst_center.fabric.border_devices.prepend_autonomous_system_count, null)

  depends_on = [catalystcenter_device_role.role, catalystcenter_fabric_provision_device.border_device]
}

resource "catalystcenter_fabric_l3_handoff_ip_transit" "l3_handoff_ip_transit" {
  for_each = { for handoff in local.l3_handoffs_ip_transit : handoff.key => handoff if strcontains(local.all_devices[handoff.device_name].state, "PROVISION") }

  network_device_id    = lookup(local.device_ip_to_id, each.value.device_ip, "")
  fabric_id            = try(catalystcenter_fabric_site.fabric_site[local.all_devices[each.value.device_name].fabric_site].id, null)
  transit_network_id   = try(catalystcenter_transit_network.transit[each.value.transit_name].id, null)
  interface_name       = try(each.value.interface_name, null)
  virtual_network_name = try(each.value.virtual_network_name, null)
  vlan_id              = try(each.value.vlan_id, null)
  tcp_mss_adjustment   = try(each.value.tcp_mss_adjustment, null)
  local_ip_address     = try(each.value.local_ip_address, null)
  remote_ip_address    = try(each.value.peer_ip_address, null)

  depends_on = [catalystcenter_fabric_device.border_device, catalystcenter_device_role.role, catalystcenter_fabric_l3_virtual_network.l3_vn, catalystcenter_fabric_site.fabric_site]
}

resource "catalystcenter_fabric_l2_handoff" "l2_handoff" {
  for_each = { for handoff in local.l2_handoffs : handoff.key => handoff if strcontains(local.all_devices[handoff.device_name].state, "PROVISION") }

  network_device_id = lookup(local.device_ip_to_id, each.value.device_ip, "")
  fabric_id         = try(catalystcenter_fabric_site.fabric_site[local.all_devices[each.value.device_name].fabric_site].id, null)
  interface_name    = try(each.value.interface_name, null)
  internal_vlan_id  = try(local.l2_handoff_vlan_id_map[each.value.vlan_name], null)
  external_vlan_id  = try(each.value.external_vlan_id, null)

  depends_on = [catalystcenter_fabric_device.border_device, catalystcenter_fabric_l3_virtual_network.l3_vn, catalystcenter_fabric_site.fabric_site]
}

resource "catalystcenter_wireless_device_provision" "wireless_controller" {
  for_each = { for device in try(local.catalyst_center.inventory.devices, []) : device.name => device if strcontains(device.state, "PROVISION") && contains(try(device.fabric_roles, []), "WIRELESS_CONTROLLER_NODE") }

  device_name          = each.key
  site                 = try(each.value.site, null)
  managed_ap_locations = try(each.value.managed_ap_locations, [each.value.site], null)

  depends_on = [catalystcenter_building.building, catalystcenter_floor.floor, catalystcenter_area.area_0, catalystcenter_area.area_1, catalystcenter_area.area_2]
}

resource "catalystcenter_fabric_device" "wireless_controller" {
  for_each = { for device in try(local.catalyst_center.inventory.devices, []) : device.name => device if strcontains(device.state, "PROVISION") && contains(try(device.fabric_roles, []), "WIRELESS_CONTROLLER_NODE") }

  network_device_id = lookup(local.device_ip_to_id, each.value.device_ip, "")
  fabric_id         = try(catalystcenter_fabric_site.fabric_site[each.value.fabric_site].id, null)
  device_roles      = try(each.value.fabric_roles, local.defaults.catalyst_center.inventory.devices.fabric_roles, null)

  depends_on = [catalystcenter_device_role.role, catalystcenter_fabric_provision_device.border_device, catalystcenter_wireless_device_provision.wireless_controller, catalystcenter_fabric_device.border_device]
}

resource "catalystcenter_fabric_provision_device" "edge_device" {
  for_each = { for device in try(local.catalyst_center.inventory.devices, []) : device.name => device if strcontains(device.state, "PROVISION") && device.device_role == "ACCESS" && (try(contains(device.fabric_roles, "EDGE_NODE"), null) != null || try(device.fabric_site, null) == null) }

  site_id           = try(local.site_id_list[each.value.site], null)
  network_device_id = try(local.device_ip_to_id[each.value.device_ip], "")
  reprovision       = try(each.value.state, null) == "REPROVISION" ? true : false

  depends_on = [catalystcenter_device_role.role, catalystcenter_fabric_provision_device.border_device]
}

resource "catalystcenter_fabric_device" "edge_device" {
  for_each = { for device in try(local.catalyst_center.inventory.devices, []) : device.name => device if strcontains(device.state, "PROVISION") && device.device_role == "ACCESS" && try(contains(device.fabric_roles, "EDGE_NODE"), null) != null }

  network_device_id = try(local.device_ip_to_id[each.value.device_ip], "")
  fabric_id         = try(catalystcenter_fabric_site.fabric_site[each.value.fabric_site].id, null)
  device_roles      = try(each.value.fabric_roles, local.defaults.catalyst_center.inventory.devices.fabric_roles, null)

  depends_on = [catalystcenter_device_role.role, catalystcenter_fabric_provision_device.edge_device, catalystcenter_fabric_device.border_device]
}

# Resolve port assignment interfaces range to interfaces list
locals {
  device_port_assignments = {
    for device in try(local.catalyst_center.inventory.devices, []) : device.name => flatten([
      for assignment in device.port_assignments : (
        try(assignment.interfaces_range, null) != null ? [
          for z in range(
            tonumber(regex("([0-9]+)$", split("-", assignment.interfaces_range)[0])[0]),
            tonumber(regex("([0-9]+)$", split("-", assignment.interfaces_range)[1])[0]) + 1
            ) : {
            interface_name             = format("%s/%s", regex("(^[A-Za-z]+[0-9]+/[0-9]+)", split("-", assignment.interfaces_range)[0])[0], z)
            connected_device_type      = try(assignment.connected_device_type, local.defaults.catalyst_center.inventory.devices.port_assignments.connected_device_type, null)
            data_vlan_name             = try(assignment.data_vlan_name, local.defaults.catalyst_center.inventory.devices.port_assignments.data_vlan_name, null)
            voice_vlan_name            = try(assignment.voice_vlan_name, local.defaults.catalyst_center.inventory.devices.port_assignments.voice_vlan_name, null)
            authenticate_template_name = try(assignment.authenticate_template_name, local.defaults.catalyst_center.inventory.devices.port_assignments.authenticate_template_name, null)
            network_device_id          = try(local.device_ip_to_id[device.device_ip], "")
            fabric_id                  = try(local.fabric_site_id_list[device.fabric_site], null)
          }
          ] : [
          {
            interface_name             = assignment.interface_name
            connected_device_type      = try(assignment.connected_device_type, local.defaults.catalyst_center.inventory.devices.port_assignments.connected_device_type, null)
            data_vlan_name             = try(assignment.data_vlan_name, local.defaults.catalyst_center.inventory.devices.port_assignments.data_vlan_name, null)
            voice_vlan_name            = try(assignment.voice_vlan_name, local.defaults.catalyst_center.inventory.devices.port_assignments.voice_vlan_name, null)
            authenticate_template_name = try(assignment.authenticate_template_name, local.defaults.catalyst_center.inventory.devices.port_assignments.authenticate_template_name, null)
            network_device_id          = try(local.device_ip_to_id[device.device_ip], "")
            fabric_id                  = try(local.fabric_site_id_list[device.fabric_site], null)
          }
        ]
      )
    ]) if try(device.port_assignments, null) != null
  }
}

resource "catalystcenter_fabric_port_assignment" "port_assignments" {
  for_each = { for device in try(local.catalyst_center.inventory.devices, []) : device.name => device if strcontains(device.state, "PROVISION") && try(contains(device.fabric_roles, "EDGE_NODE"), null) != null && try(device.port_assignments, null) != null }

  fabric_id         = try(catalystcenter_fabric_site.fabric_site[each.value.fabric_site].id, null)
  network_device_id = try(local.device_ip_to_id[each.value.device_ip], "")
  port_assignments  = try(local.device_port_assignments[each.key], null)

  depends_on = [catalystcenter_fabric_device.edge_device, catalystcenter_fabric_device.border_device, catalystcenter_fabric_provision_device.edge_device, catalystcenter_fabric_provision_device.edge_device, catalystcenter_anycast_gateway.anycast_gateway]
}
