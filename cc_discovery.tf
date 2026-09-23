# Credential IDs for discovery jobs. Per-site states resolve their explicitly
# requested credentials through data sources; global states use module-managed IDs.
locals {
  per_site_mode = !var.manage_global_settings && length(var.managed_sites) != 0

  per_site_discovery_credential_names = toset(flatten([
    for discovery in try(local.catalyst_center.inventory.discovery, []) :
    try(discovery.global_credential_list, [])
    if local.per_site_mode && try(discovery.create_per_site, false)
  ]))

  yaml_cli_credential_names          = toset([for credential in try(local.catalyst_center.network_settings.device_credentials.cli_credentials, []) : credential.name])
  yaml_https_read_credential_names   = toset([for credential in try(local.catalyst_center.network_settings.device_credentials.https_read_credentials, []) : credential.name])
  yaml_https_write_credential_names  = toset([for credential in try(local.catalyst_center.network_settings.device_credentials.https_write_credentials, []) : credential.name])
  yaml_snmpv2_read_credential_names  = toset([for credential in try(local.catalyst_center.network_settings.device_credentials.snmpv2_read_credentials, []) : credential.name])
  yaml_snmpv2_write_credential_names = toset([for credential in try(local.catalyst_center.network_settings.device_credentials.snmpv2_write_credentials, []) : credential.name])
  yaml_snmpv3_credential_names       = toset([for credential in try(local.catalyst_center.network_settings.device_credentials.snmpv3_credentials, []) : credential.name])

  discovery_cli_lookup          = setsubtract(setintersection(local.per_site_discovery_credential_names, local.yaml_cli_credential_names), local.multi_state_non_global_cli_creds)
  discovery_https_read_lookup   = setsubtract(setintersection(local.per_site_discovery_credential_names, local.yaml_https_read_credential_names), local.multi_state_non_global_https_read_creds)
  discovery_https_write_lookup  = setsubtract(setintersection(local.per_site_discovery_credential_names, local.yaml_https_write_credential_names), local.multi_state_non_global_https_write_creds)
  discovery_snmpv2_read_lookup  = setsubtract(setintersection(local.per_site_discovery_credential_names, local.yaml_snmpv2_read_credential_names), local.multi_state_non_global_snmpv2_read_creds)
  discovery_snmpv2_write_lookup = setsubtract(setintersection(local.per_site_discovery_credential_names, local.yaml_snmpv2_write_credential_names), local.multi_state_non_global_snmpv2_write_creds)
  discovery_snmpv3_lookup       = setsubtract(setintersection(local.per_site_discovery_credential_names, local.yaml_snmpv3_credential_names), local.multi_state_non_global_snmpv3_creds)

  all_credential_ids = merge(
    try({ for name, credential in data.catalystcenter_credentials_cli.multi_state_non_global_credentials : name => credential.id }, {}),
    try({ for name, credential in data.catalystcenter_credentials_snmpv2_read.multi_state_non_global_credentials : name => credential.id }, {}),
    try({ for name, credential in data.catalystcenter_credentials_snmpv2_write.multi_state_non_global_credentials : name => credential.id }, {}),
    try({ for name, credential in data.catalystcenter_credentials_snmpv3.multi_state_non_global_credentials : name => credential.id }, {}),
    try({ for name, credential in data.catalystcenter_credentials_https_read.multi_state_non_global_credentials : name => credential.id }, {}),
    try({ for name, credential in data.catalystcenter_credentials_https_write.multi_state_non_global_credentials : name => credential.id }, {}),
    try({ for name, credential in data.catalystcenter_credentials_cli.discovery : name => credential.id }, {}),
    try({ for name, credential in data.catalystcenter_credentials_snmpv2_read.discovery : name => credential.id }, {}),
    try({ for name, credential in data.catalystcenter_credentials_snmpv2_write.discovery : name => credential.id }, {}),
    try({ for name, credential in data.catalystcenter_credentials_snmpv3.discovery : name => credential.id }, {}),
    try({ for name, credential in data.catalystcenter_credentials_https_read.discovery : name => credential.id }, {}),
    try({ for name, credential in data.catalystcenter_credentials_https_write.discovery : name => credential.id }, {}),
    try({ for name, cred in catalystcenter_credentials_cli.cli_credentials : name => cred.id }, {}),
    # SNMP v2 Read credentials
    try({ for name, cred in catalystcenter_credentials_snmpv2_read.snmpv2_read_credentials : name => cred.id }, {}),
    # SNMP v2 Write credentials
    try({ for name, cred in catalystcenter_credentials_snmpv2_write.snmpv2_write_credentials : name => cred.id }, {}),
    # SNMP v3 credentials
    try({ for name, cred in catalystcenter_credentials_snmpv3.snmpv3_credentials : name => cred.id }, {}),
    # HTTPS Read credentials
    try({ for name, cred in catalystcenter_credentials_https_read.https_read_credentials : name => cred.id }, {}),
    # HTTPS Write credentials
    try({ for name, cred in catalystcenter_credentials_https_write.https_write_credentials : name => cred.id }, {})
  )
}

data "catalystcenter_credentials_cli" "discovery" {
  for_each    = local.discovery_cli_lookup
  description = each.value
}

data "catalystcenter_credentials_https_read" "discovery" {
  for_each    = local.discovery_https_read_lookup
  description = each.value
}

