locals {
  # Companion versions are scoped to the device, deployment template and member.
  # Regular templates keep their existing single parameter namespace.
  template_variable_groups = {
    for device_name, device in local.all_devices : device_name => {
      for template_key, template in device.dayn_templates_map : template_key => {
        for item in template.variables :
        (try(local.template_lookup_extended[template_key].composite, false) ? try(item.template_name, "") : "") => item...
      }
    }
  }

  template_parameters = {
    for device_name, templates in local.template_variable_groups : device_name => {
      for template_key, members in templates : template_key => {
        for member_name, variables in members : member_name => {
          params = {
            for item in variables : item.name => try(tolist(item.value), [item.value])
            if !contains([for variable in variables : variable.name], "${item.name}_version") &&
            !(endswith(item.name, "_version") && contains([for variable in variables : variable.name], trimsuffix(item.name, "_version")))
          }
          params_wo = {
            for item in variables : item.name => try(tolist(item.value), [item.value])
            if contains([for variable in variables : variable.name], "${item.name}_version")
          }
          params_wo_versions = {
            for item in variables : trimsuffix(item.name, "_version") => item.value
            if endswith(item.name, "_version") && contains([for variable in variables : variable.name], trimsuffix(item.name, "_version"))
          }
        }
      }
    }
  }

  ambiguous_template_secret_versions = flatten([
    for device_name, templates in local.template_parameters : [
      for template_key, members in templates : [
        for member_name, parameters in members : [
          for name in keys(parameters.params_wo) : name
          if endswith(name, "_version") && contains(keys(parameters.params_wo_versions), trimsuffix(name, "_version"))
        ]
      ]
    ]
  ])

  regular_template_version_ids = {
    for key, template in local.templates_map : key => try(
      catalystcenter_template_version.regular_commit_version[key].id,
      [for v in data.catalystcenter_template_versions.template_versions[try(local.resource_key_to_template_key[key], key)].template_versions : v.id if v.version == tostring(max([for ver in data.catalystcenter_template_versions.template_versions[try(local.resource_key_to_template_key[key], key)].template_versions : ver.version != null ? tonumber(ver.version) : 0]...))][0],
      data.catalystcenter_template.template[try(local.resource_key_to_template_key[key], key)].id
    ) if !try(template.composite, false)
  }

  unmanaged_member_version_ids = {
    for id in local.unmanaged_composite_member_ids : id => try(
      [for v in data.catalystcenter_template_versions.unmanaged_member[id].template_versions : v.id if v.version == tostring(max([for ver in data.catalystcenter_template_versions.unmanaged_member[id].template_versions : ver.version != null ? tonumber(ver.version) : 0]...))][0],
      id
    )
  }

  # Omit empty secret inputs so existing deployment state stays unchanged on upgrade.
  regular_template_secret_params = {
    for template_key, devices in local.templates_by_device : template_key => [
      for device in devices : {
        target_id = coalesce(
          try(lookup(local.device_name_to_id, device.device_name, null), null),
          try(lookup(local.device_name_to_id, device.fqdn_name, null), null),
          try(lookup(local.device_ip_to_id, device.device_ip, null), null)
        )
        params_wo          = sensitive(local.template_parameters[device.name][device.template][""].params_wo)
        params_wo_versions = local.template_parameters[device.name][device.template][""].params_wo_versions
      } if strcontains(device.state, "PROVISION") && contains(local.sites, try(device.site, "NONE")) &&
      length(try(local.template_parameters[device.name][device.template][""].params_wo_versions, {})) > 0
    ]
    if try(local.template_lookup_extended[template_key].composite, false) == false &&
    try(local.template_lookup_extended[template_key].template_type, null) == "dayn" &&
    length([for d in devices : d if(strcontains(d.state, "PROVISION")) && contains(local.sites, try(d.site, "NONE"))]) > 0
  }

  managed_composite_secret_params = {
    for template_key, devices in local.templates_by_device : template_key => flatten([
      for tmpl in local.composite_templates_lookup[template_key] : [
        for device in devices : {
          target_id = coalesce(
            try(lookup(local.device_name_to_id, device.device_name, null), null),
            try(lookup(local.device_name_to_id, device.fqdn_name, null), null),
            try(lookup(local.device_ip_to_id, device.device_ip, null), null)
          )
          member_template_id = local.regular_template_version_ids[tmpl]
          params_wo          = sensitive(local.template_parameters[device.name][device.template][local.templates_map[tmpl].template_name].params_wo)
          params_wo_versions = local.template_parameters[device.name][device.template][local.templates_map[tmpl].template_name].params_wo_versions
        } if strcontains(device.state, "PROVISION") && contains(local.sites, try(device.site, "NONE")) &&
        length(try(local.template_parameters[device.name][device.template][local.templates_map[tmpl].template_name].params_wo_versions, {})) > 0
      ]
    ])
    if try(local.template_lookup[template_key].composite, false) == true &&
    local.template_lookup[template_key].template_type == "dayn" &&
    length([for d in devices : d if(strcontains(d.state, "PROVISION")) && contains(local.sites, try(d.site, "NONE"))]) > 0
  }

  discovered_composite_secret_params = {
    for template_key, devices in local.templates_by_device : template_key => flatten([
      for member in try(data.catalystcenter_template.unmanaged[template_key].containing_templates, []) : [
        for device in devices : {
          target_id = coalesce(
            try(lookup(local.device_name_to_id, device.device_name, null), null),
            try(lookup(local.device_name_to_id, device.fqdn_name, null), null),
            try(lookup(local.device_ip_to_id, device.device_ip, null), null)
          )
          member_template_id = local.unmanaged_member_version_ids[member.id]
          params_wo          = sensitive(local.template_parameters[device.name][device.template][member.name].params_wo)
          params_wo_versions = local.template_parameters[device.name][device.template][member.name].params_wo_versions
        } if strcontains(device.state, "PROVISION") && contains(local.sites, try(device.site, "NONE")) &&
        length(try(local.template_parameters[device.name][device.template][member.name].params_wo_versions, {})) > 0
      ]
    ])
    if contains(local.unmanaged_composite_keys, template_key) &&
    length([for d in devices : d if(strcontains(d.state, "PROVISION")) && contains(local.sites, try(d.site, "NONE"))]) > 0
  }

  # Keep the public model output useful without exporting write-only values.
  exported_inventory_devices = [
    for device in try(local.catalyst_center.inventory.devices, []) : merge(device,
      try(device.dayn_templates, null) == null ? {} : {
        dayn_templates = merge(device.dayn_templates, {
          for kind, templates in device.dayn_templates : kind => [
            for template in templates : merge(template,
              try(template.variables, null) == null ? {} : {
                variables = [
                  for item in template.variables : merge(item,
                    contains(keys(try(local.template_parameters[device.name][try("${template.project_name}#${template.name}", template.name)][kind == "composite" ? try(item.template_name, "") : ""].params_wo_versions, {})), item.name) ? { value = null } : {}
                  )
                ]
              }
            )
          ] if contains(["regular", "composite"], kind)
        })
      }
    )
  ]

  exported_model = merge(local.model,
    try(local.catalyst_center.inventory.devices, null) == null ? {} : {
      catalyst_center = merge(local.catalyst_center, {
        inventory = merge(local.catalyst_center.inventory, { devices = local.exported_inventory_devices })
      })
    }
  )
}
