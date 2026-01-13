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
      id = var.use_bulk_api ? local.data_source_created_sites_list[site] : local.site_id_list[site]
    } if contains(local.sites, site) && (var.use_bulk_api ? try(local.data_source_created_sites_list[site], null) != null : try(local.site_id_list[site], null) != null)
  ]

  depends_on = [catalystcenter_area.area_0, catalystcenter_area.area_1, catalystcenter_area.area_2, catalystcenter_area.area_3, catalystcenter_building.building, catalystcenter_floor.floor, catalystcenter_areas.areas, catalystcenter_buildings.buildings, catalystcenter_floors.floors, data.catalystcenter_sites.created_sites]
}
