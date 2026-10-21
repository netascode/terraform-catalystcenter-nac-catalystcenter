locals {
  # Redact raw input lists, not normalized deployments: unused and overridden
  # inputs must not expose marked secrets either. Keep the public model's shape.
  # Composite companion markers belong to the same member template.
  exported_inventory_devices = [
    for device in try(local.raw_catalyst_center.inventory.devices, []) : merge(device,
      try(device.dayn_templates, null) == null ? {} : {
        dayn_templates = merge(device.dayn_templates, {
          for kind, templates in device.dayn_templates : kind => [
            for template in templates : merge(template,
              try(template.variables, null) == null ? {} : {
                variables = [
                  for item in template.variables : merge(item, {
                    value = contains([
                      for companion in template.variables : companion.name
                      if kind != "composite" || try(companion.template_name, "") == try(item.template_name, "")
                    ], "${item.name}_version_secure") ? null : item.value
                  })
                ]
              }
            )
          ] if contains(["regular", "composite"], kind)
        })
      }
    )
  ]

  exported_template_associations = [
    for association in try(local.raw_catalyst_center.template_device_association.templates, []) : merge(association,
      try(association.variables.type, "") != "local" ? {} : {
        variables = merge(association.variables, {
          values = [
            for item in try(association.variables.values, []) : merge(item, {
              value = contains([
                for companion in try(association.variables.values, []) : companion.name
                if try(association.type, "DAYN") != "COMPOSITE" || try(companion.template_name, "") == try(item.template_name, "")
              ], "${item.name}_version_secure") ? null : item.value
            })
          ]
        })
      },
      try(association.devices, null) == null ? {} : {
        devices = [
          for device in association.devices : merge(device,
            try(device.variables.type, "") != "local" ? {} : {
              variables = merge(device.variables, {
                values = [
                  for item in try(device.variables.values, []) : merge(item, {
                    value = contains([
                      for companion in try(device.variables.values, []) : companion.name
                      if try(association.type, "DAYN") != "COMPOSITE" || try(companion.template_name, "") == try(item.template_name, "")
                    ], "${item.name}_version_secure") ? null : item.value
                  })
                ]
              })
            }
          )
        ]
      }
    )
  ]

  exported_template_provisioning = {
    for kind, templates in try(local.raw_catalyst_center.template_provisioning, {}) : kind => [
      for template in templates : merge(template,
        try(template.variables, null) == null ? {} : {
          variables = [
            for item in template.variables : merge(item, {
              value = contains([
                for companion in template.variables : companion.name
                if kind != "composite_templates" || try(companion.template_name, "") == try(item.template_name, "")
              ], "${item.name}_version_secure") ? null : item.value
            })
          ]
        },
        try(template.devices, null) == null ? {} : {
          devices = [
            for device in template.devices : merge(device,
              try(device.variables, null) == null ? {} : {
                variables = [
                  for item in device.variables : merge(item, {
                    value = contains([
                      for companion in device.variables : companion.name
                      if kind != "composite_templates" || try(companion.template_name, "") == try(item.template_name, "")
                    ], "${item.name}_version_secure") ? null : item.value
                  })
                ]
              }
            )
          ]
        }
      )
    ] if contains(["dayn_templates", "composite_templates", "onboarding_templates"], kind)
  }

  exported_model = merge(local.model,
    try(local.model.catalyst_center, null) == null ? {} : {
      catalyst_center = merge(local.raw_catalyst_center,
        try(local.raw_catalyst_center.inventory.devices, null) == null ? {} : {
          inventory = merge(local.raw_catalyst_center.inventory, { devices = local.exported_inventory_devices })
        },
        try(local.raw_catalyst_center.template_device_association.templates, null) == null ? {} : {
          template_device_association = merge(local.raw_catalyst_center.template_device_association, { templates = local.exported_template_associations })
        },
        try(local.raw_catalyst_center.template_provisioning, null) == null ? {} : {
          template_provisioning = merge(local.raw_catalyst_center.template_provisioning, local.exported_template_provisioning)
        }
      )
    }
  )
}
