# Access points — inventory resolution, site assignment, provisioning and
# configuration.
#
# Access points are separated from cc_device_provision.tf because they resolve
# and provision differently from switches and routers: they are identified by
# serial number rather than management IP, they carry an ethernet MAC that the
# Configure Access Points API keys on, and they are provisioned per site rather
# than per device. Wireless controller resources stay in cc_device_provision.tf
# — `assign_managed_ap_locations` configures the controller, not the access
# point.

locals {
  # The Configure Access Points API selects APs by their ETHERNET MAC. This is
  # not `mac_address`, which on an AP is the base radio MAC and is rejected with
  # "There are no Access points with the specified ethernet mac addresses".
  # Requires catalystcenter provider 0.6.1 or later.
  #
  # Both maps are grouped with `...` before being keyed. Catalyst Center does not
  # guarantee a unique hostname, and can briefly hold two entries for one serial
  # number, so a `for` expression keying either directly aborts the entire plan
  # with "Duplicate object key" — for every user of the module, not only those
  # configuring access points. An access point and its RMA replacement sit in
  # inventory under the same hostname until the old unit is removed.
  #
  # The explicit null tests matter: `try(x, "")` only substitutes on an error,
  # not on a null, so a device with no serial number or hostname would otherwise
  # survive the filter and produce a null map key. `device_serial_to_id` in
  # cc_device_provision.tf guards the same way.
  device_serial_ap_eth_macs = {
    for device in coalesce(data.catalystcenter_network_devices.all_devices.devices, []) :
    device.serial_number => device.ap_ethernet_mac_address...
    if try(device.serial_number, null) != null
    && try(device.serial_number, "") != ""
    && try(device.ap_ethernet_mac_address, null) != null
    && try(device.ap_ethernet_mac_address, "") != ""
  }

  device_hostname_ap_eth_macs = {
    for device in coalesce(data.catalystcenter_network_devices.all_devices.devices, []) :
    device.hostname => device.ap_ethernet_mac_address...
    if try(device.hostname, null) != null
    && try(device.hostname, "") != ""
    && try(device.ap_ethernet_mac_address, null) != null
    && try(device.ap_ethernet_mac_address, "") != ""
  }

  # An identifier that maps to more than one ethernet MAC resolves to nothing
  # rather than to an arbitrary one of the candidates. Guessing would push a
  # configuration to the wrong physical access point, which is worse than
  # skipping it; `access_point_ambiguous_identifier_validation` reports the
  # affected access points.
  device_serial_to_ap_eth_mac = {
    for serial, macs in local.device_serial_ap_eth_macs :
    serial => macs[0] if length(distinct(macs)) == 1
  }

  # Applying a configuration does not require a serial number — the ethernet MAC
  # resolves from the Catalyst Center hostname just as well, which keeps AP
  # configuration consistent with the serial / name / FQDN ladder already used
  # for site assignment and provisioning. Only `manage_hostname` genuinely needs
  # a serial; see `ap_hostname_without_serial`.
  device_name_to_ap_eth_mac = {
    for hostname, macs in local.device_hostname_ap_eth_macs :
    hostname => macs[0] if length(distinct(macs)) == 1
  }

  assigned_access_points_map = {
    for d in try(local.catalyst_center.inventory.devices, []) :
    d.site => {
      name          = d.name
      fqdn_name     = try(d.fqdn_name, null)
      device_ip     = try(d.device_ip, null)
      serial_number = try(d.serial_number, null)
    }... if(strcontains(d.state, "PROVISION") || d.state == "ASSIGN") && contains(local.sites, try(d.site, "NONE")) && try(d.type, null) == "AccessPoint"
    && (
      lookup(local.device_serial_to_id, try(d.serial_number, ""), null) != null ||
      lookup(local.device_name_to_id, d.name, null) != null ||
      lookup(local.device_name_to_id, try(d.fqdn_name, ""), null) != null ||
      lookup(local.device_ip_to_id, try(d.device_ip, ""), null) != null
    )
  }

  missing_access_points = [
    for device in try(local.catalyst_center.inventory.devices, []) :
    device
    if(strcontains(device.state, "PROVISION") || device.state == "ASSIGN")
    && try(device.type, null) == "AccessPoint"
    && contains(local.sites, try(device.site, "NONE"))
    && lookup(local.device_serial_to_id, try(device.serial_number, ""), null) == null
    && lookup(local.device_name_to_id, device.name, null) == null
    && lookup(local.device_name_to_id, try(device.fqdn_name, ""), null) == null
    && lookup(local.device_ip_to_id, try(device.device_ip, ""), null) == null
  ]

  missing_access_points_error = length(local.missing_access_points) > 0 ? "❌ The following access points are not found in Catalyst Center inventory:\n\n${join("\n", [for d in local.missing_access_points : "  • ${d.name} (Serial: ${try(d.serial_number, "N/A")}, FQDN: ${try(d.fqdn_name, "N/A")}, Site: ${d.site})"])}\n\nAn access point is resolved by `serial_number` first, then `name` / `fqdn_name`. Resolution by `device_ip` does not apply to Catalyst 9100-series (C91xx) or Cisco Wireless (CW91xx) access points, whose management IPs are ephemeral and deliberately excluded from IP-based lookup. Because Catalyst Center also assigns AP hostnames at claim time, `serial_number` is the recommended identifier.\n\nAction required: Add `serial_number` to these access points in the data model, or ensure they are claimed and present in Catalyst Center inventory before running Terraform." : ""
}

