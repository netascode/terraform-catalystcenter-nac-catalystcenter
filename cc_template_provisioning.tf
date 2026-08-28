locals {
  # Index inventory devices by name for metadata resolution.
  tp_inventory_by_name = {
    for device in try(local.catalyst_center.inventory.devices, []) :
    device.name => device
  }

  # All template_provisioning blocks tagged by kind. dayn + onboarding deploy as
  # regular templates; composite deploys through the composite path. `_composite`
  # mirrors the section-derived routing the inventory path uses.
  tp_template_blocks = concat(
    [for t in try(local.catalyst_center.template_provisioning.dayn_templates, []) : merge(t, { _composite = false })],
    [for t in try(local.catalyst_center.template_provisioning.onboarding_templates, []) : merge(t, { _composite = false })],
    [for t in try(local.catalyst_center.template_provisioning.composite_templates, []) : merge(t, { _composite = true })],
  )

  # Flatten to per-(template, device) tuples in the EXACT `combined_templates`
  # shape (cc_templates.tf:164) consumed by local.templates_by_device -> deploy
  # resources. `template` uses the project#name key form (template_provisioning
  # always supplies both), matching combined_templates and dayn_templates_map keys.
  provisioning_combined_templates = flatten([
    for block in local.tp_template_blocks : [
      for device in try(block.devices, []) : {
        "template"            = "${block.project_name}#${block.template_name}"
        "template_name"       = block.template_name
        "name"                = device.name
        "state"               = try(local.tp_inventory_by_name[device.name].state, null)
        "site"                = try(local.tp_inventory_by_name[device.name].site, null)
        "device_ip"           = try(local.tp_inventory_by_name[device.name].device_ip, null)
        "device_name"         = device.name
        "redeploy_template"   = try(device.redeploy_template, block.redeploy_template, local.defaults.catalyst_center.template_provisioning.redeploy_template, local.defaults.catalyst_center.templates.redeploy_template, null)
        "fqdn_name"           = try(local.tp_inventory_by_name[device.name].fqdn_name, null)
        "copying_config"      = try(device.copying_config, block.copying_config, local.defaults.catalyst_center.templates.copying_config, null)
        "force_push_template" = try(device.force_push_template, block.force_push_template, local.defaults.catalyst_center.templates.force_push_template, null)
      }
    ]
  ])

  provisioning_dayn_template_keys = distinct(concat(
    [for t in try(local.catalyst_center.template_provisioning.dayn_templates, []) : "${t.project_name}#${t.template_name}"],
    [for t in try(local.catalyst_center.template_provisioning.onboarding_templates, []) : "${t.project_name}#${t.template_name}"],
  ))

  provisioning_composite_template_keys = distinct([
    for t in try(local.catalyst_center.template_provisioning.composite_templates, []) : "${t.project_name}#${t.template_name}"
  ])

  provisioning_dayn_templates_map_by_device = {
    for device_name in distinct([for e in local.provisioning_combined_templates : e.device_name]) :
    device_name => {
      for block in local.tp_template_blocks :
      "${block.project_name}#${block.template_name}" => {
        name                = block.template_name
        variables           = try(one([for d in block.devices : d.variables if d.name == device_name && try(d.variables, null) != null]), [])
        copying_config      = try(one([for d in block.devices : d.copying_config if d.name == device_name && try(d.copying_config, null) != null]), null)
        force_push_template = try(one([for d in block.devices : d.force_push_template if d.name == device_name && try(d.force_push_template, null) != null]), null)
      }
      if anytrue([for d in try(block.devices, []) : d.name == device_name])
    }
    if contains(keys(local.tp_inventory_by_name), device_name)
  }
}

