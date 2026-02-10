locals {
  ssid_radio_type_mapping = {
    "Triple Band"     = "Triple band operation(2.4GHz, 5GHz and 6GHz)"
    "5GHz"            = "5GHz only"
    "2.4GHz"          = "2.4GHz only"
    "6GHz"            = "6GHz only"
    "2.4GHz and 5GHz" = "2.4 and 5 GHz"
    "2.4GHz and 6GHz" = "2.4 and 6 GHz"
    "5GHz and 6GHz"   = "5 and 6 GHz"
  }

  wireless_controllers = length({
    for device in try(local.catalyst_center.inventory.devices, []) : device.name => device if strcontains(device.state, "PROVISION") && contains(try(device.fabric_roles, []), "WIRELESS_CONTROLLER_NODE")
  }) > 0

  # All dot11be profile names referenced in ssid_details
  dot11be_profile_names_referenced = distinct(flatten([
    for np in try(local.catalyst_center.network_profiles.wireless, []) : [
      for ssid in try(np.ssid_details, []) : ssid.dot11be_profile_name
      if try(ssid.dot11be_profile_name, null) != null
    ]
  ]))

  # Profile names defined in YAML (will be managed by Terraform)
  dot11be_profile_names_managed = [for profile in try(local.catalyst_center.wireless.dot11be_profiles, []) : profile.name]

  # Profile names that are referenced but NOT defined in YAML (need to look up existing profiles)
  dot11be_profile_names_existing = [
    for name in local.dot11be_profile_names_referenced : name
    if !contains(local.dot11be_profile_names_managed, name)
  ]
}

# Create 802.11be profiles from YAML configuration
resource "catalystcenter_dot11be_profile" "dot11be_profile" {
  for_each = { for profile in try(local.catalyst_center.wireless.dot11be_profiles, []) : profile.name => profile if var.manage_global_settings || (!var.manage_global_settings && length(var.managed_sites) == 0) }

  profile_name      = each.key
  ofdma_down_link   = try(each.value.ofdma_down_link, local.defaults.catalyst_center.wireless.dot11be_profiles.ofdma_down_link, null)
  ofdma_up_link     = try(each.value.ofdma_up_link, local.defaults.catalyst_center.wireless.dot11be_profiles.ofdma_up_link, null)
  mu_mimo_down_link = try(each.value.mu_mimo_down_link, local.defaults.catalyst_center.wireless.dot11be_profiles.mu_mimo_down_link, null)
  mu_mimo_up_link   = try(each.value.mu_mimo_up_link, local.defaults.catalyst_center.wireless.dot11be_profiles.mu_mimo_up_link, null)
  ofdma_multi_ru    = try(each.value.ofdma_multi_ru, local.defaults.catalyst_center.wireless.dot11be_profiles.ofdma_multi_ru, null)
}

# Look up existing 802.11be profiles (created outside of Terraform)
data "catalystcenter_dot11be_profile" "dot11be_profile" {
  for_each = toset(local.dot11be_profile_names_existing)

  profile_name = each.key
}