check "access_point_discovery_validation" {
  assert {
    condition     = length(local.missing_access_points) == 0
    error_message = local.missing_access_points_error
  }
}

resource "catalystcenter_assign_device_to_site" "access_points_to_site" {
  for_each = local.assigned_access_points_map

  device_ids = [
    for device in each.value :
    try(local.device_serial_to_id[device.serial_number], local.device_name_to_id[device.name], local.device_name_to_id[device.fqdn_name], local.device_ip_to_id[device.device_ip])
    if(
      lookup(local.device_serial_to_id, try(device.serial_number, ""), null) != null ||
      lookup(local.device_name_to_id, device.name, null) != null ||
      lookup(local.device_name_to_id, try(device.fqdn_name, ""), null) != null ||
      lookup(local.device_ip_to_id, try(device.device_ip, ""), null) != null
    )
  ]
  site_id = var.use_bulk_api ? coalesce(local.site_id_list_bulk[each.key], local.data_source_created_sites_list[each.key]) : local.site_id_list[each.key]
}

locals {
  provisioned_access_points = [
    for device in try(local.catalyst_center.inventory.devices, []) : device
    if(strcontains(device.state, "PROVISION"))
    && try(device.type, null) == "AccessPoint"
    && contains(local.sites, try(device.site, "NONE"))
    && (
      lookup(local.device_serial_to_id, try(device.serial_number, ""), null) != null ||
      lookup(local.device_name_to_id, device.name, null) != null ||
      lookup(local.device_name_to_id, try(device.fqdn_name, ""), null) != null ||
      lookup(local.device_ip_to_id, try(device.device_ip, ""), null) != null
    )
  ]

  provisioned_access_points_by_site = {
    for d in local.provisioned_access_points : d.site => d...
  }
}

resource "catalystcenter_provision_access_points" "access_points" {
  for_each = { for site, devices in try(local.provisioned_access_points_by_site, {}) : site => devices if length(devices) > 0 }

  network_devices = [for device in each.value : {
    device_id = coalesce(
      try(lookup(local.device_serial_to_id, device.serial_number, null), null),
      try(lookup(local.device_name_to_id, device.name, null), null),
      try(lookup(local.device_name_to_id, device.fqdn_name, null), null),
      try(lookup(local.device_ip_to_id, device.device_ip, null), null)
    )
    reprovision = try(device.state, null) == "REPROVISION" ? true : false
  }]
  rf_profile_name = try(each.value[0].rf_profile)
  site_id         = try(var.use_bulk_api ? coalesce(local.site_id_list_bulk[each.key], local.data_source_created_sites_list[each.key]) : local.site_id_list[each.key], null)

  depends_on = [catalystcenter_assign_device_to_site.access_points_to_site]
}

