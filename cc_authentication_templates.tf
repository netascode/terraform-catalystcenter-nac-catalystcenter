resource "catalystcenter_update_authentication_profile" "global_authentication_template" {
  for_each = { for template in try(local.catalyst_center.authentication_templates, []) : template.name => template }

  authentication_profile_name   = each.value.name
  authentication_order          = try(each.value.authentication_order, local.defaults.catalyst_center.authentication_templates.authentication_order, null)
  dot1x_to_mab_fallback_timeout = try(each.value.dot1x_to_mab_fallback_timeout, local.defaults.catalyst_center.authentication_templates.dot1x_to_mab_fallback_timeout, null)
  wake_on_lan                   = try(each.value.wake_on_lan, local.defaults.catalyst_center.authentication_templates.wake_on_lan, null)
  number_of_hosts               = try(each.value.number_of_hosts, local.defaults.catalyst_center.authentication_templates.number_of_hosts, null)
  is_bpdu_guard_enabled         = each.value.name == "Closed Authentication" ? try(each.value.bpdu_guard, local.defaults.catalyst_center.authentication_templates.bpdu_guard, null) : null
  pre_auth_acl_enabled          = each.value.name == "Low Impact" ? try(each.value.pre_auth_acl.enabled, local.defaults.catalyst_center.authentication_templates.pre_auth_acl.enabled, null) : null
  pre_auth_acl_description      = each.value.name == "Low Impact" ? try(each.value.pre_auth_acl.description, local.defaults.catalyst_center.authentication_templates.pre_auth_acl.description, null) : null
  pre_auth_acl_implicit_action  = each.value.name == "Low Impact" ? try(each.value.pre_auth_acl.implicit_action, local.defaults.catalyst_center.authentication_templates.pre_auth_acl.implicit_action, null) : null
  pre_auth_acl_access_contracts = each.value.name == "Low Impact" ? try([for contract in each.value.pre_auth_acl.access_contracts : {
    "action" : contract.action,
    "port" : contract.port,
    "protocol" : contract.protocol
  }], local.defaults.catalyst_center.authentication_templates.pre_auth_acl.access_contracts, null) : null

  lifecycle {
    ignore_changes = [pre_auth_acl_description]
  }
}

resource "catalystcenter_update_authentication_profile" "low_impact" {
  for_each = { for fabric_site in try(local.catalyst_center.fabric.fabric_sites, []) : fabric_site.name => fabric_site if fabric_site.authentication_template.name == "Low Impact" }

  fabric_id                     = try(local.fabric_site_id_list[each.key], null)
  authentication_profile_name   = "Low Impact"
  authentication_order          = try(each.value.authentication_template.authentication_order, local.defaults.catalyst_center.authentication_templates.authentication_order, null)
  dot1x_to_mab_fallback_timeout = try(each.value.authentication_template.dot1x_to_mab_fallback_timeout, local.defaults.catalyst_center.authentication_templates.dot1x_to_mab_fallback_timeout, null)
  wake_on_lan                   = try(each.value.authentication_template.wake_on_lan, local.defaults.catalyst_center.authentication_templates.wake_on_lan, null)
  number_of_hosts               = try(each.value.authentication_template.number_of_hosts, local.defaults.catalyst_center.authentication_templates.number_of_hosts, null)
  pre_auth_acl_enabled          = each.value.authentication_template.name == "Low Impact" ? try(each.value.authentication_template.pre_auth_acl.enabled, local.defaults.catalyst_center.authentication_templates.pre_auth_acl.enabled, null) : null
  pre_auth_acl_description      = each.value.authentication_template.name == "Low Impact" ? try(each.value.authentication_template.pre_auth_acl.description, local.defaults.catalyst_center.authentication_templates.pre_auth_acl.description, null) : null
  pre_auth_acl_implicit_action  = each.value.authentication_template.name == "Low Impact" ? try(each.value.authentication_template.pre_auth_acl.implicit_action, local.defaults.catalyst_center.authentication_templates.pre_auth_acl.implicit_action, null) : null
  pre_auth_acl_access_contracts = each.value.authentication_template.name == "Low Impact" ? try([for contract in each.value.authentication_template.pre_auth_acl.access_contracts : {
    "action" : contract.action,
    "port" : contract.port,
    "protocol" : contract.protocol
  }], local.defaults.catalyst_center.authentication_templates.pre_auth_acl.access_contracts, null) : null

  lifecycle {
    ignore_changes = [pre_auth_acl_description]
  }
}

resource "catalystcenter_update_authentication_profile" "open_authentication" {
  for_each = { for fabric_site in try(local.catalyst_center.fabric.fabric_sites, []) : fabric_site.name => fabric_site if fabric_site.authentication_template.name == "Open Authentication" }

  fabric_id                     = try(local.fabric_site_id_list[each.key], null)
  authentication_profile_name   = "Open Authentication"
  authentication_order          = try(each.value.authentication_template.authentication_order, local.defaults.catalyst_center.authentication_templates.authentication_order, null)
  dot1x_to_mab_fallback_timeout = try(each.value.authentication_template.dot1x_to_mab_fallback_timeout, local.defaults.catalyst_center.authentication_templates.dot1x_to_mab_fallback_timeout, null)
  wake_on_lan                   = try(each.value.authentication_template.wake_on_lan, local.defaults.catalyst_center.authentication_templates.wake_on_lan, null)
  number_of_hosts               = try(each.value.authentication_template.number_of_hosts, local.defaults.catalyst_center.authentication_templates.number_of_hosts, null)
}

resource "catalystcenter_update_authentication_profile" "closed_authentication" {
  for_each = { for fabric_site in try(local.catalyst_center.fabric.fabric_sites, []) : fabric_site.name => fabric_site if fabric_site.authentication_template.name == "Closed Authentication" }

  fabric_id                     = try(local.fabric_site_id_list[each.key], null)
  authentication_profile_name   = "Closed Authentication"
  authentication_order          = try(each.value.authentication_template.authentication_order, local.defaults.catalyst_center.authentication_templates.authentication_order, null)
  dot1x_to_mab_fallback_timeout = try(each.value.authentication_template.dot1x_to_mab_fallback_timeout, local.defaults.catalyst_center.authentication_templates.dot1x_to_mab_fallback_timeout, null)
  wake_on_lan                   = try(each.value.authentication_template.wake_on_lan, local.defaults.catalyst_center.authentication_templates.wake_on_lan, null)
  number_of_hosts               = try(each.value.authentication_template.number_of_hosts, local.defaults.catalyst_center.authentication_templates.number_of_hosts, null)
  is_bpdu_guard_enabled         = try(each.value.authentication_template.bpdu_guard, local.defaults.catalyst_center.authentication_templates.bpdu_guard, null)
}