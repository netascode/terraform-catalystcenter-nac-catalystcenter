locals {
  yaml_templates_directories = flatten([
    for dir in var.templates_directories : [
      for file in fileset(dir, "*.{j2,vlt,vtl}") : "${dir}${file}"
    ]
  ])

  # extract content of template files
  templates_content = {
    for file in local.yaml_templates_directories : split(".", split("/", file)[length(split("/", file)) - 1])[0] => replace(file(file), "\r\n", "\n")
  }

  templates = flatten([
    for project in try(local.catalyst_center.templates.projects, []) : [
      for template in concat(try(project.onboarding_templates, []), try(project.dayn_templates, [])) : merge(template,
        {
          project_name      = project.name
          template_name     = template.name
          redeploy_template = try(template.redeploy_template, local.defaults.catalyst_center.templates.redeploy_template, null)
          template_type     = contains(try(project.onboarding_templates, []), template) ? "onboarding" : "dayn"
        }
      )
    ]
  ])

  project_templates = flatten([
    for project in try(local.catalyst_center.templates.projects, []) : [
      for template in concat(try(project.onboarding_templates, []), try(project.dayn_templates, [])) : {
        project_name  = project.name
        template_name = template.name
      }
    ]
  ])

  composite_templates_list = flatten([
    for project in try(local.catalyst_center.templates.projects, []) : [
      for tmpl in try(project.dayn_templates, []) : [
        {
          "containing_templates" : tmpl.containing_templates
          "template_name" : tmpl.name
        }
      ] if try(tmpl.composite, false) == true
    ]
  ])

  composite_templates_map = {
    for tmpl in local.composite_templates_list : tmpl.template_name => tmpl.containing_templates
  }

  templates_map = { for template in local.templates : template.template_name => template }

  tag_templates = flatten([
    for template in try(local.templates, []) : [
      for tag in try(template.tags, []) : {
        "tag_name" : tag,
        "template_name" : template.template_name
      }
    ] if try(template.tags, null) != null
  ])

  templates_to_tag = [
    for tag_key in distinct([for t in local.tag_templates : t.tag_name]) : {
      "tag_name" : tag_key
      "template_names" : [for t in local.tag_templates : t.template_name if t.tag_name == tag_key]
    }
  ]

  tag_devices = flatten([
    for device in try(local.catalyst_center.inventory.devices, []) : [
      for tag in try(device.tags, []) : {
        "tag_name" : tag,
        "device_name" : device.name
        "device_ip" : device.device_ip
        "fqdn_name" : device.fqdn_name
      }
    ] if try(device.tags, null) != null
  ])

  devices_to_tag = [
    for tag_key in distinct([for t in local.tag_devices : t.tag_name]) : {
      "tag_name" : tag_key
      "device_names" : [for t in local.tag_devices : t.device_name if t.tag_name == tag_key]
      "device_ips" : [for t in local.tag_devices : t.device_ip if t.tag_name == tag_key]
      "fqdn_names" : [for t in local.tag_devices : t.fqdn_name if t.tag_name == tag_key]
    }
  ]

  combined_templates = flatten([
    for device in try(local.catalyst_center.inventory.devices, []) : [
      for template in concat(try(device.dayn_templates.regular, []), try(device.dayn_templates.composite, [])) : [
        {
          "template" : try(template.name, null),
          "name" : try(device.name, null),
          "state" : try(device.state, null),
          "site" : try(device.site, null),
          "device_ip" : try(device.device_ip, null)
          "device_name" : try(device.name, null)
          "redeploy_template" : try(template.redeploy_template, device.dayn_templates.redeploy_template, local.templates_map[template.name].redeploy_template, null)
          "fqdn_name" : try(device.fqdn_name, null)
          "copying_config" : try(template.copying_config, local.defaults.catalyst_center.templates.copying_config, null)
          "force_push_template" : try(template.force_push_template, local.defaults.catalyst_center.templates.force_push_template, null)
        }
      ]
    ]
  ])

  # Group devices by template for deployment
  templates_by_device = {
    for tmpl in distinct([for d in local.combined_templates : d.template]) : tmpl => [
      for d in local.combined_templates : d if d.template == tmpl
    ]
  }
}