# ---------------------------------------------------------------------------
# Access point configuration
#
# Applies the named configurations declared under
# `wireless.access_point_configurations` to the access points that reference
# them, and reconciles AP hostnames to `inventory.devices[].name`. Both opt-ins
# live in the data model rather than in module variables, so intent travels with
# the device:
#
#   inventory:
#     devices:
#       - name: AP-01
#         type: AccessPoint
#         access_point:
#           configuration: OFFICE_STANDARD  # -> wireless.access_point_configurations[].name
#           manage_hostname: true           # rename the AP to `name` (default false)
#
# `access_point` carries a reference and a rename flag, nothing else. Every
# setting is declared once under `wireless.access_point_configurations`, because
# in the Configure Access Points API only `mac_address`, `ap_name` and
# `ap_name_new` are per-AP — every other setting, including the whole
# `radio_configurations` list, is top-level and applies to every AP in `ap_list`.
# A per-device override is therefore not per-device at all: it silently forks
# that access point into an API call of its own, which is intent the data model
# should not be able to express.
#
# RESOLUTION is two-tier: the named configuration first, then
# `defaults.catalyst_center.wireless.access_point_configurations`, so settings
# shared by every configuration can still be declared once. `radios` overrides at
# list level rather than element level.
#
# GROUPING is therefore trivial — one resource instance per named configuration,
# plus one rename-only instance keyed `(hostname only)` for access points that
# manage a hostname without referencing a configuration. Two access points on the
# same configuration are identical by construction, so no payload hashing is
# needed to tell groups apart.
#
# FOR_EACH KEYS derive only from the data model: they are configuration names.
# MAC and current hostname come from a data source and are apply-time unknown, so
# they appear only as values inside `ap_list`, never in a key. Putting them in a
# key reproduces the "Invalid for_each argument" failure that forced the RMA
# rework (netascode/nac-catalystcenter#530).
#
# IDEMPOTENCY: `ap_list` must never be derived from a value this resource itself
# mutates, or a successful apply changes its own arguments and costs a second
# apply to settle. So `ap_name_new` is always the desired data-model name, never
# the result of comparing against the live hostname, and `ap_name` stays null —
# the API keys on `mac_address`. Renaming an AP to the name it already holds is a
# no-op, which is what makes sending it unconditionally safe.
#
# VALIDATION SEVERITY follows one rule:
#
#   precondition  Catalyst Center rejects the request, returns an undefined
#   (plan fails)  result, or the module cannot build a payload at all. The apply
#                 could not have succeeded, so fail early with a better message.
#
#   check         Catalyst Center accepts the request and silently ignores the
#   (warning)     value, or the access point can be skipped without affecting the
#                 others. The apply succeeds and is correct except for that one
#                 value, so warn rather than block.
# ---------------------------------------------------------------------------
locals {
  ap_mode_map            = { LOCAL = 0, MONITOR = 1, SNIFFER = 4, BRIDGE = 5 }
  ap_failover_map        = { LOW = 1, MEDIUM = 2, HIGH = 3, CRITICAL = 4 }
  ap_assignment_mode_map = { GLOBAL = 1, CUSTOM = 2 }
  ap_channel_width_map   = { "20" = 3, "40" = 4, "80" = 5, "160" = 6, "320" = 7 }
  ap_radio_band_map      = { "2.4" = "RADIO24", "5" = "RADIO5", "6" = "RADIO6", "XOR" = "RADIO5" }
  ap_radio_type_map      = { "2.4" = 1, "5" = 2, "XOR" = 3, "6" = 6 }

  # Group holding access points that manage a hostname but reference no
  # configuration. Parenthesised so it cannot collide with a configuration name.
  ap_hostname_only_key = "(hostname only)"

  # Access points keyed by their data-model name — required by the schema and
  # already treated as unique module-wide by `local.all_devices`. Unlike
  # `serial_number` it is always present, so it is the key the whole
  # configuration pipeline runs on.
  ap_devices = { for d in local.provisioned_access_points : d.name => d }

  # Serial first, then hostname / FQDN, mirroring the resolution ladder.
  ap_eth_mac = {
    for name, d in local.ap_devices : name => try(coalesce(
      try(local.device_serial_to_ap_eth_mac[d.serial_number], null),
      try(local.device_name_to_ap_eth_mac[d.name], null),
      try(local.device_name_to_ap_eth_mac[d.fqdn_name], null)
    ), null)
  }

  ap_named_configs = {
    for c in try(local.catalyst_center.wireless.access_point_configurations, []) :
    c.name => c
  }

  ap_config_defaults = try(local.defaults.catalyst_center.wireless.access_point_configurations, {})
  ap_device_defaults = try(local.defaults.catalyst_center.inventory.devices.access_point, {})

  ap_hostname_managed = {
    for name, d in local.ap_devices : name => true
    if try(d.access_point.manage_hostname, local.ap_device_defaults.manage_hostname, false)
  }

  # A rename-only group carries no settings: every configure_* flag ends up false
  # so the API applies nothing but `ap_name_new`. Built explicitly rather than by
  # resolving an empty configuration, so it never inherits the defaults tier.
  ap_config_none = {
    admin_status                 = null
    ap_mode                      = null
    failover_priority            = null
    led_status                   = null
    led_brightness_level         = null
    location                     = null
    is_assigned_site_as_location = null
    primary_controller_name      = null
    primary_ip_address           = null
    secondary_controller_name    = null
    secondary_ip_address         = null
    tertiary_controller_name     = null
    tertiary_ip_address          = null
    radios                       = []
  }

  # Stage 1 — resolve each named configuration once. With N configurations and M
  # access points this runs N times, not M: a setting is a property of the
  # configuration, never of the device that references it.
  ap_config_resolved = merge(
    {
      for name, c in local.ap_named_configs : name => {
        admin_status                 = try(c.admin_status, local.ap_config_defaults.admin_status, null)
        ap_mode                      = try(c.ap_mode, local.ap_config_defaults.ap_mode, null)
        failover_priority            = try(c.failover_priority, local.ap_config_defaults.failover_priority, null)
        led_status                   = try(c.led_status, local.ap_config_defaults.led_status, null)
        led_brightness_level         = try(c.led_brightness_level, local.ap_config_defaults.led_brightness_level, null)
        location                     = try(c.location, local.ap_config_defaults.location, null)
        is_assigned_site_as_location = try(c.is_assigned_site_as_location, local.ap_config_defaults.is_assigned_site_as_location, null)
        primary_controller_name      = try(c.primary_controller_name, local.ap_config_defaults.primary_controller_name, null)
        primary_ip_address           = try(c.primary_ip_address, local.ap_config_defaults.primary_ip_address, null)
        secondary_controller_name    = try(c.secondary_controller_name, local.ap_config_defaults.secondary_controller_name, null)
        secondary_ip_address         = try(c.secondary_ip_address, local.ap_config_defaults.secondary_ip_address, null)
        tertiary_controller_name     = try(c.tertiary_controller_name, local.ap_config_defaults.tertiary_controller_name, null)
        tertiary_ip_address          = try(c.tertiary_ip_address, local.ap_config_defaults.tertiary_ip_address, null)
        radios                       = try(c.radios, local.ap_config_defaults.radios, [])
      }
    },
    { (local.ap_hostname_only_key) = local.ap_config_none }
  )

  # Stage 2 — API payload per configuration. The configure_* flags are derived
  # from value presence, never taken from the data model: they are an API
  # transport artefact, not user intent.
  ap_config_settings = {
    for name, r in local.ap_config_resolved : name => {
      configure_admin_status = r.admin_status != null
      admin_status           = r.admin_status

      configure_ap_mode = r.ap_mode != null
      ap_mode           = try(local.ap_mode_map[r.ap_mode], null)

      configure_failover_priority = r.failover_priority != null
      failover_priority           = try(local.ap_failover_map[r.failover_priority], null)

      configure_led_status = r.led_status != null
      led_status           = r.led_status

      configure_led_brightness_level = r.led_brightness_level != null
      led_brightness_level           = r.led_brightness_level

      # `is_assigned_site_as_location` has no configure_* flag of its own and
      # rides on configure_location, which is the gate telling the API to change
      # the location at all. Without this the site-derived option is accepted and
      # silently ignored.
      configure_location = r.location != null || r.is_assigned_site_as_location == true
      location           = r.location

      is_assigned_site_as_location = r.is_assigned_site_as_location

      configure_ha_controller   = r.primary_controller_name != null
      primary_controller_name   = r.primary_controller_name
      primary_ip_address        = r.primary_ip_address
      secondary_controller_name = r.secondary_controller_name
      secondary_ip_address      = r.secondary_ip_address
      tertiary_controller_name  = r.tertiary_controller_name
      tertiary_ip_address       = r.tertiary_ip_address

      radio_configurations = [
        for radio in r.radios : {
          # Catalyst Center rejects a radio band sent alongside an AUTO or
          # MONITOR role (NCWL10967) — the band selects which band an XOR radio
          # serves and is only meaningful for SERVING. radio_type still
          # identifies which radio is being configured.
          radio_band = contains(["AUTO", "MONITOR"], try(radio.role, "")) ? null : lookup(local.ap_radio_band_map, tostring(radio.band), null)
          radio_type = lookup(local.ap_radio_type_map, tostring(radio.band), null)

          configure_admin_status = try(radio.admin_status, null) != null
          admin_status           = try(radio.admin_status, null)

          configure_radio_role_assignment = try(radio.role, null) != null
          radio_role_assignment           = try(radio.role, null)

          configure_antenna_pattern_name = try(radio.antenna_pattern_name, null) != null
          antenna_pattern_name           = try(radio.antenna_pattern_name, null)
          antenna_gain                   = try(radio.antenna_gain, null)

          configure_antenna_cable = try(radio.antenna_cable_name, null) != null
          antenna_cable_name      = try(radio.antenna_cable_name, null)
          cable_loss              = try(radio.cable_loss, null)

          configure_channel       = try(radio.channel_number, null) != null || try(radio.channel_assignment_mode, null) != null
          channel_assignment_mode = try(local.ap_assignment_mode_map[radio.channel_assignment_mode], null)
          channel_number          = try(radio.channel_number, null)

          configure_channel_width = try(radio.channel_width, null) != null
          channel_width           = lookup(local.ap_channel_width_map, tostring(try(radio.channel_width, "")), null)

          configure_power       = try(radio.power_level, null) != null || try(radio.power_assignment_mode, null) != null
          power_assignment_mode = try(local.ap_assignment_mode_map[radio.power_assignment_mode], null)
          power_level           = try(radio.power_level, null)
        }
      ]
    }
  }

  # Stage 3 — attach access points to configurations in a single pass, then keep
  # only the groups that actually have members.
  ap_config_members = merge(
    {
      for name, d in local.ap_devices :
      d.access_point.configuration => name...
      if try(d.access_point.configuration, null) != null
    },
    {
      (local.ap_hostname_only_key) = [
        for name, d in local.ap_devices : name
        if lookup(local.ap_hostname_managed, name, false)
        && try(d.access_point.configuration, null) == null
      ]
    }
  )

  ap_config_groups = {
    for key, settings in local.ap_config_settings : key => {
      settings = settings
      devices  = lookup(local.ap_config_members, key, [])
    }
    if length(lookup(local.ap_config_members, key, [])) > 0
  }
}