data "catalystcenter_wireless_profile" "wireless_profile" {
  for_each = { for wireless_profile in try(local.catalyst_center.network_profiles.wireless, []) : wireless_profile.name => wireless_profile if var.manage_global_settings == false && length(var.managed_sites) != 0 }

  wireless_profile_name = each.key
}
resource "catalystcenter_wireless_ssid" "ssid" {
  for_each = { for ssid in try(local.catalyst_center.wireless.ssids, []) : ssid.name => ssid if var.manage_global_settings || (!var.manage_global_settings && length(var.managed_sites) == 0) }

  ssid                                        = each.key
  auth_type                                   = try(each.value.auth_type, local.defaults.catalyst_center.wireless.ssids.auth_type, null)
  wlan_type                                   = try(each.value.wlan_type, local.defaults.catalyst_center.wireless.ssids.wlan_type, null)
  site_id                                     = try(data.catalystcenter_site.global.id, null)
  aaa_override                                = try(each.value.aaa_override, local.defaults.catalyst_center.wireless.ssids.aaa_override, null)
  acct_servers                                = try(each.value.acct_servers, local.defaults.catalyst_center.wireless.ssids.acct_servers, null)
  auth_servers                                = try(each.value.auth_servers, local.defaults.catalyst_center.wireless.ssids.auth_servers, null)
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
  cckm_tsf_tolerance                          = try(each.value.cckm_tsf_tolerance, 0) == 0 ? null : try(each.value.cckm_tsf_tolerance, local.defaults.catalyst_center.wireless.ssids.cckm_tsf_tolerance, null)
  client_exclusion                            = try(each.value.client_exclusion, local.defaults.catalyst_center.wireless.ssids.client_exclusion, null)
  client_exclusion_timeout                    = try(each.value.client_exclusion_timeout, local.defaults.catalyst_center.wireless.enterprise_ssids.client_exclusion_timeout, null)
  client_rate_limit                           = try(each.value.client_rate_limit, 0) == 0 ? null : try(each.value.client_rate_limit, local.defaults.catalyst_center.wireless.ssids.client_rate_limit, null)
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
  session_timeout                             = try(each.value.session_timeout, 0) == 0 ? null : try(each.value.session_timeout, local.defaults.catalyst_center.wireless.ssids.session_timeout, null)
  session_timeout_enable                      = try(each.value.session_timeout_enable, local.defaults.catalyst_center.wireless.ssids.session_timeout_enable, null)
  sleeping_client                             = try(each.value.sleeping_client, local.defaults.catalyst_center.wireless.ssids.sleeping_client, null)
  sleeping_client_timeout                     = try(each.value.sleeping_client_timeout, local.defaults.catalyst_center.wireless.ssids.sleeping_client_timeout, null)
  ssid_radio_type                             = try(local.ssid_radio_type_mapping[each.value.ssid_radio_type], local.defaults.catalyst_center.wireless.ssids.ssid_radio_type, null)
  web_passthrough                             = try(each.value.web_passthrough, local.defaults.catalyst_center.wireless.ssids.web_passthrough, null)
  wlan_band_select                            = try(each.value.wlan_band_select, local.defaults.catalyst_center.wireless.ssids.wlan_band_select, null)
}

