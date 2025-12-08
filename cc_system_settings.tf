locals {
  ise_auth_policy_server_tacacs = can(try(local.catalyst_center.system_settings.authentication_and_policy_servers.ise.protocols.tacacs, local.defaults.catalyst_center.system_settings.authentication_and_policy_servers.ise.protocols.tacacs))
  ise_auth_policy_server_radius = can(try(local.catalyst_center.system_settings.authentication_and_policy_servers.ise.protocols.radius, local.defaults.catalyst_center.system_settings.authentication_and_policy_servers.ise.protocols.radius))
}

resource "catalystcenter_authentication_policy_server" "ise" {

  count = length(try(local.catalyst_center.system_settings.authentication_and_policy_servers.ise, [])) > 0 && (var.manage_global_settings || (!var.manage_global_settings && length(var.managed_sites) == 0)) ? 1 : 0

  authentication_port      = try(local.catalyst_center.system_settings.authentication_and_policy_servers.ise.protocols.radius.authentication_port, local.defaults.catalyst_center.system_settings.authentication_and_policy_servers.ise.protocols.radius.authentication_port, null)
  accounting_port          = try(local.catalyst_center.system_settings.authentication_and_policy_servers.ise.protocols.radius.accounting_port, local.defaults.catalyst_center.system_settings.authentication_and_policy_servers.ise.protocols.radius.accounting_port, null)
  ip_address               = try(local.catalyst_center.system_settings.authentication_and_policy_servers.ise.ip_address, local.defaults.catalyst_center.system_settings.authentication_and_policy_servers.ise.ip_address, null)
  pxgrid_enabled           = try(local.catalyst_center.system_settings.authentication_and_policy_servers.ise.pxgrid_enabled, local.defaults.catalyst_center.system_settings.authentication_and_policy_servers.ise.pxgrid_enabled, null)
  use_dnac_cert_for_pxgrid = try(local.catalyst_center.system_settings.authentication_and_policy_servers.ise.use_catc_cert_for_pxgrid, local.defaults.catalyst_center.system_settings.authentication_and_policy_servers.ise.use_catc_cert_for_pxgrid, null)
  is_ise_enabled           = true
  port                     = local.ise_auth_policy_server_tacacs ? try(local.catalyst_center.system_settings.authentication_and_policy_servers.ise.protocols.tacacs.port, local.defaults.catalyst_center.system_settings.authentication_and_policy_servers.ise.protocols.tacacs.port, null) : null
  protocol                 = local.ise_auth_policy_server_radius && local.ise_auth_policy_server_tacacs ? "RADIUS_TACACS" : local.ise_auth_policy_server_tacacs ? "TACACS" : local.ise_auth_policy_server_radius ? "RADIUS" : null
  retries                  = try(local.catalyst_center.system_settings.authentication_and_policy_servers.ise.retries, local.defaults.catalyst_center.system_settings.authentication_and_policy_servers.ise.retries, null)
  timeout_seconds          = try(local.catalyst_center.system_settings.authentication_and_policy_servers.ise.timeout, local.defaults.catalyst_center.system_settings.authentication_and_policy_servers.ise.timeout, null)
  role                     = "primary"
  shared_secret            = try(local.catalyst_center.system_settings.authentication_and_policy_servers.ise.shared_secret, local.defaults.catalyst_center.system_settings.authentication_and_policy_servers.ise.shared_secret, null)
  encryption_scheme        = try(local.catalyst_center.system_settings.authentication_and_policy_servers.ise.protocols.radius.enable_key_wrap, null) != null ? "KEYWRAP" : null
  encryption_key           = try(local.catalyst_center.system_settings.authentication_and_policy_servers.ise.protocols.radius.enable_key_wrap, null) != null ? try(local.catalyst_center.system_settings.authentication_and_policy_servers.ise.protocols.radius.enable_key_wrap.encryption_key, local.defaults.catalyst_center.system_settings.authentication_and_policy_servers.ise.protocols.radius.enable_key_wrap.encryption_key, null) : null
  message_key              = try(local.catalyst_center.system_settings.authentication_and_policy_servers.ise.protocols.radius.enable_key_wrap, null) != null ? try(local.catalyst_center.system_settings.authentication_and_policy_servers.ise.protocols.radius.enable_key_wrap.message_key, local.defaults.catalyst_center.system_settings.authentication_and_policy_servers.ise.protocols.radius.enable_key_wrap.message_key, null) : null

  cisco_ise_dtos = [
    {
      user_name       = try(local.catalyst_center.system_settings.authentication_and_policy_servers.ise.username, local.defaults.catalyst_center.system_settings.authentication_and_policy_servers.ise.username, null)
      password        = try(local.catalyst_center.system_settings.authentication_and_policy_servers.ise.password, local.defaults.catalyst_center.system_settings.authentication_and_policy_servers.ise.password, null)
      fqdn            = try(local.catalyst_center.system_settings.authentication_and_policy_servers.ise.fqdn, local.defaults.catalyst_center.system_settings.authentication_and_policy_servers.ise.fqdn, null)
      ip_address      = try(local.catalyst_center.system_settings.authentication_and_policy_servers.ise.ip_address, local.defaults.catalyst_center.system_settings.authentication_and_policy_servers.ise.ip_address, null)
      subscriber_name = try(local.catalyst_center.system_settings.authentication_and_policy_servers.ise.ip_address, local.defaults.catalyst_center.system_settings.authentication_and_policy_servers.ise.ip_address, null)
    }
  ]
}

