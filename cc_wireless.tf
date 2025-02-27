locals {
  ssid_radio_type_mapping = {
    "Triple Band"     = "Triple band operation(2.4GHz, 5GHz and 6GHz)"
    "5GHz"            = "5GHz only"
    "2.4GHz"          = "2.4GHz only"
    "6GHz"            = "6GHz only"
    "2.4GHz and 5GHz" = "2.4 and 5GHz"
    "2.4GHz and 6GHz" = "2.4 and 6GHz"
    "5GHz and 6GHz"   = "5 and 6GHz"
  }

  wireless_network_profiles = [
    for i in try(local.catalyst_center.network_profiles.wireless, []) : {
      name  = try(i.name, null)
      sites = try(i.sites, null)
    }
  ]

  sites_to_wireless_network_profile = flatten([
    for np in local.wireless_network_profiles : [
      for site in np.sites : {
        "site" : try(site, null)
        "network_profile" : try(np.name, null)
      }
    ]
  ])

  wireless_controllers = length({
    for device in try(local.catalyst_center.inventory.devices, []) : device.name => device if device.state == "PROVISION" && contains(device.fabric_roles, "WIRELESS_CONTROLLER_NODE")
  }) > 0
}

resource "catalystcenter_wireless_ssid" "ssid" {
  for_each = { for ssid in try(local.catalyst_center.wireless.ssids, []) : ssid.name => ssid }

  ssid                                        = each.key
  auth_type                                   = try(each.value.auth_type, local.defaults.catalyst_center.wireless.ssids.auth_type, null)
  wlan_type                                   = try(each.value.wlan_type, local.defaults.catalyst_center.wireless.ssids.wlan_type, null)
  site_id                                     = try(data.catalystcenter_area.global.id, null)
  aaa_override                                = try(each.value.aaa_override, local.defaults.catalyst_center.wireless.ssids.aaa_override, null)
  acct_servers                                = try(each.value.acct_servers, local.defaults.catalyst_center.wireless.ssids.acct_servers, null)
  acl_name                                    = try(each.value.acl_name, local.defaults.catalyst_center.wireless.ssids.acl_name, null)
  ap_beacon_protection                        = try(each.value.ap_beacon_protection, local.defaults.catalyst_center.wireless.ssids.ap_beacon_protection, null)
  auth_key8021x                               = try(each.value.auth_key8021x, local.defaults.catalyst_center.wireless.ssids.auth_key8021x, null)
  auth_key8021x_plus_ft                       = try(each.value.auth_key8021x_plus_ft, local.defaults.catalyst_center.wireless.ssids.auth_key8021x_plus_ft, null)
  auth_key8021x_sha256                        = try(each.value.auth_key8021x_sha256, local.defaults.catalyst_center.wireless.ssids.auth_key8021x_sha256, null)
  auth_key_easy_psk                           = try(each.value.auth_key_easy_psk, local.defaults.catalyst_center.wireless.ssids.auth_key_easy_psk, null)
  auth_key_easy_psk_sha256                    = try(each.value.auth_key_easy_psk_sha256, local.defaults.catalyst_center.wireless.ssids.auth_key_easy_psk_sha256, null)
  auth_key_owe                                = try(each.value.auth_key_owe, local.defaults.catalyst_center.wireless.ssids.auth_key_owe, null)
  auth_key_psk                                = try(each.value.auth_key_psk, local.defaults.catalyst_center.wireless.ssids.auth_key_psk, null)
  auth_key_psk_plus_ft                        = try(each.value.auth_key_psk_plus_ft, local.defaults.catalyst_center.wireless.ssids.auth_key_psk_plus_ft, null)
  auth_key_sae                                = try(each.value.auth_key_sae, local.defaults.catalyst_center.wireless.ssids.auth_key_sae, null)
  auth_key_sae_ext                            = try(each.value.auth_key_sae_ext, local.defaults.catalyst_center.wireless.ssids.auth_key_sae_ext, null)
  auth_key_sae_ext_plus_ft                    = try(each.value.auth_key_sae_ext_plus_ft, local.defaults.catalyst_center.wireless.ssids.auth_key_sae_ext_plus_ft, null)
  auth_key_sae_plus_ft                        = try(each.value.auth_key_sae_plus_ft, local.defaults.catalyst_center.wireless.ssids.auth_key_sae_plus_ft, null)
  auth_key_suite_b1921x                       = try(each.value.auth_key_suite_b1921x, local.defaults.catalyst_center.wireless.ssids.auth_key_suite_b1921x, null)
  auth_key_suite_b1x                          = try(each.value.auth_key_suite_b1x, local.defaults.catalyst_center.wireless.ssids.auth_key_suite_b1x, null)
  auth_server                                 = try(each.value.auth_server, local.defaults.catalyst_center.wireless.ssids.auth_server, null)
  basic_service_set_max_idle                  = try(each.value.basic_service_set_max_idle, local.defaults.catalyst_center.wireless.ssids.basic_service_set_max_idle, null)
  basic_service_set_client_idle_timeout       = try(each.value.basic_service_set_client_idle_timeout, local.defaults.catalyst_center.wireless.ssids.basic_service_set_client_idle_timeout, null)
  broadcast_ssid                              = try(each.value.broadcast_ssid, local.defaults.catalyst_center.wireless.ssids.broadcast_ssid, null)
  cckm                                        = try(each.value.cckm, local.defaults.catalyst_center.wireless.ssids.cckm, null)
  cckm_tsf_tolerance                          = try(each.value.cckm_tsf_tolerance, local.defaults.catalyst_center.wireless.ssids.cckm_tsf_tolerance, null)
  client_exclusion                            = try(each.value.client_exclusion, local.defaults.catalyst_center.wireless.ssids.client_exclusion, null)
  client_exclusion_timeout                    = try(each.value.client_exclusion_timeout, local.defaults.catalyst_center.wireless.enterprise_ssids.client_exclusion_timeout, null)
  client_rate_limit                           = try(each.value.client_rate_limit, local.defaults.catalyst_center.wireless.ssids.client_rate_limit, null)
  coverage_hole_detection                     = try(each.value.coverage_hole_detection, local.defaults.catalyst_center.wireless.ssids.coverage_hole_detection, null)
  directed_multicast_service                  = try(each.value.directed_multicast_service, local.defaults.catalyst_center.wireless.ssids.directed_multicast_service, null)
  egress_qos                                  = try(each.value.egress_qos, local.defaults.catalyst_center.wireless.ssids.egress_qos, null)
  enabled                                     = try(each.value.enabled, local.defaults.catalyst_center.wireless.ssids.enabled, null)
  external_auth_ip_address                    = try(each.value.external_auth_ip_address, local.defaults.catalyst_center.wireless.ssids.external_auth_ip_address, null)
  fast_lane                                   = try(each.value.fast_lane, local.defaults.catalyst_center.wireless.ssids.fast_lane, null)
  fast_transition                             = try(each.value.fast_transition, local.defaults.catalyst_center.wireless.ssids.fast_transition, null)
  fast_transition_over_the_distributed_system = try(each.value.fast_transition_over_the_distributed_system, local.defaults.catalyst_center.wireless.ssids.fast_transition_over_the_distributed_system, null)
  ghz24_policy                                = try(each.value.ghz24_policy, local.defaults.catalyst_center.wireless.ssids.ghz24_policy, null)
  ghz6_policy_client_steering                 = try(each.value.ghz6_policy_client_steering, local.defaults.catalyst_center.wireless.ssids.ghz6_policy_client_steering, null)
  hex                                         = try(each.value.hex, local.defaults.catalyst_center.wireless.ssids.hex, null)
  ingress_qos                                 = try(each.value.ingress_qos, local.defaults.catalyst_center.wireless.ssids.ingress_qos, null)
  l3_auth_type                                = try(each.value.l3_auth_type, local.defaults.catalyst_center.wireless.ssids.l3_auth_type, null)
  mac_filtering                               = try(each.value.mac_filtering, local.defaults.catalyst_center.wireless.ssids.mac_filtering, null)
  mft_client_protection                       = try(each.value.mft_client_protection, local.defaults.catalyst_center.wireless.ssids.mft_client_protection, null)
  multi_psk_settings                          = try(each.value.multi_psk_settings, local.defaults.catalyst_center.wireless.ssids.multi_psk_settings, null)
  nas_options                                 = try(each.value.nas_options, local.defaults.catalyst_center.wireless.ssids.nas_options, null)
  neighbor_list                               = try(each.value.neighbor_list, local.defaults.catalyst_center.wireless.ssids.neighbor_list, null)
  open_ssid                                   = try(each.value.open_ssid, local.defaults.catalyst_center.wireless.ssids.open_ssid, null)
  passphrase                                  = try(each.value.passphrase, local.defaults.catalyst_center.wireless.ssids.passphrase, null)
  posturing                                   = try(each.value.posturing, local.defaults.catalyst_center.wireless.ssids.posturing, null)
  profile_name                                = try(each.value.profile_name, local.defaults.catalyst_center.wireless.ssids.profile_name, null)
  protected_management_frame                  = try(each.value.protected_management_frame, local.defaults.catalyst_center.wireless.ssids.protected_management_frame, null)
  random_mac_filter                           = try(each.value.random_mac_filter, local.defaults.catalyst_center.wireless.ssids.random_mac_filter, null)
  rsn_cipher_suite_ccmp128                    = try(each.value.rsn_cipher_suite_ccmp128, local.defaults.catalyst_center.wireless.ssids.rsn_cipher_suite_ccmp128, null)
  rsn_cipher_suite_gcmp128                    = try(each.value.rsn_cipher_suite_gcmp128, local.defaults.catalyst_center.wireless.ssids.rsn_cipher_suite_gcmp128, null)
  rsn_cipher_suite_ccmp256                    = try(each.value.rsn_cipher_suite_ccmp256, local.defaults.catalyst_center.wireless.ssids.rsn_cipher_suite_ccmp256, null)
  rsn_cipher_suite_gcmp256                    = try(each.value.rsn_cipher_suite_gcmp256, local.defaults.catalyst_center.wireless.ssids.rsn_cipher_suite_gcmp256, null)
  session_timeout                             = try(each.value.session_timeout, local.defaults.catalyst_center.wireless.ssids.session_timeout, null)
  session_timeout_enable                      = try(each.value.session_timeout_enable, local.defaults.catalyst_center.wireless.ssids.session_timeout_enable, null)
  sleeping_client                             = try(each.value.sleeping_client, local.defaults.catalyst_center.wireless.ssids.sleeping_client, null)
  sleeping_client_timeout                     = try(each.value.sleeping_client_timeout, local.defaults.catalyst_center.wireless.ssids.sleeping_client_timeout, null)
  ssid_radio_type                             = try(local.ssid_radio_type_mapping[each.value.ssid_radio_type], local.defaults.catalyst_center.wireless.ssids.ssid_radio_type, null)
  web_passthrough                             = try(each.value.web_passthrough, local.defaults.catalyst_center.wireless.ssids.web_passthrough, null)
  wlan_band_select                            = try(each.value.wlan_band_select, local.defaults.catalyst_center.wireless.ssids.wlan_band_select, null)
}