# ---------------------------------------------------------------------------
# Validation
# ---------------------------------------------------------------------------
locals {
  # Every access point declaring the block, whatever its state. An undefined
  # configuration name, or a rename with no serial number to drive it, is a
  # data-model error independent of provisioning, so validation is scoped here
  # rather than to the PROVISION-gated `ap_devices`.
  ap_declared = {
    for d in try(local.catalyst_center.inventory.devices, []) : d.name => d
    if try(d.type, null) == "AccessPoint" && try(d.access_point, null) != null
  }

  # The block is only acted on once the access point is provisioned. Warn rather
  # than silently ignore it, so a block that does nothing yet is visible.
  ap_block_not_provisioned = [
    for name, d in local.ap_declared : name
    if !strcontains(try(d.state, ""), "PROVISION")
  ]

  ap_block_not_provisioned_error = length(local.ap_block_not_provisioned) > 0 ? "⚠️ The following access points declare an `access_point` block that is not applied yet:\n\n${join("\n", [for name in local.ap_block_not_provisioned : "  • ${name} (state: ${try(local.ap_declared[name].state, "N/A")})"])}\n\nAccess point configuration and hostname reconciliation run only once the access point reaches a `PROVISION` state, because both depend on it having been provisioned to its site.\n\nNo action is required if this is intentional — the block takes effect when the state changes. Otherwise set `state: PROVISION`." : ""

  # An identifier resolving to more than one ethernet MAC is not resolved at all,
  # so these access points are skipped rather than configured by guess.
  ap_ambiguous_identifier = [
    for name, d in local.ap_devices : name
    if length(distinct(lookup(local.device_serial_ap_eth_macs, try(d.serial_number, ""), []))) > 1
    || length(distinct(lookup(local.device_hostname_ap_eth_macs, name, []))) > 1
    || length(distinct(lookup(local.device_hostname_ap_eth_macs, try(d.fqdn_name, ""), []))) > 1
  ]

  ap_ambiguous_identifier_error = length(local.ap_ambiguous_identifier) > 0 ? "⚠️ The following access points cannot be configured because their identifier matches more than one ethernet MAC address in Catalyst Center inventory:\n\n${join("\n", [for name in local.ap_ambiguous_identifier : "  • ${name}"])}\n\nCatalyst Center does not guarantee a unique hostname, and can briefly hold two entries for one serial number — an access point and its RMA replacement both appear until the old unit is removed. The module does not guess which one to configure, because pushing a configuration to the wrong physical access point is worse than skipping it.\n\nAction required: Remove the stale inventory entry, or give the access point a `serial_number` that resolves to exactly one device." : ""

  ap_unknown_config_refs = [
    for name, d in local.ap_declared : d
    if try(d.access_point.configuration, null) != null
    && lookup(local.ap_named_configs, try(d.access_point.configuration, ""), null) == null
  ]

  ap_unknown_config_refs_error = length(local.ap_unknown_config_refs) > 0 ? "❌ The following access points reference an `access_point.configuration` that is not defined:\n\n${join("\n", [for d in local.ap_unknown_config_refs : "  • ${d.name} -> `${d.access_point.configuration}`"])}\n\nNamed configurations are declared under `catalyst_center.wireless.access_point_configurations`.\n\nAction required: Define the missing configuration, or correct the reference on the device." : ""

  # `manage_hostname` is the one part of the access point block that genuinely
  # needs a serial number. The access point is found by its old hostname before
  # the rename and by its new hostname afterwards, so a name-based lookup stops
  # resolving the moment it succeeds — which would silently strand the device on
  # the next apply. Applying settings has no such problem, because nothing the
  # module sends changes the identifier it looked the access point up by.
  ap_hostname_without_serial = [
    for name, d in local.ap_declared : d
    if try(d.access_point.manage_hostname, local.ap_device_defaults.manage_hostname, false)
    && try(d.serial_number, null) == null
  ]

  ap_hostname_without_serial_error = length(local.ap_hostname_without_serial) > 0 ? "❌ The following access points set `access_point.manage_hostname: true` but have no `serial_number`:\n\n${join("\n", [for d in local.ap_hostname_without_serial : "  • ${d.name} (FQDN: ${try(d.fqdn_name, "N/A")}, Site: ${d.site})"])}\n\nRenaming an access point changes the hostname it would be found by, so a rename can only be driven from an identifier the rename does not alter. `serial_number` is that identifier; `name` and `fqdn_name` are not.\n\nApplying `access_point.configuration` does not have this restriction and works with `name` / `fqdn_name` alone.\n\nAction required: Add `serial_number` to these access points, or set `access_point.manage_hostname: false`." : ""

  # Configuration-scoped validation. These iterate the configurations rather than
  # the access points, so an error names the configuration once instead of
  # enumerating every device that references it.
  ap_config_location_conflict = [
    for name, r in local.ap_config_resolved : name
    if r.location != null && r.is_assigned_site_as_location == true
  ]

  ap_config_location_conflict_error = length(local.ap_config_location_conflict) > 0 ? "❌ The following access point configurations set both `location` and `is_assigned_site_as_location: true`:\n\n${join("\n", [for name in local.ap_config_location_conflict : "  • ${name} (location: \"${local.ap_config_resolved[name].location}\")"])}\n\nThese are two mutually exclusive sources for the same access point location attribute, and the Configure Access Points API does not define which one wins.\n\nNote that the access point location is a free-text label written onto the device; it is not the Catalyst Center site assignment, which is managed separately from `site`.\n\nAction required: Keep `is_assigned_site_as_location: true` to derive the label from the assigned site (recommended, since the site is already the source of truth), or remove it and set `location` explicitly." : ""

  ap_config_role_rf_conflict = [
    for name, r in local.ap_config_resolved : name
    if anytrue([
      for radio in r.radios :
      (
        try(radio.channel_number, null) != null
        || try(radio.channel_assignment_mode, null) != null
        || try(radio.channel_width, null) != null
        || try(radio.power_level, null) != null
        || try(radio.power_assignment_mode, null) != null
      )
      && try(radio.role, "") != "SERVING"
    ])
  ]

  ap_config_role_rf_conflict_error = length(local.ap_config_role_rf_conflict) > 0 ? "❌ The following access point configurations set channel or power parameters on a radio whose `role` is not `SERVING`:\n\n${join("\n", [for name in local.ap_config_role_rf_conflict : "  • ${name}"])}\n\nCatalyst Center rejects this with `NCWL10977: Radio Role Assignment ... is not compatible with Channel Width / Power Assignment configuration. This configuration is only supported with Serving Radio Role Assignment.`\n\nOmitting `role` does not mean \"no role\" — it leaves the radio on its current role, which is typically `AUTO` and therefore still rejected. Any radio carrying `channel_number`, `channel_assignment_mode`, `channel_width`, `power_level` or `power_assignment_mode` must set `role: SERVING` explicitly in the same request.\n\nAction required: Add `role: SERVING` to those radios, or remove the channel and power parameters and let RRM manage them." : ""

  ap_config_rf_mode_conflict = [
    for name, r in local.ap_config_resolved : name
    if anytrue([
      for radio in r.radios :
      (
        (try(radio.channel_width, null) != null || try(radio.channel_number, null) != null)
        && try(radio.channel_assignment_mode, "") != "CUSTOM"
      )
      || (
        try(radio.power_level, null) != null
        && try(radio.power_assignment_mode, "") != "CUSTOM"
      )
    ])
  ]

  ap_config_rf_mode_conflict_error = length(local.ap_config_rf_mode_conflict) > 0 ? "❌ The following access point configurations set an explicit channel, channel width or power level without the matching assignment mode set to `CUSTOM`:\n\n${join("\n", [for name in local.ap_config_rf_mode_conflict : "  • ${name}"])}\n\nCatalyst Center rejects this with `NCWL10959: Channel Width can be configured only when Channel Assignment is in Custom mode.` Under `GLOBAL` — which is also the behaviour when the mode is omitted — the controller's RRM algorithm owns the value, so an explicit one cannot be applied.\n\nAction required: Add `channel_assignment_mode: CUSTOM` alongside `channel_number` / `channel_width`, and `power_assignment_mode: CUSTOM` alongside `power_level`. Otherwise remove the explicit values and let RRM manage the radio." : ""

  ap_config_width_on_24ghz = [
    for name, r in local.ap_config_resolved : name
    if anytrue([
      for radio in r.radios :
      try(radio.channel_width, null) != null && tostring(try(radio.band, "")) == "2.4"
    ])
  ]

  ap_config_width_on_24ghz_error = length(local.ap_config_width_on_24ghz) > 0 ? "❌ The following access point configurations set `channel_width` on a 2.4 GHz radio:\n\n${join("\n", [for name in local.ap_config_width_on_24ghz : "  • ${name}"])}\n\nCatalyst Center rejects this with `NCWL10970: Channel Bandwidth is supported for A (5 GHz), 6GHz and XOR (Dual-Band) radios only.` The 2.4 GHz band operates at 20 MHz only; channel bonding is not supported there.\n\nAction required: Remove `channel_width` from the 2.4 GHz radio. `channel_number`, `power_level` and their `CUSTOM` assignment modes remain valid on that band." : ""

  # Warning-only below this line ---------------------------------------------

  # Catalyst Center accepts the request and derives the gain from the named
  # antenna pattern, silently ignoring the supplied value.
  ap_config_invalid_antenna_gain = [
    for name, r in local.ap_config_resolved : name
    if anytrue([
      for radio in r.radios :
      try(radio.antenna_gain, null) != null && lower(try(radio.antenna_pattern_name, "")) != "other"
    ])
  ]

  ap_config_invalid_antenna_gain_error = length(local.ap_config_invalid_antenna_gain) > 0 ? "❌ The following access point configurations set `antenna_gain` without `antenna_pattern_name: other`:\n\n${join("\n", [for name in local.ap_config_invalid_antenna_gain : "  • ${name}"])}\n\nCatalyst Center only applies `antenna_gain` when `antenna_pattern_name` is set to `other`; otherwise the gain is derived from the named antenna pattern and the supplied value is silently ignored.\n\nAction required: Set `antenna_pattern_name: other` on those radios, or remove `antenna_gain`." : ""

  ap_config_invalid_cable_loss = [
    for name, r in local.ap_config_resolved : name
    if anytrue([
      for radio in r.radios :
      try(radio.cable_loss, null) != null && lower(try(radio.antenna_cable_name, "")) != "other"
    ])
  ]

  ap_config_invalid_cable_loss_error = length(local.ap_config_invalid_cable_loss) > 0 ? "❌ The following access point configurations set `cable_loss` without `antenna_cable_name: other`:\n\n${join("\n", [for name in local.ap_config_invalid_cable_loss : "  • ${name}"])}\n\nCatalyst Center only applies `cable_loss` when `antenna_cable_name` is set to `other`.\n\nAction required: Set `antenna_cable_name: other` on those radios, or remove `cable_loss`." : ""

  # An access point with no ethernet MAC is skipped rather than blocking the
  # apply. Serial-number resolution exists so an AP rollout can be described from
  # the bill of materials before the access points are claimed, and an ethernet
  # MAC only appears once an access point is in inventory — hard-failing here
  # would reject exactly the partially-claimed rollout that workflow enables. The
  # `for_each` and `ap_list` filters below drop these access points, so the rest
  # of the group is configured normally.
  ap_config_missing_mac = distinct(flatten([
    for key, group in local.ap_config_groups : [
      for name in group.devices : name if lookup(local.ap_eth_mac, name, null) == null
    ]
  ]))

  ap_config_missing_mac_error = length(local.ap_config_missing_mac) > 0 ? "⚠️ The following access points are skipped because Catalyst Center returned no ethernet MAC address for them:\n\n${join("\n", [for name in local.ap_config_missing_mac : "  • ${name} (Serial: ${try(local.ap_devices[name].serial_number, "N/A")})"])}\n\nThe Configure Access Points intent API selects access points by their ethernet MAC address (`apEthernetMacAddress` in inventory) and accepts no other identifier. Note this is not the device `macAddress`, which on an access point is the base radio MAC. An ethernet MAC is only present once the access point has been claimed and is in inventory.\n\nEvery other access point in the same configuration is applied normally. Re-run once these access points are claimed to configure them too." : ""
}

