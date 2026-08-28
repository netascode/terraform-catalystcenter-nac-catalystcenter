# Data-model normalization: rewrites the new nested data model into the flat
# shape every cc_*.tf reader expects. Result local.catalyst_center is consumed
# module-wide (Terraform merges all .tf files into one namespace, so where a
# local lives is organizational only).
locals {
  # Flatten fabric_sites[].fabric_devices[] into a name-keyed map, stamping each
  # device with its parent fabric_site. Feeds the inventory/border folds below.
  fabric_devices_by_name = {
    for entry in flatten([
      for fabric_site in try(local.model.catalyst_center.fabric.fabric_sites, []) : [
        for fabric_device in try(fabric_site.fabric_devices, []) : merge(
          fabric_device,
          { fabric_site = fabric_site.name }
        )
      ]
    ]) : entry.name => entry
  }

  # Split the nested port_assignments:{interfaces,port_channels} object into the
  # two flat lists cc_fabric.tf reads (device.port_assignments, device.port_channels).
  fabric_device_ports_by_name = {
    for name, fabric_device in local.fabric_devices_by_name : name => {
      port_assignments = try(fabric_device.port_assignments.interfaces, [])
      port_channels    = try(fabric_device.port_assignments.port_channels, [])
    }
    if try(fabric_device.port_assignments, null) != null
  }

  catalyst_center = merge(
    try(local.model.catalyst_center, {}),
    # design.network_profiles -> top-level network_profiles
    { network_profiles = try(local.model.catalyst_center.design.network_profiles, {}) },
    # cli_templates -> top-level templates
    { templates = try(local.model.catalyst_center.cli_templates, {}) },
    # cli_templates.feature_templates -> top-level feature_templates
    { feature_templates = try(local.model.catalyst_center.cli_templates.feature_templates, {}) },
    # fabric.authentication_templates -> top-level authentication_templates
    { authentication_templates = try(local.model.catalyst_center.fabric.authentication_templates, []) },
    # Fold device-level fabric fields (fabric_roles/fabric_site/fabric_zone + reshaped
    # ports) from fabric_devices[] back onto matching inventory.devices[] by name.
    # Unreferenced devices merge with {} and pass through unchanged.
    {
      inventory = merge(
        try(local.model.catalyst_center.inventory, {}),
        {
          devices = [
            for device in try(local.model.catalyst_center.inventory.devices, []) :
            merge(
              device,
              { for k, v in try(local.fabric_devices_by_name[device.name], {}) :
                k => v if contains(["fabric_roles", "fabric_site", "fabric_zone"], k)
              },
              try(local.fabric_device_ports_by_name[device.name], {})
            )
          ]
        }
      )
    },
    # Synthesize fabric.border_devices[] from border-bearing fabric_devices[]
    # (those carrying border_types/l3_handoffs/l2_handoffs/sda_transit).
    # Remap l3_handoffs[].ip_transit_name -> name for the cc_fabric.tf read path.
    {
      fabric = merge(
        try(local.model.catalyst_center.fabric, {}),
        {
          border_devices = concat(
            try(local.model.catalyst_center.fabric.border_devices, []),
            [
              for fabric_device in values(local.fabric_devices_by_name) :
              merge(
                fabric_device,
                {
                  l3_handoffs = [
                    for handoff in try(fabric_device.l3_handoffs, []) :
                    merge(handoff, { name = try(handoff.ip_transit_name, handoff.name, null) })
                  ]
                }
              )
              if try(fabric_device.border_types, null) != null ||
              try(fabric_device.l3_handoffs, null) != null ||
              try(fabric_device.l2_handoffs, null) != null ||
              try(fabric_device.sda_transit, null) != null
            ]
          )
        }
      )
    }
  )
}
