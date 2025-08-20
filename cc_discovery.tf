# Simplified approach: Only use Terraform managed resources for credentials
# This avoids the complexity of mixing managed resources with data sources

locals {
  # Collect all credential IDs from managed resources only
  all_credential_ids = merge(
    # CLI credentials
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

resource "catalystcenter_discovery" "discovery" {
  for_each                  = { for discovery in try(local.catalyst_center.inventory.discovery, []) : discovery.name => discovery }
  name                      = each.key
  discovery_type            = try(each.value.type, local.defaults.catalyst_center.inventory.discovery.type, null)
  protocol_order            = try(each.value.protocol_order, local.defaults.catalyst_center.inventory.discovery.protocol_order, null)
  cdp_level                 = try(each.value.cdp_level, local.defaults.catalyst_center.inventory.discovery.cdp_level, null)
  enable_password_list      = try(each.value.enable_password_list, local.defaults.catalyst_center.inventory.discovery.enable_password_list, null)
  global_credential_id_list = try([for cred in each.value.global_credential_list : local.all_credential_ids[cred]], null)
  http_read_credential      = try(each.value.http_read_credential, local.defaults.catalyst_center.inventory.discovery.http_read_credential, null)
  http_write_credential     = try(each.value.http_write_credential, local.defaults.catalyst_center.inventory.discovery.http_write_credential, null)
  ip_address_list           = try(each.value.ip_address_list, local.defaults.catalyst_center.inventory.discovery.ip_address_list, null)
  ip_filter_list            = try(each.value.ip_filter_list, local.defaults.catalyst_center.inventory.discovery.ip_filter_list, null)
  netconf_port              = try(each.value.netconf_port, local.defaults.catalyst_center.inventory.discovery.netconf_port, null)
  preferred_ip_method       = try(each.value.preferred_ip_method, local.defaults.catalyst_center.inventory.discovery.preferred_ip_method, null)
  retry                     = try(each.value.retry, local.defaults.catalyst_center.inventory.discovery.retry, null)
  snmp_auth_passphrase      = try(each.value.snmp_auth_passphrase, local.defaults.catalyst_center.inventory.discovery.snmp_auth_passphrase, null)
  snmp_auth_protocol        = try(each.value.snmp_auth_protocol, local.defaults.catalyst_center.inventory.discovery.snmp_auth_protocol, null)
  snmp_mode                 = try(each.value.snmp_mode, local.defaults.catalyst_center.inventory.discovery.snmp_mode, null)
  snmp_priv_passphrase      = try(each.value.snmp_priv_passphrase, local.defaults.catalyst_center.inventory.discovery.snmp_priv_passphrase, null)
  snmp_priv_protocol        = try(each.value.snmp_priv_protocol, local.defaults.catalyst_center.inventory.discovery.snmp_priv_protocol, null)
  snmp_ro_community         = try(each.value.snmp_ro_community, local.defaults.catalyst_center.inventory.discovery.snmp_ro_community, null)
  snmp_rw_community         = try(each.value.snmp_rw_community, local.defaults.catalyst_center.inventory.discovery.snmp_rw_community, null)
  snmp_ro_community_desc    = try(each.value.snmp_ro_community_desc, local.defaults.catalyst_center.inventory.discovery.snmp_ro_community_desc, null)
  snmp_rw_community_desc    = try(each.value.snmp_rw_community_desc, local.defaults.catalyst_center.inventory.discovery.snmp_rw_community_desc, null)
  snmp_user_name            = try(each.value.snmp_user_name, local.defaults.catalyst_center.inventory.discovery.snmp_user_name, null)
  snmp_version              = try(each.value.snmp_version, local.defaults.catalyst_center.inventory.discovery.snmp_version, null)
  timeout_seconds           = try(each.value.time_out, local.defaults.catalyst_center.inventory.discovery.time_out, null)
  user_name_list            = try(each.value.user_name_list, local.defaults.catalyst_center.inventory.discovery.user_name_list, null)

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