data "catalystcenter_credentials_https_write" "discovery" {
  for_each    = local.discovery_https_write_lookup
  description = each.value
}

data "catalystcenter_credentials_snmpv2_read" "discovery" {
  for_each    = local.discovery_snmpv2_read_lookup
  description = each.value
}

data "catalystcenter_credentials_snmpv2_write" "discovery" {
  for_each    = local.discovery_snmpv2_write_lookup
  description = each.value
}

data "catalystcenter_credentials_snmpv3" "discovery" {
  for_each    = local.discovery_snmpv3_lookup
  description = each.value
}

resource "catalystcenter_discovery" "discovery" {
  for_each = { for discovery in try(local.catalyst_center.inventory.discovery, []) : discovery.name => discovery if var.manage_global_settings || (!var.manage_global_settings && length(var.managed_sites) == 0) ||
    (local.per_site_mode && try(discovery.create_per_site, false))
  }
  name                      = each.key
  discovery_type            = try(each.value.type, local.defaults.catalyst_center.inventory.discovery.type, null)
  protocol_order            = try(each.value.protocol_order, local.defaults.catalyst_center.inventory.discovery.protocol_order, null)
  cdp_level                 = try(each.value.cdp_level, local.defaults.catalyst_center.inventory.discovery.cdp_level, null)
  lldp_level                = try(each.value.lldp_level, local.defaults.catalyst_center.inventory.discovery.lldp_level, null)
  enable_password_list      = sensitive(try(each.value.enable_password_list, local.defaults.catalyst_center.inventory.discovery.enable_password_list, null))
  global_credential_id_list = try([for cred in each.value.global_credential_list : local.all_credential_ids[cred]], null)
  http_read_credential      = try(each.value.http_read_credential, local.defaults.catalyst_center.inventory.discovery.http_read_credential, null)
  http_write_credential     = try(each.value.http_write_credential, local.defaults.catalyst_center.inventory.discovery.http_write_credential, null)
  ip_address_list           = try(each.value.ip_address_list, local.defaults.catalyst_center.inventory.discovery.ip_address_list, null)
  ip_filter_list            = try(each.value.ip_filter_list, local.defaults.catalyst_center.inventory.discovery.ip_filter_list, null)
  netconf_port              = try(each.value.netconf_port, local.defaults.catalyst_center.inventory.discovery.netconf_port, null)
  preferred_mgmt_ip_method  = try(each.value.preferred_mgmt_ip_method, local.defaults.catalyst_center.inventory.discovery.preferred_mgmt_ip_method, null)
  retry                     = try(each.value.retry, local.defaults.catalyst_center.inventory.discovery.retry, null)
  snmp_auth_passphrase      = sensitive(try(each.value.snmp_auth_passphrase, local.defaults.catalyst_center.inventory.discovery.snmp_auth_passphrase, null))
  snmp_auth_protocol        = try(each.value.snmp_auth_protocol, local.defaults.catalyst_center.inventory.discovery.snmp_auth_protocol, null)
  snmp_mode                 = try(each.value.snmp_mode, local.defaults.catalyst_center.inventory.discovery.snmp_mode, null)
  snmp_priv_passphrase      = sensitive(try(each.value.snmp_priv_passphrase, local.defaults.catalyst_center.inventory.discovery.snmp_priv_passphrase, null))
  snmp_priv_protocol        = try(each.value.snmp_priv_protocol, local.defaults.catalyst_center.inventory.discovery.snmp_priv_protocol, null)
  snmp_ro_community         = sensitive(try(each.value.snmp_ro_community, local.defaults.catalyst_center.inventory.discovery.snmp_ro_community, null))
  snmp_rw_community         = sensitive(try(each.value.snmp_rw_community, local.defaults.catalyst_center.inventory.discovery.snmp_rw_community, null))
  snmp_ro_community_desc    = try(each.value.snmp_ro_community_desc, local.defaults.catalyst_center.inventory.discovery.snmp_ro_community_desc, null)
  snmp_rw_community_desc    = try(each.value.snmp_rw_community_desc, local.defaults.catalyst_center.inventory.discovery.snmp_rw_community_desc, null)
  snmp_user_name            = try(each.value.snmp_user_name, local.defaults.catalyst_center.inventory.discovery.snmp_user_name, null)
  snmp_version              = try(each.value.snmp_version, local.defaults.catalyst_center.inventory.discovery.snmp_version, null)
  timeout_seconds           = try(each.value.time_out, local.defaults.catalyst_center.inventory.discovery.time_out, null)
  user_name_list            = try(each.value.user_name_list, local.defaults.catalyst_center.inventory.discovery.user_name_list, null)
  password_list             = sensitive(try(each.value.password_list, local.defaults.catalyst_center.inventory.discovery.password_list, null))


  lifecycle {
    ignore_changes = [discovery_type]
  }

  depends_on = [
    catalystcenter_credentials_cli.cli_credentials,
    catalystcenter_credentials_snmpv2_read.snmpv2_read_credentials,
    catalystcenter_credentials_snmpv2_write.snmpv2_write_credentials,
    catalystcenter_credentials_snmpv3.snmpv3_credentials,
    catalystcenter_credentials_https_read.https_read_credentials,
    catalystcenter_credentials_https_write.https_write_credentials
  ]
}

