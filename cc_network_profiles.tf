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
}

resource "catalystcenter_network_profile" "switching_network_profile" {
  for_each = var.manage_global_settings || (!var.manage_global_settings && length(var.managed_sites) == 0) ? local.switching_profile_templates : {}

  name      = each.key
  type      = "switching"
  templates = each.value.templates
}

data "catalystcenter_network_profile" "switching_network_profile" {
  for_each = var.manage_global_settings == false && length(var.managed_sites) != 0 ? local.switching_profile_templates : {}

  name = each.key
}

resource "catalystcenter_network_profile_for_sites_assignments" "site_to_network_profile" {
  for_each = { for np in try(local.catalyst_center.network_profiles.switching, []) : np.name => np if length(try(np.sites, [])) > 0 && anytrue([for site in np.sites : contains(local.sites, site)]) }

  network_profile_id = try(catalystcenter_network_profile.switching_network_profile[each.key].id, data.catalystcenter_network_profile.switching_network_profile[each.key].id)
  items = [
    for site in each.value.sites : {
      id = local.site_id_list[site]
    } if contains(local.sites, site)
  ]
}
