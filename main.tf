locals {
  raw_catalyst_center   = try(local.model.catalyst_center, {})
  raw_fabric            = try(local.raw_catalyst_center.fabric, {})
  raw_fabric_sites      = try(local.raw_fabric.fabric_sites, [])
  raw_inventory_devices = try(local.raw_catalyst_center.inventory.devices, [])

  # master/data mixes short host names, FQDNs, `name`, and `device_name`.
  # Build an alias index before joining root-level fabric devices to inventory.
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

  # master/data keeps fabric devices at fabric.fabric_devices rather than inside
  # fabric_sites. Normalize their field aliases once. An unqualified device inherits
  # the most-specific fabric-site prefix of its inventory `site` path.
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
          for device in local.master_fabric_devices : device
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
    { network_settings = try(local.raw_catalyst_center.sites.global.network_settings, local.raw_catalyst_center.network_settings, {}) },
    # cli_templates -> top-level templates
    { templates = try(local.model.catalyst_center.cli_templates, {}) },
    # cli_templates.feature_templates -> top-level feature_templates
    { feature_templates = try(local.model.catalyst_center.cli_templates.feature_templates, {}) },
    # fabric.authentication_templates -> top-level authentication_templates
    { authentication_templates = try(local.model.catalyst_center.fabric.authentication_templates, []) },
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
