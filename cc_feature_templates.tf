locals {

  ft_wireless = try(
    local.catalyst_center.feature_templates.wireless,
    local.catalyst_center.templates.feature_templates.wireless,
    {}
  )

  # radio_band: schema (2.4GHz/5GHz/6GHz) -> provider (2_4GHZ/5GHZ/6GHZ)
  ft_cleanair_band_map = {
    "2.4GHz" = "2_4GHZ"
    "5GHz"   = "5GHZ"
    "6GHz"   = "6GHZ"
  }

  # radio_band: schema (2.4GHz_5GHz/5GHz_6GHz) -> provider (2_4GHZ_5GHZ/5GHZ_6GHZ)
  ft_fra_band_map = {
    "2.4GHz_5GHz" = "2_4GHZ_5GHZ"
    "5GHz_6GHz"   = "5GHZ_6GHZ"
  }

  # fra_sensitivity: schema (UPPER_SNAKE) -> provider (Title Case)
  ft_fra_sensitivity_map = {
    "LOW"         = "Low"
    "MEDIUM"      = "Medium"
    "HIGH"        = "High"
    "HIGHER"      = "Higher"
    "EVEN_HIGHER" = "Even Higher"
    "SUPER_HIGH"  = "Super High"
  }

  ft_cleanair = { for c in try(local.ft_wireless.cleanair, []) : c.name => c }
  ft_rrm_fra  = { for f in try(local.ft_wireless.rrm_fra, []) : f.name => f }
}

resource "catalystcenter_wireless_cleanair_configuration" "cleanair" {
  for_each = local.ft_cleanair

  design_name                   = each.value.name
  description                   = try(each.value.description, null)
  radio_band                    = local.ft_cleanair_band_map[each.value.radio_band]
  clean_air                     = try(each.value.enable, local.defaults.catalyst_center.feature_templates.wireless.cleanair.enable, null)
  clean_air_device_reporting    = try(each.value.device_reporting, local.defaults.catalyst_center.feature_templates.wireless.cleanair.device_reporting, null)
  persistent_device_propagation = try(each.value.persistent_device_propagation, local.defaults.catalyst_center.feature_templates.wireless.cleanair.persistent_device_propagation, null)

  ble_beacon                          = try(each.value.interferers.ble_beacon, null)
  bluetooth_paging_inquiry            = try(each.value.interferers.bluetooth_paging_inquiry, null)
  bluetooth_sco_acl                   = try(each.value.interferers.bluetooth_sco_acl, null)
  continuous_transmitter              = try(each.value.interferers.continuous_transmitter, null)
  generic_dect                        = try(each.value.interferers.generic_dect, null)
  generic_tdd                         = try(each.value.interferers.generic_tdd, null)
  jammer                              = try(each.value.interferers.jammer, null)
  microwave_oven                      = try(each.value.interferers.microwave_oven, null)
  motorola_canopy                     = try(each.value.interferers.motorola_canopy, null)
  si_fhss                             = try(each.value.interferers.si_fhss, null)
  spectrum_80211_fh                   = try(each.value.interferers.spectrum_80211_fh, null)
  spectrum_80211_non_standard_channel = try(each.value.interferers.spectrum_80211_non_standard_channel, null)
  spectrum_802154                     = try(each.value.interferers.spectrum_802154, null)
  spectrum_inverted                   = try(each.value.interferers.spectrum_inverted, null)
  super_ag                            = try(each.value.interferers.super_ag, null)
  video_camera                        = try(each.value.interferers.video_camera, null)
  wimax_fixed                         = try(each.value.interferers.wimax_fixed, null)
  wimax_mobile                        = try(each.value.interferers.wimax_mobile, null)
  xbox                                = try(each.value.interferers.xbox, null)
}

resource "catalystcenter_wireless_rrm_fra_configuration" "rrm_fra" {
  for_each = local.ft_rrm_fra

  design_name     = each.value.name
  radio_band      = local.ft_fra_band_map[each.value.radio_band]
  fra_freeze      = try(each.value.fra_freeze, local.defaults.catalyst_center.feature_templates.wireless.rrm_fra.fra_freeze, null)
  fra_status      = try(each.value.fra_status, local.defaults.catalyst_center.feature_templates.wireless.rrm_fra.fra_status, null)
  fra_interval    = try(each.value.fra_interval, local.defaults.catalyst_center.feature_templates.wireless.rrm_fra.fra_interval, null)
  fra_sensitivity = try(local.ft_fra_sensitivity_map[each.value.fra_sensitivity], local.ft_fra_sensitivity_map[local.defaults.catalyst_center.feature_templates.wireless.rrm_fra.fra_sensitivity], null)
}