resource "catalystcenter_integrate_ise" "ise" {

  count = length(try(local.catalyst_center.system_settings.authentication_and_policy_servers.ise, [])) > 0 && (var.manage_global_settings || (!var.manage_global_settings && length(var.managed_sites) == 0)) ? 1 : 0

  ise_instance_id = catalystcenter_authentication_policy_server.ise[0].id
}

resource "catalystcenter_authentication_policy_server" "aaa" {

  for_each = { for aaa in try(local.catalyst_center.system_settings.authentication_and_policy_servers.aaa, []) : aaa.ip_address => aaa if var.manage_global_settings || (!var.manage_global_settings && length(var.managed_sites) == 0) }

  authentication_port = try(each.value.protocols.radius.authentication_port, local.defaults.catalyst_center.system_settings.authentication_and_policy_servers.aaa.protocols.radius.authentication_port, null)
  accounting_port     = try(each.value.protocols.radius.accounting_port, local.defaults.catalyst_center.system_settings.authentication_and_policy_servers.aaa.protocols.radius.accounting_port, null)
  ip_address          = each.key
  port                = try(each.value.protocols.tacacs.port, local.defaults.catalyst_center.system_settings.authentication_and_policy_servers.aaa.protocols.tacacs.port, null)
  protocol            = can(each.value.protocols.tacacs) && can(each.value.protocols.radius) ? "RADIUS_TACACS" : can(each.value.protocols.tacacs) ? "TACACS" : can(each.value.protocols.radius) ? "RADIUS" : null
  retries             = try(each.value.retries, local.defaults.catalyst_center.system_settings.authentication_and_policy_servers.aaa.retries, null)
  timeout_seconds     = try(each.value.timeout, local.defaults.catalyst_center.system_settings.authentication_and_policy_servers.aaa.timeout, null)
  role                = "primary"
  shared_secret       = try(each.value.shared_secret, local.defaults.catalyst_center.system_settings.authentication_and_policy_servers.aaa.shared_secret, null)
  encryption_scheme   = try(each.value.protocols.radius.enable_key_wrap, null) != null ? "KEYWRAP" : null
  encryption_key      = can(each.value.protocols.radius.enable_key_wrap) ? try(each.value.protocols.radius.enable_key_wrap.encryption_key, local.defaults.catalyst_center.system_settings.authentication_and_policy_servers.aaa.protocols.radius.enable_key_wrap.encryption_key, null) : null
  message_key         = can(each.value.protocols.radius.enable_key_wrap) ? try(each.value.protocols.radius.enable_key_wrap.message_key, local.defaults.catalyst_center.system_settings.authentication_and_policy_servers.aaa.protocols.radius.enable_key_wrap.message_key, null) : null
}