resource "terraform_data" "ap_configuration_validation" {
  lifecycle {
    precondition {
      condition     = length(local.ap_unknown_config_refs) == 0
      error_message = local.ap_unknown_config_refs_error
    }
    precondition {
      condition     = length(local.ap_hostname_without_serial) == 0
      error_message = local.ap_hostname_without_serial_error
    }
    precondition {
      condition     = length(local.ap_config_location_conflict) == 0
      error_message = local.ap_config_location_conflict_error
    }
    precondition {
      condition     = length(local.ap_config_role_rf_conflict) == 0
      error_message = local.ap_config_role_rf_conflict_error
    }
    precondition {
      condition     = length(local.ap_config_rf_mode_conflict) == 0
      error_message = local.ap_config_rf_mode_conflict_error
    }
    precondition {
      condition     = length(local.ap_config_width_on_24ghz) == 0
      error_message = local.ap_config_width_on_24ghz_error
    }
  }
}

check "access_point_configuration_antenna_gain_validation" {
  assert {
    condition     = length(local.ap_config_invalid_antenna_gain) == 0
    error_message = local.ap_config_invalid_antenna_gain_error
  }
}

check "access_point_configuration_cable_loss_validation" {
  assert {
    condition     = length(local.ap_config_invalid_cable_loss) == 0
    error_message = local.ap_config_invalid_cable_loss_error
  }
}