resource "catalystcenter_wireless_rf_profile" "rf_profile" {
  for_each = { for rf_profile in try(local.catalyst_center.wireless.rf_profiles, []) : rf_profile.name => rf_profile if var.manage_global_settings || (!var.manage_global_settings && length(var.managed_sites) == 0) }

  rf_profile_name         = each.key
  default_rf_profile      = try(each.value.default_rf_profile, local.defaults.catalyst_center.wireless.rf_profiles.default_rf_profile, null)
  enable_radio_type_a     = try(each.value.enable_radio_type_a, local.defaults.catalyst_center.wireless.rf_profiles.enable_radio_type_a, null)
  enable_radio_type_b     = try(each.value.enable_radio_type_b, local.defaults.catalyst_center.wireless.rf_profiles.enable_radio_type_b, null)
  enable_radio_type6_g_hz = try(each.value.enable_radio_type_c, local.defaults.catalyst_center.wireless.rf_profiles.enable_radio_type_c, null)

  # Radio Type A Properties (5 GHz)
  radio_type_a_parent_profile          = try(each.value.radio_type_a_properties.parent_profile, local.defaults.catalyst_center.wireless.rf_profiles.radio_type_a_properties.parent_profile, null)
  radio_type_a_radio_channels          = try(each.value.radio_type_a_properties.radio_channels, local.defaults.catalyst_center.wireless.rf_profiles.radio_type_a_properties.radio_channels, null)
  radio_type_a_data_rates              = try(each.value.radio_type_a_properties.data_rates, local.defaults.catalyst_center.wireless.rf_profiles.radio_type_a_properties.data_rates, null)
  radio_type_a_mandatory_data_rates    = try(each.value.radio_type_a_properties.mandatory_data_rates, local.defaults.catalyst_center.wireless.rf_profiles.radio_type_a_properties.mandatory_data_rates, null)
  radio_type_a_power_threshold_v1      = try(each.value.radio_type_a_properties.power_threshold_v1, local.defaults.catalyst_center.wireless.rf_profiles.radio_type_a_properties.power_threshold_v1, null)
  radio_type_a_rx_sop_threshold        = try(each.value.radio_type_a_properties.rx_sop_threshold, local.defaults.catalyst_center.wireless.rf_profiles.radio_type_a_properties.rx_sop_threshold, null)
  radio_type_a_min_power_level         = try(each.value.radio_type_a_properties.min_power_level, local.defaults.catalyst_center.wireless.rf_profiles.radio_type_a_properties.min_power_level, null)
  radio_type_a_max_power_level         = try(each.value.radio_type_a_properties.max_power_level, local.defaults.catalyst_center.wireless.rf_profiles.radio_type_a_properties.max_power_level, null)
  radio_type_a_channel_width           = try(each.value.radio_type_a_properties.channel_width, local.defaults.catalyst_center.wireless.rf_profiles.radio_type_a_properties.channel_width, null)
  radio_type_a_preamble_puncture       = try(each.value.radio_type_a_properties.preamble_puncture, local.defaults.catalyst_center.wireless.rf_profiles.radio_type_a_properties.preamble_puncture, null)
  radio_type_a_zero_wait_dfs_enable    = try(each.value.radio_type_a_properties.zero_wait_dfs_enable, local.defaults.catalyst_center.wireless.rf_profiles.radio_type_a_properties.zero_wait_dfs_enable, null)
  radio_type_a_custom_rx_sop_threshold = try(each.value.radio_type_a_properties.custom_rx_sop_threshold, local.defaults.catalyst_center.wireless.rf_profiles.radio_type_a_properties.custom_rx_sop_threshold, null)
  radio_type_a_max_radio_clients       = try(each.value.radio_type_a_properties.max_radio_clients, local.defaults.catalyst_center.wireless.rf_profiles.radio_type_a_properties.max_radio_clients, null)

  # Radio Type A FRA Properties (5 GHz)
  radio_type_a_fra_properties_client_aware  = try(each.value.radio_type_a_properties.fra_properties_a.client_aware, local.defaults.catalyst_center.wireless.rf_profiles.radio_type_a_properties.fra_properties_a.client_aware, null)
  radio_type_a_fra_properties_client_select = try(each.value.radio_type_a_properties.fra_properties_a.client_select, local.defaults.catalyst_center.wireless.rf_profiles.radio_type_a_properties.fra_properties_a.client_select, null)
  radio_type_a_fra_properties_client_reset  = try(each.value.radio_type_a_properties.fra_properties_a.client_reset, local.defaults.catalyst_center.wireless.rf_profiles.radio_type_a_properties.fra_properties_a.client_reset, null)

  # Radio Type A Coverage Hole Detection Properties (5 GHz)
  radio_type_a_coverage_hole_detection_properties_chd_client_level         = try(each.value.radio_type_a_properties.coverage_hole_detection_properties.chd_client_level, local.defaults.catalyst_center.wireless.rf_profiles.radio_type_a_properties.coverage_hole_detection_properties.chd_client_level, null)
  radio_type_a_coverage_hole_detection_properties_chd_data_rssi_threshold  = try(each.value.radio_type_a_properties.coverage_hole_detection_properties.chd_data_rssi_threshold, local.defaults.catalyst_center.wireless.rf_profiles.radio_type_a_properties.coverage_hole_detection_properties.chd_data_rssi_threshold, null)
  radio_type_a_coverage_hole_detection_properties_chd_voice_rssi_threshold = try(each.value.radio_type_a_properties.coverage_hole_detection_properties.chd_voice_rssi_threshold, local.defaults.catalyst_center.wireless.rf_profiles.radio_type_a_properties.coverage_hole_detection_properties.chd_voice_rssi_threshold, null)
  radio_type_a_coverage_hole_detection_properties_chd_exception_level      = try(each.value.radio_type_a_properties.coverage_hole_detection_properties.chd_exception_level, local.defaults.catalyst_center.wireless.rf_profiles.radio_type_a_properties.coverage_hole_detection_properties.chd_exception_level, null)

  # Radio Type A Spatial Reuse Properties (5 GHz)
  radio_type_a_spatial_reuse_properties_dot11ax_non_srg_obss_packet_detect               = try(each.value.radio_type_a_properties.spatial_reuse_properties.dot11ax_non_srg_obss_packet_detect, local.defaults.catalyst_center.wireless.rf_profiles.radio_type_a_properties.spatial_reuse_properties.dot11ax_non_srg_obss_packet_detect, null)
  radio_type_a_spatial_reuse_properties_dot11ax_non_srg_obss_packet_detect_max_threshold = try(each.value.radio_type_a_properties.spatial_reuse_properties.dot11ax_non_srg_obss_packet_detect_max_threshold, local.defaults.catalyst_center.wireless.rf_profiles.radio_type_a_properties.spatial_reuse_properties.dot11ax_non_srg_obss_packet_detect_max_threshold, null)
  radio_type_a_spatial_reuse_properties_dot11ax_srg_obss_packet_detect                   = try(each.value.radio_type_a_properties.spatial_reuse_properties.dot11ax_srg_obss_packet_detect, local.defaults.catalyst_center.wireless.rf_profiles.radio_type_a_properties.spatial_reuse_properties.dot11ax_srg_obss_packet_detect, null)
  radio_type_a_spatial_reuse_properties_dot11ax_srg_obss_packet_detect_min_threshold     = try(each.value.radio_type_a_properties.spatial_reuse_properties.dot11ax_srg_obss_packet_detect_min_threshold, local.defaults.catalyst_center.wireless.rf_profiles.radio_type_a_properties.spatial_reuse_properties.dot11ax_srg_obss_packet_detect_min_threshold, null)
  radio_type_a_spatial_reuse_properties_dot11ax_srg_obss_packet_detect_max_threshold     = try(each.value.radio_type_a_properties.spatial_reuse_properties.dot11ax_srg_obss_packet_detect_max_threshold, local.defaults.catalyst_center.wireless.rf_profiles.radio_type_a_properties.spatial_reuse_properties.dot11ax_srg_obss_packet_detect_max_threshold, null)

  # Radio Type B Properties (2.4 GHz)
  radio_type_b_parent_profile          = try(each.value.radio_type_b_properties.parent_profile, local.defaults.catalyst_center.wireless.rf_profiles.radio_type_b_properties.parent_profile, null)
  radio_type_b_radio_channels          = try(each.value.radio_type_b_properties.radio_channels, local.defaults.catalyst_center.wireless.rf_profiles.radio_type_b_properties.radio_channels, null)
  radio_type_b_data_rates              = try(each.value.radio_type_b_properties.data_rates, local.defaults.catalyst_center.wireless.rf_profiles.radio_type_b_properties.data_rates, null)
  radio_type_b_mandatory_data_rates    = try(each.value.radio_type_b_properties.mandatory_data_rates, local.defaults.catalyst_center.wireless.rf_profiles.radio_type_b_properties.mandatory_data_rates, null)
  radio_type_b_power_threshold_v1      = try(each.value.radio_type_b_properties.power_threshold_v1, local.defaults.catalyst_center.wireless.rf_profiles.radio_type_b_properties.power_threshold_v1, null)
  radio_type_b_rx_sop_threshold        = try(each.value.radio_type_b_properties.rx_sop_threshold, local.defaults.catalyst_center.wireless.rf_profiles.radio_type_b_properties.rx_sop_threshold, null)
  radio_type_b_min_power_level         = try(each.value.radio_type_b_properties.min_power_level, local.defaults.catalyst_center.wireless.rf_profiles.radio_type_b_properties.min_power_level, null)
  radio_type_b_max_power_level         = try(each.value.radio_type_b_properties.max_power_level, local.defaults.catalyst_center.wireless.rf_profiles.radio_type_b_properties.max_power_level, null)
  radio_type_b_custom_rx_sop_threshold = try(each.value.radio_type_b_properties.custom_rx_sop_threshold, local.defaults.catalyst_center.wireless.rf_profiles.radio_type_b_properties.custom_rx_sop_threshold, null)
  radio_type_b_max_radio_clients       = try(each.value.radio_type_b_properties.max_radio_clients, local.defaults.catalyst_center.wireless.rf_profiles.radio_type_b_properties.max_radio_clients, null)

  # Radio Type B Coverage Hole Detection Properties (2.4 GHz)
  radio_type_b_coverage_hole_detection_properties_chd_client_level         = try(each.value.radio_type_b_properties.coverage_hole_detection_properties.chd_client_level, local.defaults.catalyst_center.wireless.rf_profiles.radio_type_b_properties.coverage_hole_detection_properties.chd_client_level, null)
  radio_type_b_coverage_hole_detection_properties_chd_data_rssi_threshold  = try(each.value.radio_type_b_properties.coverage_hole_detection_properties.chd_data_rssi_threshold, local.defaults.catalyst_center.wireless.rf_profiles.radio_type_b_properties.coverage_hole_detection_properties.chd_data_rssi_threshold, null)
  radio_type_b_coverage_hole_detection_properties_chd_voice_rssi_threshold = try(each.value.radio_type_b_properties.coverage_hole_detection_properties.chd_voice_rssi_threshold, local.defaults.catalyst_center.wireless.rf_profiles.radio_type_b_properties.coverage_hole_detection_properties.chd_voice_rssi_threshold, null)
  radio_type_b_coverage_hole_detection_properties_chd_exception_level      = try(each.value.radio_type_b_properties.coverage_hole_detection_properties.chd_exception_level, local.defaults.catalyst_center.wireless.rf_profiles.radio_type_b_properties.coverage_hole_detection_properties.chd_exception_level, null)

  # Radio Type B Spatial Reuse Properties (2.4 GHz)
  radio_type_b_spatial_reuse_properties_dot11ax_non_srg_obss_packet_detect               = try(each.value.radio_type_b_properties.spatial_reuse_properties.dot11ax_non_srg_obss_packet_detect, local.defaults.catalyst_center.wireless.rf_profiles.radio_type_b_properties.spatial_reuse_properties.dot11ax_non_srg_obss_packet_detect, null)
  radio_type_b_spatial_reuse_properties_dot11ax_non_srg_obss_packet_detect_max_threshold = try(each.value.radio_type_b_properties.spatial_reuse_properties.dot11ax_non_srg_obss_packet_detect_max_threshold, local.defaults.catalyst_center.wireless.rf_profiles.radio_type_b_properties.spatial_reuse_properties.dot11ax_non_srg_obss_packet_detect_max_threshold, null)
  radio_type_b_spatial_reuse_properties_dot11ax_srg_obss_packet_detect                   = try(each.value.radio_type_b_properties.spatial_reuse_properties.dot11ax_srg_obss_packet_detect, local.defaults.catalyst_center.wireless.rf_profiles.radio_type_b_properties.spatial_reuse_properties.dot11ax_srg_obss_packet_detect, null)
  radio_type_b_spatial_reuse_properties_dot11ax_srg_obss_packet_detect_min_threshold     = try(each.value.radio_type_b_properties.spatial_reuse_properties.dot11ax_srg_obss_packet_detect_min_threshold, local.defaults.catalyst_center.wireless.rf_profiles.radio_type_b_properties.spatial_reuse_properties.dot11ax_srg_obss_packet_detect_min_threshold, null)
  radio_type_b_spatial_reuse_properties_dot11ax_srg_obss_packet_detect_max_threshold     = try(each.value.radio_type_b_properties.spatial_reuse_properties.dot11ax_srg_obss_packet_detect_max_threshold, local.defaults.catalyst_center.wireless.rf_profiles.radio_type_b_properties.spatial_reuse_properties.dot11ax_srg_obss_packet_detect_max_threshold, null)

  # Radio Type C (6 GHz) Properties
  radio_type_c_parent_profile                = try(each.value.radio_type_c_properties.parent_profile, local.defaults.catalyst_center.wireless.rf_profiles.radio_type_c_properties.parent_profile, null)
  radio_type_c_radio_channels                = try(each.value.radio_type_c_properties.radio_channels, local.defaults.catalyst_center.wireless.rf_profiles.radio_type_c_properties.radio_channels, null)
  radio_type_c_data_rates                    = try(each.value.radio_type_c_properties.data_rates, local.defaults.catalyst_center.wireless.rf_profiles.radio_type_c_properties.data_rates, null)
  radio_type_c_mandatory_data_rates          = try(each.value.radio_type_c_properties.mandatory_data_rates, local.defaults.catalyst_center.wireless.rf_profiles.radio_type_c_properties.mandatory_data_rates, null)
  radio_type_c_power_threshold_v1            = try(each.value.radio_type_c_properties.power_threshold_v1, local.defaults.catalyst_center.wireless.rf_profiles.radio_type_c_properties.power_threshold_v1, null)
  radio_type_c_rx_sop_threshold              = try(each.value.radio_type_c_properties.rx_sop_threshold, local.defaults.catalyst_center.wireless.rf_profiles.radio_type_c_properties.rx_sop_threshold, null)
  radio_type_c_min_power_level               = try(each.value.radio_type_c_properties.min_power_level, local.defaults.catalyst_center.wireless.rf_profiles.radio_type_c_properties.min_power_level, null)
  radio_type_c_max_power_level               = try(each.value.radio_type_c_properties.max_power_level, local.defaults.catalyst_center.wireless.rf_profiles.radio_type_c_properties.max_power_level, null)
  radio_type_c_enable_standard_power_service = try(each.value.radio_type_c_properties.enable_standard_power_service, local.defaults.catalyst_center.wireless.rf_profiles.radio_type_c_properties.enable_standard_power_service, null)
  radio_type_c_custom_rx_sop_threshold       = try(each.value.radio_type_c_properties.custom_rx_sop_threshold, local.defaults.catalyst_center.wireless.rf_profiles.radio_type_c_properties.custom_rx_sop_threshold, null)
  radio_type_c_max_radio_clients             = try(each.value.radio_type_c_properties.max_radio_clients, local.defaults.catalyst_center.wireless.rf_profiles.radio_type_c_properties.max_radio_clients, null)

  # Radio Type C Multi-BSSID Properties - 802.11ax Parameters
  radio_type_c_multi_bssid_properties_dot11ax_parameters_ofdma_down_link   = try(each.value.radio_type_c_properties.multi_bssid_properties.dot11ax_parameters.ofdma_down_link, local.defaults.catalyst_center.wireless.rf_profiles.radio_type_c_properties.multi_bssid_properties.dot11ax_parameters.ofdma_down_link, null)
  radio_type_c_multi_bssid_properties_dot11ax_parameters_ofdma_up_link     = try(each.value.radio_type_c_properties.multi_bssid_properties.dot11ax_parameters.ofdma_up_link, local.defaults.catalyst_center.wireless.rf_profiles.radio_type_c_properties.multi_bssid_properties.dot11ax_parameters.ofdma_up_link, null)
  radio_type_c_multi_bssid_properties_dot11ax_parameters_mu_mimo_up_link   = try(each.value.radio_type_c_properties.multi_bssid_properties.dot11ax_parameters.mu_mimo_up_link, local.defaults.catalyst_center.wireless.rf_profiles.radio_type_c_properties.multi_bssid_properties.dot11ax_parameters.mu_mimo_up_link, null)
  radio_type_c_multi_bssid_properties_dot11ax_parameters_mu_mimo_down_link = try(each.value.radio_type_c_properties.multi_bssid_properties.dot11ax_parameters.mu_mimo_down_link, local.defaults.catalyst_center.wireless.rf_profiles.radio_type_c_properties.multi_bssid_properties.dot11ax_parameters.mu_mimo_down_link, null)

  # Radio Type C Multi-BSSID Properties - 802.11be Parameters
  radio_type_c_multi_bssid_properties_dot11be_parameters_ofdma_down_link   = try(each.value.radio_type_c_properties.multi_bssid_properties.dot11be_parameters.ofdma_down_link, local.defaults.catalyst_center.wireless.rf_profiles.radio_type_c_properties.multi_bssid_properties.dot11be_parameters.ofdma_down_link, null)
  radio_type_c_multi_bssid_properties_dot11be_parameters_ofdma_up_link     = try(each.value.radio_type_c_properties.multi_bssid_properties.dot11be_parameters.ofdma_up_link, local.defaults.catalyst_center.wireless.rf_profiles.radio_type_c_properties.multi_bssid_properties.dot11be_parameters.ofdma_up_link, null)
  radio_type_c_multi_bssid_properties_dot11be_parameters_mu_mimo_up_link   = try(each.value.radio_type_c_properties.multi_bssid_properties.dot11be_parameters.mu_mimo_up_link, local.defaults.catalyst_center.wireless.rf_profiles.radio_type_c_properties.multi_bssid_properties.dot11be_parameters.mu_mimo_up_link, null)
  radio_type_c_multi_bssid_properties_dot11be_parameters_mu_mimo_down_link = try(each.value.radio_type_c_properties.multi_bssid_properties.dot11be_parameters.mu_mimo_down_link, local.defaults.catalyst_center.wireless.rf_profiles.radio_type_c_properties.multi_bssid_properties.dot11be_parameters.mu_mimo_down_link, null)
  radio_type_c_multi_bssid_properties_dot11be_parameters_ofdma_multi_ru    = try(each.value.radio_type_c_properties.multi_bssid_properties.dot11be_parameters.ofdma_multi_ru, local.defaults.catalyst_center.wireless.rf_profiles.radio_type_c_properties.multi_bssid_properties.dot11be_parameters.ofdma_multi_ru, null)

  # Radio Type C Multi-BSSID Properties - Target Wake Time and TWT Broadcast Support
  radio_type_c_multi_bssid_properties_target_wake_time      = try(each.value.radio_type_c_properties.multi_bssid_properties.target_wake_time, local.defaults.catalyst_center.wireless.rf_profiles.radio_type_c_properties.multi_bssid_properties.target_wake_time, null)
  radio_type_c_multi_bssid_properties_twt_broadcast_support = try(each.value.radio_type_c_properties.multi_bssid_properties.twt_broadcast_support, local.defaults.catalyst_center.wireless.rf_profiles.radio_type_c_properties.multi_bssid_properties.twt_broadcast_support, null)

  # Radio Type C Additional Properties
  radio_type_c_preamble_puncture                 = try(each.value.radio_type_c_properties.preamble_puncture, local.defaults.catalyst_center.wireless.rf_profiles.radio_type_c_properties.preamble_puncture, null)
  radio_type_c_min_dbs_width                     = try(each.value.radio_type_c_properties.min_dbs_width, local.defaults.catalyst_center.wireless.rf_profiles.radio_type_c_properties.min_dbs_width, null)
  radio_type_c_max_dbs_width                     = try(each.value.radio_type_c_properties.max_dbs_width, local.defaults.catalyst_center.wireless.rf_profiles.radio_type_c_properties.max_dbs_width, null)
  radio_type_c_psc_enforcing_enabled             = try(each.value.radio_type_c_properties.psc_enforcing_enabled, local.defaults.catalyst_center.wireless.rf_profiles.radio_type_c_properties.psc_enforcing_enabled, null)
  radio_type_c_discovery_frames_6ghz             = try(each.value.radio_type_c_properties.discovery_frames_6ghz, local.defaults.catalyst_center.wireless.rf_profiles.radio_type_c_properties.discovery_frames_6ghz, null)
  radio_type_c_broadcast_probe_response_interval = try(each.value.radio_type_c_properties.broadcast_probe_response_interval, local.defaults.catalyst_center.wireless.rf_profiles.radio_type_c_properties.broadcast_probe_response_interval, null)

  # Radio Type C FRA Properties
  radio_type_c_fra_properties_client_reset_count           = try(each.value.radio_type_c_properties.fra_properties_c.client_reset_count, local.defaults.catalyst_center.wireless.rf_profiles.radio_type_c_properties.fra_properties_c.client_reset_count, null)
  radio_type_c_fra_properties_client_utilization_threshold = try(each.value.radio_type_c_properties.fra_properties_c.client_utilization_threshold, local.defaults.catalyst_center.wireless.rf_profiles.radio_type_c_properties.fra_properties_c.client_utilization_threshold, null)

  # Radio Type C Coverage Hole Detection Properties
  radio_type_c_coverage_hole_detection_properties_chd_client_level         = try(each.value.radio_type_c_properties.coverage_hole_detection_properties.chd_client_level, local.defaults.catalyst_center.wireless.rf_profiles.radio_type_c_properties.coverage_hole_detection_properties.chd_client_level, null)
  radio_type_c_coverage_hole_detection_properties_chd_data_rssi_threshold  = try(each.value.radio_type_c_properties.coverage_hole_detection_properties.chd_data_rssi_threshold, local.defaults.catalyst_center.wireless.rf_profiles.radio_type_c_properties.coverage_hole_detection_properties.chd_data_rssi_threshold, null)
  radio_type_c_coverage_hole_detection_properties_chd_voice_rssi_threshold = try(each.value.radio_type_c_properties.coverage_hole_detection_properties.chd_voice_rssi_threshold, local.defaults.catalyst_center.wireless.rf_profiles.radio_type_c_properties.coverage_hole_detection_properties.chd_voice_rssi_threshold, null)
  radio_type_c_coverage_hole_detection_properties_chd_exception_level      = try(each.value.radio_type_c_properties.coverage_hole_detection_properties.chd_exception_level, local.defaults.catalyst_center.wireless.rf_profiles.radio_type_c_properties.coverage_hole_detection_properties.chd_exception_level, null)

  # Radio Type C Spatial Reuse Properties (6 GHz)
  radio_type_c_spatial_reuse_properties_dot11ax_non_srg_obss_packet_detect               = try(each.value.radio_type_c_properties.spatial_reuse_properties.dot11ax_non_srg_obss_packet_detect, local.defaults.catalyst_center.wireless.rf_profiles.radio_type_c_properties.spatial_reuse_properties.dot11ax_non_srg_obss_packet_detect, null)
  radio_type_c_spatial_reuse_properties_dot11ax_non_srg_obss_packet_detect_max_threshold = try(each.value.radio_type_c_properties.spatial_reuse_properties.dot11ax_non_srg_obss_packet_detect_max_threshold, local.defaults.catalyst_center.wireless.rf_profiles.radio_type_c_properties.spatial_reuse_properties.dot11ax_non_srg_obss_packet_detect_max_threshold, null)
  radio_type_c_spatial_reuse_properties_dot11ax_srg_obss_packet_detect                   = try(each.value.radio_type_c_properties.spatial_reuse_properties.dot11ax_srg_obss_packet_detect, local.defaults.catalyst_center.wireless.rf_profiles.radio_type_c_properties.spatial_reuse_properties.dot11ax_srg_obss_packet_detect, null)
  radio_type_c_spatial_reuse_properties_dot11ax_srg_obss_packet_detect_min_threshold     = try(each.value.radio_type_c_properties.spatial_reuse_properties.dot11ax_srg_obss_packet_detect_min_threshold, local.defaults.catalyst_center.wireless.rf_profiles.radio_type_c_properties.spatial_reuse_properties.dot11ax_srg_obss_packet_detect_min_threshold, null)
  radio_type_c_spatial_reuse_properties_dot11ax_srg_obss_packet_detect_max_threshold     = try(each.value.radio_type_c_properties.spatial_reuse_properties.dot11ax_srg_obss_packet_detect_max_threshold, local.defaults.catalyst_center.wireless.rf_profiles.radio_type_c_properties.spatial_reuse_properties.dot11ax_srg_obss_packet_detect_max_threshold, null)

  depends_on = [catalystcenter_wireless_ssid.ssid]
}