resource "catalystcenter_tag" "tag" {
  for_each = { for tag in try(local.catalyst_center.templates.tags, []) : tag.name => tag if var.manage_global_settings || (!var.manage_global_settings && length(var.managed_sites) == 0) }

  name          = each.key
  description   = try(each.value.description, local.defaults.catalyst_center.templates.tags.description, null)
  system_tag    = try(each.value.system_tag, local.defaults.catalyst_center.templates.tags.sytem_tag, null)
  dynamic_rules = try(each.value.dynamic_rules, local.defaults.catalyst_center.templates.tags.dynamic_rules, null)
}

data "catalystcenter_project" "onboarding" {
  name = "Onboarding Configuration"
}

data "catalystcenter_project" "project" {
  for_each = var.manage_global_settings == false && length(var.managed_sites) != 0 ? toset([for project in try(local.catalyst_center.templates.projects, []) : project.name]) : toset([])

  name = each.key
}

data "catalystcenter_template" "template" {
  for_each = var.manage_global_settings == false && length(var.managed_sites) != 0 ? { for template in try(local.project_templates, []) : template.template_name => template.project_name } : {}

  name       = each.key
  project_id = try(catalystcenter_project.project[each.key].id, data.catalystcenter_project.project[each.value].id, null)
}

resource "catalystcenter_project" "project" {
  for_each = { for project in try(local.catalyst_center.templates.projects, []) : project.name => project if project.name != "Onboarding Configuration" && (var.manage_global_settings || (!var.manage_global_settings && length(var.managed_sites) == 0)) }

  name        = each.key
  description = try(each.value.description, null)
}

resource "catalystcenter_template" "regular_template" {
  for_each = { for template in try(concat(local.templates), []) : template.template_name => template if try(template.composite, false) == false && (var.manage_global_settings || (!var.manage_global_settings && length(var.managed_sites) == 0)) }

  name             = each.key
  project_id       = try(catalystcenter_project.project[each.value.project_name].id, data.catalystcenter_project.onboarding.id, null)
  description      = try(each.value.description, local.defaults.catalyst_center.templates.description, null)
  device_types     = try(each.value.device_types, local.defaults.catalyst_center.templates.device_types, null)
  language         = try(each.value.language, local.defaults.catalyst_center.templates.language, null)
  software_type    = try(each.value.software_type, local.defaults.catalyst_center.templates.software_type, null)
  software_version = try(each.value.software_version, local.catalyst_center.templates.software_version, null)
  template_content = local.templates_content[each.key]
  composite        = try(each.value.composite, local.defaults.catalyst_center.templates.composite, null)

  template_params = [for param in try(each.value.variables, []) : {
    parameter_name   = try(param.name, null)
    data_type        = try(param.data_type, local.defaults.catalyst_center.templates.template_params.data_type, null)
    default_value    = try(param.default_value, local.defaults.catalyst_center.templates.template_params.default_value, null)
    description      = try(param.additional_info, local.defaults.catalyst_center.templates.template_params.additional_info, null)
    display_name     = try(param.field_name, local.defaults.catalyst_center.templates.template_params.field_name, null)
    instruction_text = try(param.hint_text, local.defaults.catalyst_center.templates.template_params.hint_text, null)
    not_param        = try(param.not_param, local.defaults.catalyst_center.templates.template_params.not_param, null)
    param_array      = try(param.param_array, local.defaults.catalyst_center.templates.template_params.param_array, null)
    required         = try(param.required, local.defaults.catalyst_center.templates.template_params.required, null)
    selection_type   = try(param.selection_type, local.defaults.catalyst_center.templates.template_params.selection_type, null)
    selection_values = try(param.data_values, local.defaults.catalyst_center.templates.template_params.data_values, null)
    }
  ]
}

resource "time_sleep" "template_wait" {
  count = length(try(local.templates, [])) > 0 && (var.manage_global_settings || (!var.manage_global_settings && length(var.managed_sites) == 0)) ? 1 : 0

  create_duration = "10s"

  depends_on = [catalystcenter_template.regular_template]
}

resource "catalystcenter_template" "composite_template" {
  for_each = { for template in try(concat(local.templates), []) : template.template_name => template if try(template.composite, false) == true && (var.manage_global_settings || (!var.manage_global_settings && length(var.managed_sites) == 0)) }

  name             = each.key
  project_id       = try(catalystcenter_project.project[each.value.project_name].id, data.catalystcenter_project.onboarding.id, null)
  description      = try(each.value.description, local.defaults.catalyst_center.templates.description, null)
  device_types     = try(each.value.device_types, local.defaults.catalyst_center.templates.device_types, null)
  language         = try(each.value.language, local.defaults.catalyst_center.templates.language, null)
  software_type    = try(each.value.software_type, local.defaults.catalyst_center.templates.software_type, null)
  software_version = try(each.value.software_version, local.catalyst_center.templates.software_version, null)
  composite        = try(each.value.composite, local.defaults.catalyst_center.templates.composite, null)

  containing_templates = [for containing_template in try(each.value.containing_templates, []) : {
    name         = containing_template
    id           = try(catalystcenter_template.regular_template[containing_template].id, null)
    language     = try(catalystcenter_template.regular_template[containing_template].language, local.defaults.catalyst_center.templates.language, null)
    project_name = try(each.value.project_name, containing_template.project_name, null)
    }
  ]

  depends_on = [time_sleep.template_wait]
}

