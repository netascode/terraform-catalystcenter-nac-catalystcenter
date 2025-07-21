locals {
  switching_profile_templates = {
    for profile in try(local.catalyst_center.network_profiles.switching, {}) : profile.name => {
      "templates" : [{
        "type" : "cli.templates"
        "attributes" : [for template_name in try(profile.dayn_templates, []) :
          {
            "template_id" : try(catalystcenter_template.regular_template[template_name].id, catalystcenter_template.composite_template[template_name].id, null)
          }
        ]
        },
        {
          "type" : "day0.templates"
          "attributes" : [for template_name in try(profile.onboarding_templates, []) :
            {
              "template_id" : try(catalystcenter_template.regular_template[template_name].id, catalystcenter_template.composite_template[template_name].id, null)
            }
          ]
      }]
    }
  }

  sites_to_network_profile = flatten([
    for np in try(local.catalyst_center.network_profiles.switching, []) : [
      for site in np.sites : {
        "site" : try(site, null)
        "network_profile" : try(np.name, null)
      }
    ]
  ])
}

resource "catalystcenter_network_profile" "switching_network_profile" {
  for_each = var.manage_global_settings ? local.switching_profile_templates : {}

  name      = each.key
  type      = "switching"
  templates = each.value.templates
}

resource "catalystcenter_associate_site_to_network_profile" "site_to_network_profile" {
  for_each = { for s in try(local.sites_to_network_profile, []) : "${s.site}#_#${s.network_profile}" => s if contains(local.sites, s.site) && length(var.managed_sites) > 0 }

  network_profile_id = catalystcenter_network_profile.switching_network_profile[each.value.network_profile].id
  site_id            = local.site_id_list[each.value.site]
}
