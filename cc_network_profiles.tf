locals {
  switching_profile_templates = {
    for profile in try(local.catalyst_center.network_profiles.switching, {}) : profile.name => {
      "templates" : [{
        "type" : "cli.templates"
        "attributes" : [for template in try(profile.dayn_templates, []) :
          {
            "template_id" : try(catalystcenter_template.regular_template[template].id, catalystcenter_template.composite_template[template].id, catalystcenter_template.regular_template[local.template_name_to_key[template]].id, catalystcenter_template.composite_template[local.template_name_to_key[template]].id, null)
          }
        ]
        },
        {
          "type" : "day0.templates"
          "attributes" : [for template in try(profile.onboarding_templates, []) :
            {
              "template_id" : try(catalystcenter_template.regular_template[template].id, catalystcenter_template.composite_template[template].id, catalystcenter_template.regular_template[local.template_name_to_key[template]].id, catalystcenter_template.composite_template[local.template_name_to_key[template]].id, null)
            }
          ]
      }]
    }
  }

  # The new site's root lives outside the flattened area/building/floor list.
  # Admit it for profile assignments in global runs without widening other
  # features' managed-site selection.
  network_profile_assignment_sites = setunion(toset(local.sites), toset(
    var.manage_global_settings || length(var.managed_sites) == 0 ? ["Global"] : []
  ))
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
  for_each = { for np in try(local.catalyst_center.network_profiles.switching, []) : np.name => np if length(try(np.sites, [])) > 0 && anytrue([for site in np.sites : contains(local.network_profile_assignment_sites, site)]) }

  network_profile_id = try(catalystcenter_network_profile.switching_network_profile[each.key].id, data.catalystcenter_network_profile.switching_network_profile[each.key].id)
  items = [
    for site in each.value.sites : {
      id = site == "Global" ? data.catalystcenter_site.global.id : (var.use_bulk_api ? coalesce(local.site_id_list_bulk[site], local.data_source_created_sites_list[site]) : local.site_id_list[site])
    } if contains(local.network_profile_assignment_sites, site)
  ]

  depends_on = [catalystcenter_area.area_0, catalystcenter_area.area_1, catalystcenter_area.area_2, catalystcenter_area.area_3, catalystcenter_area.area_4, catalystcenter_area.area_5, catalystcenter_area.area_6, catalystcenter_area.area_7, catalystcenter_area.area_8, catalystcenter_area.area_9, catalystcenter_building.building, catalystcenter_floor.floor, catalystcenter_areas.bulk_areas, catalystcenter_buildings.bulk_buildings, catalystcenter_floors.bulk_floors, data.catalystcenter_sites.created_sites]
}