resource "catalystcenter_wireless_profile" "wireless_profile" {
  for_each = { for wireless_profile in try(local.catalyst_center.network_profiles.wireless, []) : wireless_profile.name => wireless_profile if var.manage_global_settings || (!var.manage_global_settings && length(var.managed_sites) == 0) }

  wireless_profile_name = each.key
  ssid_details = try([for ssid in each.value.ssid_details : {
    ssid_name           = try(ssid.name, null)
    enable_fabric       = try(ssid.enable_fabric, local.defaults.catalyst_center.network_profiles.wireless.ssid_details.enable_fabric, null)
    enable_flex_connect = try(ssid.enable_flex_connect, local.defaults.catalyst_center.network_profiles.wireless.ssid_details.enable_flex_connect, null)
    local_to_vlan       = try(ssid.enable_flex_connect, local.defaults.catalyst_center.network_profiles.wireless.ssid_details.enable_flex_connect, false) == true ? try(ssid.local_to_vlan, local.defaults.catalyst_center.network_profiles.wireless.ssid_details.local_to_vlan, null) : null
    interface_name      = try(ssid.enable_fabric, false) == false ? try(ssid.interface_name, local.defaults.catalyst_center.network_profiles.wireless.ssid_details.interface_name, null) : null
    wlan_profile_name   = try(ssid.wlan_profile_name, local.defaults.catalyst_center.network_profiles.wireless.ssid_details.wlan_profile_name, null)
    # Direct reference to ensure proper dependency tracking - try managed resource first, then data source
    dot11be_profile_id = try(ssid.dot11be_profile_name, null) != null ? try(
      catalystcenter_dot11be_profile.dot11be_profile[ssid.dot11be_profile_name].id,
      data.catalystcenter_dot11be_profile.dot11be_profile[ssid.dot11be_profile_name].id,
      null
    ) : null
  }], null)
  additional_interfaces = try(each.value.additional_interfaces, null)
  ap_zones = try([for ap_zone in each.value.ap_zones : {
    ap_zone_name    = try(ap_zone.name, local.defaults.catalyst_center.network_profiles.wireless.ap_zones.name, null)
    rf_profile_name = try(ap_zone.rf_profile_name, local.defaults.catalyst_center.network_profiles.wireless.ap_zones.rf_profile_name, null)
    ssids           = try(ap_zone.ssids, local.defaults.catalyst_center.network_profiles.wireless.ap_zones.ssids, [])
  }], null)

  depends_on = [catalystcenter_wireless_ssid.ssid, catalystcenter_wireless_interface.interface, catalystcenter_wireless_rf_profile.rf_profile, catalystcenter_dot11be_profile.dot11be_profile]
}