resource "catalystcenter_assign_templates_to_tag" "template_to_tag" {
  for_each = { for tag in try(local.templates_to_tag, []) : tag.tag_name => tag if var.manage_global_settings || (!var.manage_global_settings && length(var.managed_sites) == 0) }

  tag_id       = catalystcenter_tag.tag[each.key].id
  template_ids = [for template in each.value.template_names : try(catalystcenter_template.regular_template[template].id, catalystcenter_template.composite_template[template].id, null)]
}

resource "catalystcenter_assign_devices_to_tag" "device_to_tag" {
  for_each = { for tag in try(local.devices_to_tag, []) : tag.tag_name => tag if var.manage_global_settings || (!var.manage_global_settings && length(var.managed_sites) == 0) }

  tag_id = catalystcenter_tag.tag[each.key].id
  device_ids = [
    for i in range(length(each.value.device_names)) : coalesce(
      try(local.device_name_to_id[each.value.device_names[i]], null),
      try(local.device_name_to_id[each.value.fqdn_names[i]], null),
      try(local.device_ip_to_id[each.value.device_ips[i]], null)
    )
  ]
}

resource "catalystcenter_template_version" "regular_commit_version" {
  for_each = { for template in try(concat(local.templates), []) : template.template_name => template if try(template.composite, false) == false && (var.manage_global_settings || (!var.manage_global_settings && length(var.managed_sites) == 0)) }

  template_id = catalystcenter_template.regular_template[each.key].id
  comments    = try(md5(local.templates_content[each.key]), null)

}

locals {
  composite_template_hashes = {
    for key, value in catalystcenter_template.composite_template :
    key => md5(
      join(",", [
        value.project_id,
        value.description,
        value.language,
        value.software_type,
        join(",", [for item in value.containing_templates : item.id])
      ])
    )
  }
}

resource "catalystcenter_template_version" "composite_commit_version" {
  for_each = { for template in try(concat(local.templates), []) : template.template_name => template if try(template.composite, false) == true && (var.manage_global_settings || (!var.manage_global_settings && length(var.managed_sites) == 0)) }

  template_id = catalystcenter_template.composite_template[each.key].id
  comments    = try(md5(local.composite_template_hashes[each.key]), null)
}

resource "catalystcenter_deploy_template" "regular_template_deploy" {
  for_each = {
    for tmpl, devices in local.templates_by_device : tmpl => devices
    if try(local.templates_map[tmpl].composite, false) == false &&
    local.templates_map[tmpl].template_type == "dayn" &&
    length([for d in devices : d if strcontains(d.state, "PROVISION") && contains(local.sites, try(d.site, "NONE"))]) > 0
  }

  template_id         = try(catalystcenter_template.regular_template[each.key].id, data.catalystcenter_template.template[each.key].id)
  redeploy            = try(each.value[0].redeploy_template, local.templates_map[each.key].redeploy_template, "NEVER")
  copying_config      = try(each.value[0].copying_config, local.defaults.catalyst_center.templates.copying_config, null)
  force_push_template = try(each.value[0].force_push_template, local.defaults.catalyst_center.templates.force_push_template, null)
  is_composite        = false

  target_info = [
    for device in each.value : {
      id = coalesce(
        try(lookup(local.device_name_to_id, device.device_name, null), null),
        try(lookup(local.device_name_to_id, device.fqdn_name, null), null),
        try(lookup(local.device_ip_to_id, device.device_ip, null), null)
      )
      type                  = "MANAGED_DEVICE_UUID"
      redeploy              = try(device.redeploy_template, local.templates_map[each.key].redeploy_template, "NEVER")
      versioned_template_id = try(catalystcenter_template_version.regular_commit_version[each.key].id, data.catalystcenter_template.template[device.template].id)
      params = try({
        for item in local.all_devices[device.name].dayn_templates_map[device.template].variables : item.name => item.value
      }, {})
      resource_params = [
        {
          type  = "MANAGED_DEVICE_UUID"
          scope = "RUNTIME"
          value = coalesce(
            try(lookup(local.device_name_to_id, device.device_name, null), null),
            try(lookup(local.device_name_to_id, device.fqdn_name, null), null),
            try(lookup(local.device_ip_to_id, device.device_ip, null), null)
          )
        }
      ]
    } if strcontains(device.state, "PROVISION") && contains(local.sites, try(device.site, "NONE"))
  ]

  depends_on = [catalystcenter_device_role.role, catalystcenter_provision_devices.provision_devices, catalystcenter_provision_device.provision_device, time_sleep.provision_device_wait, catalystcenter_template_version.regular_commit_version]
}