check "access_point_configuration_ethernet_mac_validation" {
  assert {
    condition     = length(local.ap_config_missing_mac) == 0
    error_message = local.ap_config_missing_mac_error
  }
}

check "access_point_ambiguous_identifier_validation" {
  assert {
    condition     = length(local.ap_ambiguous_identifier) == 0
    error_message = local.ap_ambiguous_identifier_error
  }
}

check "access_point_block_not_provisioned_validation" {
  assert {
    condition     = length(local.ap_block_not_provisioned) == 0
    error_message = local.ap_block_not_provisioned_error
  }
}

resource "catalystcenter_access_point_configuration" "ap_config" {
  for_each = {
    for key, group in local.ap_config_groups : key => group
    if length([for name in group.devices : name if lookup(local.ap_eth_mac, name, null) != null]) > 0
  }

  ap_list = [
    for name in each.value.devices : {
      mac_address = local.ap_eth_mac[name]
      ap_name     = null
      ap_name_new = lookup(local.ap_hostname_managed, name, false) ? name : null
    }
    if lookup(local.ap_eth_mac, name, null) != null
  ]

  configure_admin_status = each.value.settings.configure_admin_status
  admin_status           = each.value.settings.admin_status

  configure_ap_mode = each.value.settings.configure_ap_mode
  ap_mode           = each.value.settings.ap_mode

  configure_failover_priority = each.value.settings.configure_failover_priority
  failover_priority           = each.value.settings.failover_priority

  configure_led_status = each.value.settings.configure_led_status
  led_status           = each.value.settings.led_status

  configure_led_brightness_level = each.value.settings.configure_led_brightness_level
  led_brightness_level           = each.value.settings.led_brightness_level

  configure_location = each.value.settings.configure_location
  location           = each.value.settings.location

  is_assigned_site_as_location = each.value.settings.is_assigned_site_as_location

  configure_ha_controller   = each.value.settings.configure_ha_controller
  primary_controller_name   = each.value.settings.primary_controller_name
  primary_ip_address        = each.value.settings.primary_ip_address
  secondary_controller_name = each.value.settings.secondary_controller_name
  secondary_ip_address      = each.value.settings.secondary_ip_address
  tertiary_controller_name  = each.value.settings.tertiary_controller_name
  tertiary_ip_address       = each.value.settings.tertiary_ip_address

  radio_configurations = each.value.settings.radio_configurations

  depends_on = [catalystcenter_provision_access_points.access_points]
}
