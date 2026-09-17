locals {
  raw_catalyst_center   = try(local.model.catalyst_center, {})
  raw_fabric            = try(local.raw_catalyst_center.fabric, {})
  raw_fabric_sites      = try(local.raw_fabric.fabric_sites, [])
  raw_inventory_devices = try(local.raw_catalyst_center.inventory.devices, [])

  # Combine both supported locations for global network settings. Pool entries
  # with the same name are merged so either location can supply details.
  top_level_network_settings   = try(local.raw_catalyst_center.network_settings, {})
  site_global_network_settings = try(local.raw_catalyst_center.sites.global.network_settings, {})
  top_level_ip_pools_by_name = {
    for pool in try(local.top_level_network_settings.ip_pools, []) : pool.name => pool
  }
  site_global_ip_pools_by_name = {
    for pool in try(local.site_global_network_settings.ip_pools, []) : pool.name => pool
  }
  normalized_network_settings = merge(
    local.top_level_network_settings,
    local.site_global_network_settings,
    length(setunion(toset(keys(local.top_level_ip_pools_by_name)), toset(keys(local.site_global_ip_pools_by_name)))) > 0 ? {
      ip_pools = [
        for name in sort(tolist(setunion(toset(keys(local.top_level_ip_pools_by_name)), toset(keys(local.site_global_ip_pools_by_name))))) :
        merge(
          try(local.top_level_ip_pools_by_name[name], {}),
          try(local.site_global_ip_pools_by_name[name], {}),
        )
      ]
    } : {},
  )

  # Accept LAN automation as either typed entries or separate collections.
  normalized_lan_automation = {
    devices = concat(try(local.raw_catalyst_center.lan_automation.devices, []), [
      for item in try(tolist(local.raw_catalyst_center.lan_automation), []) : item
      if try(item.type, "devices") == "devices"
    ])
    links = concat(try(local.raw_catalyst_center.lan_automation.links, []), [
      for item in try(tolist(local.raw_catalyst_center.lan_automation), []) : item
      if try(item.type, "") == "links"
    ])
  }

  # Convert template-device associations into template provisioning entries.
  normalized_template_provisioning = {
    dayn_templates = [
      for association in try(local.raw_catalyst_center.template_device_association.templates, []) : {
        template_name     = association.name
        project_name      = association.project_name
        deploy_order      = try(association.deploy_order, local.raw_catalyst_center.template_device_association.deploy_order, null)
        redeploy_template = try(association.state, "ON_CHANGE")
        variables_file    = try(association.variables.type, "") == "csv" ? association.variables.name : null
        devices = [
          for device in try(association.devices, []) : {
            name              = device.name
            redeploy_template = try(device.state, association.state, "ON_CHANGE")
            deploy_order      = try(device.deploy_order, association.deploy_order, local.raw_catalyst_center.template_device_association.deploy_order, null)
            variables_file    = try(device.variables.type, "") == "csv" ? device.variables.name : null
            variables         = try(device.variables.type, "") == "local" ? try(device.variables.values, []) : []
          }
        ]
      }
    ]
  }

  # Index every supported device-name form before joining fabric and inventory data.
  inventory_device_aliases = flatten([
    for device in local.raw_inventory_devices : [
      for alias in distinct(concat(
        [
          for name in [
            try(device.name, null),
            try(device.device_name, null),
            try(device.fqdn_name, null),
            try(device.hostname, null),
          ] : name if name != null
        ],
        [
          for name in [
            try(device.name, null),
            try(device.device_name, null),
            try(device.fqdn_name, null),
            try(device.hostname, null),
          ] : split(".", name)[0] if name != null && strcontains(name, ".")
        ],
        )) : {
        alias  = alias
        device = device
      }
    ]
  ])

  inventory_devices_by_alias = {
    for entry in local.inventory_device_aliases : entry.alias => entry.device
  }

  # Normalize top-level fabric devices. Devices without an explicit fabric site
  # inherit the most-specific matching prefix from their inventory site.
  master_fabric_devices = [
    for device in try(local.raw_fabric.fabric_devices, []) : merge(device, {
      name = coalesce(try(device.name, null), try(device.device_name, null))
      state = try(
        device.state,
        local.inventory_devices_by_alias[coalesce(try(device.name, null), try(device.device_name, null))].state,
        null,
      )
      device_ip = try(
        device.device_ip,
        local.inventory_devices_by_alias[coalesce(try(device.name, null), try(device.device_name, null))].device_ip,
        null,
      )
      fqdn_name = try(
        device.fqdn_name,
        local.inventory_devices_by_alias[coalesce(try(device.name, null), try(device.device_name, null))].fqdn_name,
        null,
      )
      fabric_site = try(coalesce(
        try(device.fabric_site, null),
        try(split("|", reverse(sort([
          for fabric_site in local.raw_fabric_sites : format("%03d|%s", length(split("/", fabric_site.name)), fabric_site.name)
          if try(local.inventory_devices_by_alias[coalesce(try(device.name, null), try(device.device_name, null))].site, "") == fabric_site.name || startswith(try(local.inventory_devices_by_alias[coalesce(try(device.name, null), try(device.device_name, null))].site, ""), "${fabric_site.name}/")
        ]))[0])[1], null),
      ), null)
      l3_handoffs = [
        for handoff in try(device.l3_handoffs, []) : merge(handoff, {
          ip_transit_name = try(handoff.ip_transit_name, handoff.name)
        })
      ]
      port_assignments = {
        interfaces = [
          for assignment in try(device.port_assignments.interfaces, device.port_assignments, []) : merge(assignment, {
            authenticate_template_name = try(assignment.authenticate_template_name, assignment.authentication_template)
          })
        ]
      }
    })
  ]

  normalized_fabric_sites = [
    for fabric_site in local.raw_fabric_sites : merge(fabric_site, {
      anycast_gateways = [
        for gateway in try(fabric_site.anycast_gateways, []) : merge(gateway, {
          ip_pool_name = try(gateway.ip_pool_name, gateway.name)
        })
      ]
      fabric_devices = concat(
        try(fabric_site.fabric_devices, []),
        [
          for device in local.master_fabric_devices : merge(device, {
            # Resolve an anycast handoff's L3 VN name to its site-local IP pool.
            l2_handoffs = merge(try(device.l2_handoffs, {}), {
              l2_with_anycast_gateway = [
                for handoff in try(device.l2_handoffs.l2_with_anycast_gateway, []) : merge(handoff, {
                  l3_virtual_network = try(handoff.l3_virtual_network, handoff.name)
                  ip_pool_name = try(
                    handoff.ip_pool_name,
                    one([
                      for gateway in try(fabric_site.anycast_gateways, []) : try(gateway.ip_pool_name, gateway.name)
                      if try(gateway.l3_virtual_network, null) == try(handoff.l3_virtual_network, handoff.name)
                    ]),
                    null,
                  )
                })
              ]
              l2_without_anycast_gateway = merge(try(device.l2_handoffs.l2_without_anycast_gateway, {}), {
                vlans = [
                  for vlan in try(device.l2_handoffs.l2_without_anycast_gateway.vlans, []) : merge(vlan, {
                    vlan_name = try(vlan.vlan_name, vlan.name)
                  })
                ]
              })
            })
          })
          if try(device.fabric_site, null) == fabric_site.name ||
          (length(local.raw_fabric_sites) == 1 && try(device.fabric_site, null) == null)
        ]
      )
    })
  ]

  # Name-keyed map of every normalized fabric device. Feeds the fabric_roles fold.
  fabric_devices_by_name = {
    for entry in flatten([
      for fabric_site in local.normalized_fabric_sites : [
        for fabric_device in try(fabric_site.fabric_devices, []) : merge(fabric_device, {
          name = try(fabric_device.name, fabric_device.device_name)
        })
      ]
    ]) : entry.name => entry
  }

  catalyst_center = merge(
    local.raw_catalyst_center,
    { fabric = merge(local.raw_fabric, { fabric_sites = local.normalized_fabric_sites }) },
    # design.network_profiles -> top-level network_profiles
    { network_profiles = try(local.model.catalyst_center.design.network_profiles, {}) },
    # sites.global.network_settings -> top-level network_settings
    { network_settings = local.normalized_network_settings },
    # cli_templates -> top-level templates
    { templates = try(local.model.catalyst_center.cli_templates, {}) },
    # cli_templates.feature_templates -> top-level feature_templates
    { feature_templates = try(local.model.catalyst_center.cli_templates.feature_templates, {}) },
    # fabric.authentication_templates -> top-level authentication_templates
    { authentication_templates = try(local.model.catalyst_center.fabric.authentication_templates, []) },
    # typed LAN automation entries -> devices/links collections
    { lan_automation = local.normalized_lan_automation },
    # template-device associations -> template provisioning
    {
      template_provisioning = merge(
        try(local.raw_catalyst_center.template_provisioning, {}),
        try(local.raw_catalyst_center.template_device_association.templates[0], null) != null ? {
          dayn_templates = concat(
            try(local.raw_catalyst_center.template_provisioning.dayn_templates, []),
            local.normalized_template_provisioning.dayn_templates,
          )
        } : {},
      )
    },
    {
      inventory = merge(
        try(local.raw_catalyst_center.inventory, {}),
        {
          devices = [
            for device in try(local.raw_catalyst_center.inventory.devices, []) :
            merge(
              device,
              { name = coalesce(try(device.name, null), try(device.device_name, null)) },
              { for k, v in try(local.fabric_devices_by_name[coalesce(try(device.name, null), try(device.device_name, null))], {}) :
                k => v if k == "fabric_roles"
              },
            )
          ]
        }
      )
    },
  )
}
