locals {
  ssid_radio_policy_mapping = {
    "Triple Band"        = "Triple band operation(2.4GHz, 5GHz and 6GHz)"
    "Triple Band Select" = "Triple band operation with band select"
    "5GHz"               = "5GHz only"
    "2.4GHz"             = "2.4GHz only"
    "6GHz"               = "6GHz only"
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
}

resource "catalystcenter_wireless_enterprise_ssid" "enteprise_ssid" {
  for_each = { for ssid in try(local.catalyst_center.wireless.enterprise_ssids, []) : ssid.name => ssid }

  name = each.key

  basic_service_set_client_idle_timeout = try(each.value.basic_service_set_client_idle_timeout, local.defaults.catalyst_center.wireless.enterprise_ssids.basic_service_set_client_idle_timeout, null)
  client_exclusion_timeout              = try(each.value.client_exclusion_timeout, local.defaults.catalyst_center.wireless.enterprise_ssids.client_exclusion_timeout, null)
  enable_basic_service_set_max_idle     = try(each.value.enable_basic_service_set_max_idle, local.defaults.catalyst_center.wireless.enterprise_ssids.enable_basic_service_set_max_idle, null)
  enable_broadcast_ssid                 = try(each.value.enable_broadcast_ssid, local.defaults.catalyst_center.wireless.enterprise_ssids.enable_broadcast_ssid, null)
  enable_client_exclusion               = try(each.value.enable_client_exclusion, local.defaults.catalyst_center.wireless.enterprise_ssids.enable_client_exclusion, null)
  enable_directed_multicast_service     = try(each.value.enable_directed_multicast_service, local.defaults.catalyst_center.wireless.enterprise_ssids.enable_directed_multicast_service, null)
  enable_fast_lane                      = try(each.value.enable_fast_lane, local.defaults.catalyst_center.wireless.enterprise_ssids.enable_fast_lane, null)
  enable_mac_filtering                  = try(each.value.enable_mac_filtering, local.defaults.catalyst_center.wireless.enterprise_ssids.enable_mac_filtering, null)
  enable_neighbor_list                  = try(each.value.enable_neighbor_list, local.defaults.catalyst_center.wireless.enterprise_ssids.enable_neighbor_list, null)
  enable_session_time_out               = try(each.value.enable_session_time_out, local.defaults.catalyst_center.wireless.enterprise_ssids.enable_session_time_out, null)
  fast_transition                       = try(each.value.fast_transition, local.defaults.catalyst_center.wireless.enterprise_ssids.fast_transition, null)
  mfp_client_protection                 = try(each.value.mfp_client_protection, local.defaults.catalyst_center.wireless.enterprise_ssids.mfp_client_protection, null)
  nas_options                           = try(each.value.nas_options, local.defaults.catalyst_center.wireless.enterprise_ssids.nas_options, null)
  passphrase                            = try(each.value.passphrase, local.defaults.catalyst_center.wireless.enterprise_ssids.passphrase, null)
  radio_policy                          = try(local.ssid_radio_policy_mapping[each.value.radio_policy], local.defaults.catalyst_center.wireless.enterprise_ssids.radio_policy, null)
  session_time_out                      = try(each.value.session_time_out, local.defaults.catalyst_center.wireless.enterprise_ssids.session_time_out, null)
  traffic_type                          = try(each.value.traffic_type, local.defaults.catalyst_center.wireless.enterprise_ssids.traffic_type, null)
  security_level                        = try(each.value.security_level, local.defaults.catalyst_center.wireless.enterprise_ssids.security_level, null)
  profile_name                          = try(each.value.profile_name, local.defaults.catalyst_center.wireless.enterprise_ssids.profile_name, null)
  policy_profile_name                   = try(each.value.policy_profile_name, local.defaults.catalyst_center.wireless.enterprise_ssids.policy_profile_name, null)
  aaa_override                          = try(each.value.aaa_override, local.defaults.catalyst_center.wireless.enterprise_ssids.aaa_override, null)
  coverage_hole_detection_enable        = try(each.value.coverage_hole_detection_enable, local.defaults.catalyst_center.wireless.enterprise_ssids.coverage_hole_detection_enable, null)
  multi_psk_settings                    = try(each.value.multi_psk_settings, local.defaults.catalyst_center.wireless.enterprise_ssids.multi_psk_settings, null)
  client_rate_limit                     = try(each.value.client_rate_limit, local.defaults.catalyst_center.wireless.enterprise_ssids.client_rate_limit, null)
  auth_key_mgmt                         = try(each.value.auth_key_mgmt, local.defaults.catalyst_center.wireless.enterprise_ssids.auth_key_mgmt, null)
  rsn_cipher_suite_ccmp256              = try(each.value.rsn_cipher_suite_ccmp256, local.defaults.catalyst_center.wireless.enterprise_ssids.rsn_cipher_suite_ccmp256, null)
  rsn_cipher_suite_gcmp256              = try(each.value.rsn_cipher_suite_gcmp256, local.defaults.catalyst_center.wireless.enterprise_ssids.rsn_cipher_suite_gcmp256, null)
  rsn_cipher_suite_gcmp128              = try(each.value.rsn_cipher_suite_gcmp128, local.defaults.catalyst_center.wireless.enterprise_ssids.rsn_cipher_suite_gcmp128, null)
  ghz6_policy_client_steering           = try(each.value.ghz6_policy_client_steering, local.defaults.catalyst_center.wireless.enterprise_ssids.ghz6_policy_client_steering, null)
  ghz24_policy                          = try(each.value.ghz24_policy, local.defaults.catalyst_center.wireless.enterprise_ssids.ghz24_policy, null)

  lifecycle {
    ignore_changes = [ghz24_policy]
  }
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

  depends_on = [catalystcenter_wireless_enterprise_ssid.enteprise_ssid]
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

  depends_on = [catalystcenter_wireless_enterprise_ssid.enteprise_ssid]
}

resource "catalystcenter_associate_site_to_network_profile" "site_to_wireless_network_profile" {
  for_each = { for s in try(local.sites_to_wireless_network_profile, []) : "${s.site}#_#${s.network_profile}" => s }

  network_profile_id = catalystcenter_wireless_profile.wireless_profile[each.value.network_profile].id
  site_id            = local.site_id_list[each.value.site]
}