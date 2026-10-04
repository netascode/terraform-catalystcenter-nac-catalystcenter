locals {
  application_qos = try(local.catalyst_center.application_qos, {})

  application_sets     = try(local.application_qos.application_sets, [])
  custom_applications  = try(local.application_qos.applications, [])
  queuing_profiles     = try(local.application_qos.queuing_profiles, [])
  application_policies = try(local.application_qos.policies, [])

  # Application set names managed by this module, versus names only referenced by
  # a policy. The ~29 built-in sets fall in the second group and must be resolved
  # through a data source because they are not Terraform-managed.
  managed_application_set_names = toset([for s in local.application_sets : s.name])

  referenced_application_set_names = toset(flatten([
    for p in local.application_policies : concat(
      try(p.application_sets.business_relevant, []),
      try(p.application_sets.default, []),
      try(p.application_sets.business_irrelevant, []),
    )
  ]))

  lookup_application_set_names = setsubtract(local.referenced_application_set_names, local.managed_application_set_names)

  # Queuing profiles referenced by a policy but not managed here, such as the
  # built-in CVD_QUEUING_PROFILE.
  managed_queuing_profile_names = toset([for q in local.queuing_profiles : q.name])

  referenced_queuing_profile_names = toset(compact([
    for p in local.application_policies :
    try(p.queuing_profile, local.defaults.catalyst_center.application_qos.policies.queuing_profile, null)
  ]))

  lookup_queuing_profile_names = setsubtract(local.referenced_queuing_profile_names, local.managed_queuing_profile_names)

  # The GUI has a single Protocol control. The controller stores it twice: as
  # networkIdentity.protocol and as the derived networkApplications.appProtocol,
  # which it rejects the object without. URL applications only accept TCP.
  derived_app_protocol = {
    for a in local.custom_applications : a.name => (
      try(a.type, null) == "url" ? "TCP" : try({
        TCP_OR_UDP = "TCP/UDP"
        TCP        = "TCP"
        UDP        = "UDP"
        IP         = "IP"
      }[a.network_identities[0].protocol], null)
    )
  }

  # Name to id maps, combining resources created here with looked-up objects.
  application_set_ids = merge(
    { for k, v in catalystcenter_application_set.application_qos_application_set : k => v.id },
    { for k, v in data.catalystcenter_application_set.application_qos_application_set : k => v.id },
  )

  queuing_profile_ids = merge(
    { for k, v in catalystcenter_app_policy_queuing_profile.application_qos_queuing_profile : k => v.id },
    { for k, v in data.catalystcenter_app_policy_queuing_profile.application_qos_queuing_profile : k => v.id },
  )

  # The GUI shows three columns. The controller stores one sibling policy per
  # application set. Expand the columns into that dense form.
  policy_relevance_rows = {
    for p in local.application_policies : p.name => flatten([
      for level, names in {
        BUSINESS_RELEVANT   = try(p.application_sets.business_relevant, [])
        DEFAULT             = try(p.application_sets.default, [])
        BUSINESS_IRRELEVANT = try(p.application_sets.business_irrelevant, [])
        } : [
        for n in names : {
          set_name        = n
          relevance_level = level
        }
      ]
    ])
  }

  # Sites created by this module are preferred. A policy may also target a site
  # that already exists on the controller, so fall back to the all-sites lookup.
  policy_site_ids = {
    for p in local.application_policies : p.name => [
      for s in try(p.sites, []) :
      try(
        var.use_bulk_api ? coalesce(local.site_id_list_bulk[s], local.data_source_created_sites_list[s]) : local.site_id_list[s],
        local.data_source_site_list[s]
      )
    ]
  }
}

data "catalystcenter_application_set" "application_qos_application_set" {
  for_each = local.lookup_application_set_names

  name = each.value
}

data "catalystcenter_app_policy_queuing_profile" "application_qos_queuing_profile" {
  for_each = local.lookup_queuing_profile_names

  name = each.value
}

resource "catalystcenter_qos_policy_setting" "application_qos_policy_setting" {
  count = can(local.application_qos.deploy_by_default_on_wired_devices) ? 1 : 0

  name                               = "qos_policy_setting"
  deploy_by_default_on_wired_devices = local.application_qos.deploy_by_default_on_wired_devices
}

resource "catalystcenter_application_set" "application_qos_application_set" {
  for_each = { for s in local.application_sets : s.name => s }

  name                       = each.value.name
  default_business_relevance = try(each.value.default_business_relevance, local.defaults.catalyst_center.application_qos.application_sets.default_business_relevance, null)
}

resource "catalystcenter_app_policy_queuing_profile" "application_qos_queuing_profile" {
  for_each = { for q in local.queuing_profiles : q.name => q }

  name        = each.value.name
  description = try(each.value.description, local.defaults.catalyst_center.application_qos.queuing_profiles.description, null)

  clauses = concat(
    can(each.value.bandwidth) ? [{
      type                                   = "BANDWIDTH"
      is_common_between_all_interface_speeds = try(each.value.bandwidth.is_common, local.defaults.catalyst_center.application_qos.queuing_profiles.bandwidth.is_common, null)
      interface_speed_bandwidth_clauses = [
        for s in try(each.value.bandwidth.interface_speeds, []) : {
          interface_speed = s.speed
          tc_bandwidth_settings = [
            for b in try(s.bandwidth_percentages, []) : {
              traffic_class        = b.traffic_class
              bandwidth_percentage = b.percentage
            }
          ]
        }
      ]
    }] : [],
    can(each.value.dscp_settings) ? [{
      type = "DSCP_CUSTOMIZATION"
      tc_dscp_settings = [
        for d in each.value.dscp_settings : {
          traffic_class = d.traffic_class
          dscp          = d.dscp
        }
      ]
    }] : [],
  )
}

