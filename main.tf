locals {
  # Name-keyed map of every nested fabric device. Feeds the fabric_roles fold.
  fabric_devices_by_name = {
    for entry in flatten([
      for fabric_site in try(local.model.catalyst_center.fabric.fabric_sites, []) : [
        for fabric_device in try(fabric_site.fabric_devices, []) : fabric_device
      ]
    ]) : entry.name => entry
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
    {
      inventory = merge(
        try(local.model.catalyst_center.inventory, {}),
        {
          devices = [
            for device in try(local.model.catalyst_center.inventory.devices, []) :
            merge(
              device,
              { for k, v in try(local.fabric_devices_by_name[device.name], {}) :
                k => v if k == "fabric_roles"
              },
            )
          ]
        }
      )
    },
  )
}