resource "catalystcenter_wireless_rf_profile" "rf_profile" {
  for_each = { for rf_profile in try(local.catalyst_center.wireless.rf_profiles, []) : rf_profile.name => rf_profile }

  name                              = each.key
  default_rf_profile                = try(each.value.default_rf_profile, local.defaults.catalyst_center.wireless.rf_profiles.default_rf_profile, null)
  enable_radio_type_a               = try(each.value.enable_radio_type_a, local.defaults.catalyst_center.wireless.rf_profiles.enable_radio_type_a, null)
  enable_radio_type_b               = try(each.value.enable_radio_type_b, local.defaults.catalyst_center.wireless.rf_profiles.enable_radio_type_b, null)
  enable_radio_type_c               = try(each.value.enable_radio_type_c, local.defaults.catalyst_center.wireless.rf_profiles.enable_radio_type_c, null)
  channel_width                     = try(each.value.channel_width, local.defaults.catalyst_center.wireless.rf_profiles.channel_width, null)
  enable_custom                     = try(each.value.enable_custom, local.defaults.catalyst_center.wireless.rf_profiles.enable_custom, null)
  enable_brown_field                = try(each.value.enable_brown_field, local.defaults.catalyst_center.wireless.rf_profiles.enable_brown_field, null)
  radio_type_a_parent_profile       = try(each.value.radio_type_a_properties.parent_profile, local.defaults.catalyst_center.wireless.rf_profiles.radio_type_a_properties.parent_profile, null)
  radio_type_a_radio_channels       = try(each.value.radio_type_a_properties.radio_channels, local.defaults.catalyst_center.wireless.rf_profiles.radio_type_a_properties.radio_channels, null)
  radio_type_a_data_rates           = try(each.value.radio_type_a_properties.data_rates, local.defaults.catalyst_center.wireless.rf_profiles.radio_type_a_properties.data_rates, null)
  radio_type_a_mandatory_data_rates = try(each.value.radio_type_a_properties.mandatory_data_rates, local.defaults.catalyst_center.wireless.rf_profiles.radio_type_a_properties.mandatory_data_rates, null)
  radio_type_a_power_threshold_v1   = try(each.value.radio_type_a_properties.power_threshold_v1, local.defaults.catalyst_center.wireless.rf_profiles.radio_type_a_properties.power_threshold_v1, null)
  radio_type_a_rx_sop_threshold     = try(each.value.radio_type_a_properties.rx_sop_threshold, local.defaults.catalyst_center.wireless.rf_profiles.radio_type_a_properties.rx_sop_threshold, null)
  radio_type_a_min_power_level      = try(each.value.radio_type_a_properties.min_power_level, local.defaults.catalyst_center.wireless.rf_profiles.radio_type_a_properties.min_power_level, null)
  radio_type_a_max_power_level      = try(each.value.radio_type_a_properties.max_power_level, local.defaults.catalyst_center.wireless.rf_profiles.radio_type_a_properties.max_power_level, null)
  radio_type_b_parent_profile       = try(each.value.radio_type_b_properties.parent_profile, local.defaults.catalyst_center.wireless.rf_profiles.radio_type_b_properties.parent_profile, null)
  radio_type_b_radio_channels       = try(each.value.radio_type_b_properties.radio_channels, local.defaults.catalyst_center.wireless.rf_profiles.radio_type_b_properties.radio_channels, null)
  radio_type_b_data_rates           = try(each.value.radio_type_b_properties.data_rates, local.defaults.catalyst_center.wireless.rf_profiles.radio_type_b_properties.data_rates, null)
  radio_type_b_mandatory_data_rates = try(each.value.radio_type_b_properties.mandatory_data_rates, local.defaults.catalyst_center.wireless.rf_profiles.radio_type_b_properties.mandatory_data_rates, null)
  radio_type_b_power_threshold_v1   = try(each.value.radio_type_b_properties.power_threshold_v1, local.defaults.catalyst_center.wireless.rf_profiles.radio_type_b_properties.power_threshold_v1, null)
  radio_type_b_rx_sop_threshold     = try(each.value.radio_type_b_properties.rx_sop_threshold, local.defaults.catalyst_center.wireless.rf_profiles.radio_type_b_properties.rx_sop_threshold, null)
  radio_type_b_min_power_level      = try(each.value.radio_type_b_properties.min_power_level, local.defaults.catalyst_center.wireless.rf_profiles.radio_type_b_properties.min_power_level, null)
  radio_type_b_max_power_level      = try(each.value.radio_type_b_properties.max_power_level, local.defaults.catalyst_center.wireless.rf_profiles.radio_type_b_properties.max_power_level, null)
  radio_type_c_parent_profile       = try(each.value.radio_type_c_properties.parent_profile, local.defaults.catalyst_center.wireless.rf_profiles.radio_type_c_properties.parent_profile, null)
  radio_type_c_radio_channels       = try(each.value.radio_type_c_properties.radio_channels, local.defaults.catalyst_center.wireless.rf_profiles.radio_type_c_properties.radio_channels, null)
  radio_type_c_data_rates           = try(each.value.radio_type_c_properties.data_rates, local.defaults.catalyst_center.wireless.rf_profiles.radio_type_c_properties.data_rates, null)
  radio_type_c_mandatory_data_rates = try(each.value.radio_type_c_properties.mandatory_data_rates, local.defaults.catalyst_center.wireless.rf_profiles.radio_type_c_properties.mandatory_data_rates, null)
  radio_type_c_power_threshold_v1   = try(each.value.radio_type_c_properties.power_threshold_v1, local.defaults.catalyst_center.wireless.rf_profiles.radio_type_c_properties.power_threshold_v1, null)
  radio_type_c_rx_sop_threshold     = try(each.value.radio_type_c_properties.rx_sop_threshold, local.defaults.catalyst_center.wireless.rf_profiles.radio_type_c_properties.rx_sop_threshold, null)
  radio_type_c_min_power_level      = try(each.value.radio_type_c_properties.min_power_level, local.defaults.catalyst_center.wireless.rf_profiles.radio_type_c_properties.min_power_level, null)
  radio_type_c_max_power_level      = try(each.value.radio_type_c_properties.max_power_level, local.defaults.catalyst_center.wireless.rf_profiles.radio_type_c_properties.max_power_level, null)

  depends_on = [catalystcenter_wireless_ssid.ssid]
}

resource "catalystcenter_wireless_profile" "wireless_profile" {
  for_each = { for wireless_profile in try(local.catalyst_center.network_profiles.wireless, []) : wireless_profile.name => wireless_profile }

  wireless_profile_name = each.key
  ssid_details = try([for ssid in each.value.ssid_details : {
    ssid_name           = try(ssid.name, null)
    enable_fabric       = try(ssid.enable_fabric, local.defaults.catalyst_center.network_profiles.wireless.ssid_details.enable_fabric, null)
    enable_flex_connect = try(ssid.enable_flex_connect, local.defaults.catalyst_center.network_profiles.wireless.ssid_details.enable_flex_connect, null)
    interface_name      = try(ssid.interface_name, local.defaults.catalyst_center.network_profiles.wireless.ssid_details.interface_name, null)
  }], null)

  depends_on = [catalystcenter_wireless_ssid.ssid]
}

resource "catalystcenter_associate_site_to_network_profile" "site_to_wireless_network_profile" {
  for_each = { for s in try(local.sites_to_wireless_network_profile, []) : "${s.site}#_#${s.network_profile}" => s }

  network_profile_id = catalystcenter_wireless_profile.wireless_profile[each.value.network_profile].id
  site_id            = local.site_id_list[each.value.site]
}