resource "catalystcenter_application" "application_qos_application" {
  for_each = { for a in local.custom_applications : a.name => a }

  name               = each.value.name
  application_set_id = local.application_set_ids[each.value.application_set]
  category_id        = try(each.value.category_id, local.defaults.catalyst_center.application_qos.applications.category_id, null)
  traffic_class      = each.value.traffic_class
  help_string        = try(each.value.help_string, local.defaults.catalyst_center.application_qos.applications.help_string, null)
  dscp               = try(each.value.dscp, local.defaults.catalyst_center.application_qos.applications.dscp, null)
  rank               = try(each.value.rank, local.defaults.catalyst_center.application_qos.applications.rank, null)
  engine_id          = try(each.value.engine_id, local.defaults.catalyst_center.application_qos.applications.engine_id, null)
  app_protocol       = local.derived_app_protocol[each.value.name]
  server_name        = try(each.value.server_name, local.defaults.catalyst_center.application_qos.applications.server_name, null)
  url                = try(each.value.url, local.defaults.catalyst_center.application_qos.applications.url, null)

  server_type = try({
    server_name = "_servername"
    url         = "_url"
    server_ip   = "_server-ip"
  }[each.value.type], null)

  network_identity = [
    for n in try(each.value.network_identities, []) : {
      protocol = n.protocol
      # The controller requires the ports key to be present even when empty, so
      # a range-only classifier still has to send "".
      ports       = try(n.ports, "")
      lower_port  = try(n.lower_port, null)
      upper_port  = try(n.upper_port, null)
      ipv4_subnet = try(n.ipv4_subnets, null)
    }
  ]

  depends_on = [catalystcenter_application_set.application_qos_application_set]
}

resource "catalystcenter_application_policy" "application_qos_policy" {
  for_each = { for p in local.application_policies : p.name => p }

  policy_scope = each.value.name
  undeploy_action = try(
    each.value.undeploy_action,
    local.defaults.catalyst_center.application_qos.policies.undeploy_action,
    null
  )


  items = concat(
    [
      for row in local.policy_relevance_rows[each.key] : {
        name                       = "${each.value.name}_${row.set_name}"
        policy_scope               = each.value.name
        priority                   = tostring(try(each.value.priority, local.defaults.catalyst_center.application_qos.policies.priority, null))
        delete_policy_status       = try(each.value.delete_policy_status, local.defaults.catalyst_center.application_qos.policies.delete_policy_status, null)
        advanced_policy_scope_name = each.value.name
        site_ids                   = local.policy_site_ids[each.key]
        ssids                      = try(each.value.ssids, [])
        clause_type                = "BUSINESS_RELEVANCE"
        relevance_level            = row.relevance_level
        application_set_id         = local.application_set_ids[row.set_name]
      }
    ],
    [
      {
        name                       = "${each.value.name}_queuing_customization"
        policy_scope               = each.value.name
        priority                   = tostring(try(each.value.priority, local.defaults.catalyst_center.application_qos.policies.priority, null))
        delete_policy_status       = try(each.value.delete_policy_status, local.defaults.catalyst_center.application_qos.policies.delete_policy_status, null)
        advanced_policy_scope_name = each.value.name
        site_ids                   = local.policy_site_ids[each.key]
        ssids                      = try(each.value.ssids, [])
        queuing_profile_id         = local.queuing_profile_ids[try(each.value.queuing_profile, local.defaults.catalyst_center.application_qos.policies.queuing_profile)]
      }
    ],
    can(each.value.global_policy_configuration) ? [
      {
        name                       = "${each.value.name}_global_policy_configuration"
        policy_scope               = each.value.name
        priority                   = tostring(try(each.value.priority, local.defaults.catalyst_center.application_qos.policies.priority, null))
        delete_policy_status       = try(each.value.delete_policy_status, local.defaults.catalyst_center.application_qos.policies.delete_policy_status, null)
        advanced_policy_scope_name = each.value.name
        site_ids                   = local.policy_site_ids[each.key]
        ssids                      = try(each.value.ssids, [])
        clause_type                = "APPLICATION_POLICY_KNOBS"
        device_removal_behavior    = try(each.value.global_policy_configuration.device_removal_behavior, local.defaults.catalyst_center.application_qos.policies.global_policy_configuration.device_removal_behavior, null)
        host_tracking_enabled      = try(each.value.global_policy_configuration.host_tracking_enabled, local.defaults.catalyst_center.application_qos.policies.global_policy_configuration.host_tracking_enabled, null)
      }
    ] : [],
  )

  depends_on = [
    catalystcenter_application_set.application_qos_application_set,
    catalystcenter_application.application_qos_application,
    catalystcenter_app_policy_queuing_profile.application_qos_queuing_profile,
    catalystcenter_area.area_0,
    catalystcenter_building.building,
    catalystcenter_floor.floor,
    data.catalystcenter_sites.created_sites,
  ]
}