resource "catalystcenter_network_profile_for_sites_assignments" "site_to_wireless_network_profile" {
  for_each = { for np in try(local.catalyst_center.network_profiles.wireless, []) : np.name => np if length(try(np.sites, [])) > 0 && anytrue([for site in np.sites : contains(local.sites, site)]) }

  network_profile_id = try(catalystcenter_wireless_profile.wireless_profile[each.key].id, data.catalystcenter_wireless_profile.wireless_profile[each.key].id)
  items = [
    for site in each.value.sites : {
      id = var.use_bulk_api ? coalesce(try(local.site_id_list_bulk[site], null), local.data_source_created_sites_list[site]) : local.site_id_list[site]
    } if contains(local.sites, site) && (var.use_bulk_api ? try(local.data_source_created_sites_list[site], null) != null : try(local.site_id_list[site], null) != null)
  ]
}

resource "catalystcenter_wireless_interface" "interface" {
  for_each = { for iface in try(local.catalyst_center.wireless.interfaces, []) : iface.name => iface if var.manage_global_settings || (!var.manage_global_settings && length(var.managed_sites) == 0) }

  interface_name = try(each.value.name, local.defaults.catalyst_center.wireless.interfaces.name, null)
  vlan_id        = try(each.value.vlan_id, local.defaults.catalyst_center.wireless.interfaces.vlan_id, null)
}