resource "catalystcenter_deploy_template" "composite_template_deploy" {
  for_each = {
    for tmpl, devices in local.templates_by_device : tmpl => devices
    if try(local.templates_map[tmpl].composite, false) == true &&
    local.templates_map[tmpl].template_type == "dayn" &&
    length([for d in devices : d if strcontains(d.state, "PROVISION") && contains(local.sites, try(d.site, "NONE"))]) > 0
  }

  redeploy            = try(each.value[0].redeploy_template, local.templates_map[each.key].redeploy_template, "NEVER")
  template_id         = catalystcenter_template_version.composite_commit_version[each.key].id
  main_template_id    = catalystcenter_template.composite_template[each.key].id
  force_push_template = try(local.templates_map[each.key].force_push_template, local.defaults.catalyst_center.templates.force_push_template, null)
  is_composite        = true

  member_template_deployment_info = [for tmpl in local.composite_templates_map[each.key] : {
    template_id         = catalystcenter_template_version.regular_commit_version[tmpl].id
    main_template_id    = catalystcenter_template.regular_template[tmpl].id
    force_push_template = try(each.value[0].force_push_template, local.defaults.catalyst_center.templates.force_push_template, null)
    is_composite        = try(local.templates_map[tmpl].composite, local.defaults.catalyst_center.templates.composite, null)
    copying_config      = try(each.value[0].copying_config, local.defaults.catalyst_center.templates.copying_config, null)
    target_info = flatten([
      for device in each.value : [
        {
          id = coalesce(
            try(lookup(local.device_name_to_id, device.device_name, null), null),
            try(lookup(local.device_name_to_id, device.fqdn_name, null), null),
            try(lookup(local.device_ip_to_id, device.device_ip, null), null)
          )
          type = "MANAGED_DEVICE_UUID"

          redeploy = try(device.redeploy_template, local.templates_map[each.key].redeploy_template, "NEVER")

          params = { for item in local.all_devices[device.name].dayn_templates_map[device.template].variables : item.name => item.value if item.template_name == tmpl }
          resource_params = [
            {
              type  = "MANAGED_DEVICE_UUID"
              scope = "RUNTIME"
              value = coalesce(
                try(lookup(local.device_name_to_id, device.device_name, null), null),
                try(lookup(local.device_name_to_id, device.fqdn_name, null), null),
                try(lookup(local.device_ip_to_id, device.device_ip, null), null)
              )
            }
          ]
        }
      ] if strcontains(device.state, "PROVISION") && contains(local.sites, try(device.site, "NONE"))
    ])
    }
  ]

  target_info = [
    for device in each.value : {
      id = coalesce(
        try(lookup(local.device_name_to_id, device.device_name, null), null),
        try(lookup(local.device_name_to_id, device.fqdn_name, null), null),
        try(lookup(local.device_ip_to_id, device.device_ip, null), null)
      )
      type   = "MANAGED_DEVICE_UUID"
      params = {}
      resource_params = [
        {
          type  = "MANAGED_DEVICE_UUID"
          scope = "RUNTIME"
          value = coalesce(
            try(lookup(local.device_name_to_id, device.device_name, null), null),
            try(lookup(local.device_name_to_id, device.fqdn_name, null), null),
            try(lookup(local.device_ip_to_id, device.device_ip, null), null)
          )
        }
      ]
    } if strcontains(device.state, "PROVISION") && contains(local.sites, try(device.site, "NONE"))
  ]

  depends_on = [catalystcenter_device_role.role, catalystcenter_provision_devices.provision_devices, catalystcenter_provision_device.provision_device, time_sleep.provision_device_wait, catalystcenter_template_version.composite_commit_version]
}
