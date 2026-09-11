locals {
  # Index inventory devices by name for metadata resolution.
  tp_inventory_by_name = {
    for device in try(local.catalyst_center.inventory.devices, []) :
    device.name => device
  }

  # ---------------------------------------------------------------------------
  # CSV variable sources (Issue #521).
  #
  # `variables_file:` references (at entry level or per device) name a CSV file
  # resolved against the `templates_var_directories` input. Two layouts:
  #   WIDE  (dayn/onboarding): hostname,<var1>,<var2>,...  -> one row per device
  #   TALL  (composite):       hostname,member_template,variable,value
  # Cells containing "|" are split into a list value.
  # ---------------------------------------------------------------------------

  # Glob every *.csv across the configured directories, keyed by BARE filename
  # (basename, extension kept — DM data references the full "foo.csv" name).
  tp_var_csv_files = {
    for file in flatten([
      for dir in var.templates_var_directories : [
        for f in fileset(dir, "*.csv") : "${dir}${f}"
      ]
    ]) : split("/", file)[length(split("/", file)) - 1] => replace(file(file), "\r\n", "\n")
  }

  # WIDE parse: { <hostname> => [ {name, value, template_name}, ... ] } per CSV.
  # Every non-hostname column becomes a variable. `value` is ALWAYS a list
  # (single-element for scalars) so the element type stays consistent; cells
  # containing "|" split into multiple elements. The consumer already unwraps
  # single-element lists, so scalar semantics are preserved. `template_name` is
  # carried as "" so wide and tall elements share one object type (required for
  # the `? :` selection below); dayn/onboarding consumers ignore it. Hostnames
  # are grouped (`...`) and the first row kept, so a tall CSV swept into this map
  # (only dayn/onboarding blocks ever read it) does not error on repeated hosts.
  tp_csv_wide_by_file = {
    for fname, content in local.tp_var_csv_files : fname => {
      for host, rows in {
        for row in csvdecode(content) : row.hostname => row...
        } : host => [
        for col, cell in rows[0] : {
          name          = col
          value         = split("|", cell)
          template_name = ""
        } if col != "hostname"
      ]
    }
  }

  # TALL parse: { <hostname> => [ {name, value, template_name}, ... ] } per CSV.
  # Rows are grouped by hostname; each row carries the member template name so
  # the composite deploy path can route the variable to the right member.
  # `value` is ALWAYS a list (see WIDE note). Column access is guarded with
  # `try(...)` so that non-tall CSVs swept into this map (only composite blocks
  # ever read it) evaluate without error rather than referencing absent columns.
  tp_csv_tall_by_file = {
    for fname, content in local.tp_var_csv_files : fname => {
      for host in distinct([for row in csvdecode(content) : row.hostname]) : host => [
        for row in csvdecode(content) : {
          name          = try(row.variable, "")
          value         = split("|", try(row.value, ""))
          template_name = try(row.member_template, "")
        } if row.hostname == host
      ]
    }
  }

  # All template_provisioning blocks tagged by kind. dayn + onboarding deploy as
  # regular templates; composite deploys through the composite path. `_composite`
  # mirrors the section-derived routing the inventory path uses. `_key` is the
  # canonical module resource-key (bare template name when that name is unique
  # across all projects, else "project#template") — MATCHING `template_lookup`,
  # `templates_by_device`, and the deploy for_each. Using the bare-when-unique
  # form (rather than always project#name) is what lets the provisioning-sourced
  # entries resolve in `local.template_lookup[tmpl]`; otherwise the deploy
  # resources' for_each filter misses and no deploy resource is created.
  tp_template_blocks = concat(
    [for t in try(local.catalyst_center.template_provisioning.dayn_templates, []) : merge(t, { _composite = false, _key = try(local.template_name_counts[t.template_name], 0) == 1 ? t.template_name : "${t.project_name}#${t.template_name}" })],
    [for t in try(local.catalyst_center.template_provisioning.onboarding_templates, []) : merge(t, { _composite = false, _key = try(local.template_name_counts[t.template_name], 0) == 1 ? t.template_name : "${t.project_name}#${t.template_name}" })],
    [for t in try(local.catalyst_center.template_provisioning.composite_templates, []) : merge(t, { _composite = true, _key = try(local.template_name_counts[t.template_name], 0) == 1 ? t.template_name : "${t.project_name}#${t.template_name}" })],
  )

  # Per-(block, device) resolution of a DEVICE-level `variables_file:` into the
  # variable list, using the WIDE or TALL parser per block kind. Empty list when
  # the device has no `variables_file`. Keyed [block._key][device_name].
  tp_prov_device_csv_vars = {
    for block in local.tp_template_blocks : block._key => {
      for d in try(block.devices, []) : d.name => (
        try(d.variables_file, null) == null ? [] : (
          block._composite
          ? try(local.tp_csv_tall_by_file[d.variables_file][d.name], [])
          : try(local.tp_csv_wide_by_file[d.variables_file][d.name], [])
        )
      )
    }
  }

  # Per-(block, device) inline `variables:`, NORMALIZED to the CSV element shape
  # {name, value(list), template_name(string)} so every precedence source below
  # shares one element type (Terraform unifies `? :` branch types). `value` is
  # wrapped to a list; `template_name` is preserved for composites, "" otherwise.
  # The deploy-resource consumer unwraps single-element lists and ignores the
  # empty `template_name` on non-composite templates.
  tp_prov_device_inline_vars = {
    for block in local.tp_template_blocks : block._key => {
      for d in try(block.devices, []) : d.name => [
        for v in try(d.variables, []) : {
          name          = v.name
          value         = try(tolist(v.value), [v.value])
          template_name = try(v.template_name, "")
        }
      ]
    }
  }

  # Flatten to per-(template, device) tuples in the EXACT `combined_templates`
  # shape (cc_templates.tf:164) consumed by local.templates_by_device -> deploy
  # resources. `template` uses the canonical resource-key form (`block._key`),
  # matching combined_templates, template_lookup, and dayn_templates_map keys.
  provisioning_combined_templates = flatten([
    for block in local.tp_template_blocks : [
      for device in try(block.devices, []) : {
        "template"            = block._key
        "template_name"       = block.template_name
        "name"                = device.name
        "state"               = try(local.tp_inventory_by_name[device.name].state, null)
        "site"                = try(local.tp_inventory_by_name[device.name].site, null)
        "device_ip"           = try(local.tp_inventory_by_name[device.name].device_ip, null)
        "device_name"         = device.name
        "redeploy_template"   = try(device.redeploy_template, block.redeploy_template, local.defaults.catalyst_center.template_provisioning.redeploy_template, local.defaults.catalyst_center.templates.redeploy_template, null)
        "fqdn_name"           = try(local.tp_inventory_by_name[device.name].fqdn_name, null)
        "copying_config"      = try(device.copying_config, block.copying_config, local.defaults.catalyst_center.templates.copying_config, null)
        "force_push_template" = try(device.force_push_template, block.force_push_template, local.defaults.catalyst_center.templates.force_push_template, null)
      }
    ]
  ])

  provisioning_dayn_template_keys = distinct(concat(
    [for t in try(local.catalyst_center.template_provisioning.dayn_templates, []) : "${t.project_name}#${t.template_name}"],
    [for t in try(local.catalyst_center.template_provisioning.onboarding_templates, []) : "${t.project_name}#${t.template_name}"],
  ))

  provisioning_composite_template_keys = distinct([
    for t in try(local.catalyst_center.template_provisioning.composite_templates, []) : "${t.project_name}#${t.template_name}"
  ])

  provisioning_dayn_templates_map_by_device = {
    for device_name in distinct([for e in local.provisioning_combined_templates : e.device_name]) :
    device_name => {
      for block in local.tp_template_blocks :
      block._key => {
        name = block.template_name
        # 4-step variable precedence per (template, device) — Issue #521:
        #   1. device inline `variables:`
        #   2. device `variables_file:`  (CSV row for this host)
        #   3. entry-level `variables_file:`  (CSV row for this host)
        #   4. none -> []
        # All three sources are normalized to {name, value(list), template_name}
        # (composite blocks route via template_name; dayn/onboarding leave it "").
        # The first non-empty source wins.
        variables = (
          # 1. device inline
          length(try(local.tp_prov_device_inline_vars[block._key][device_name], [])) > 0
          ? local.tp_prov_device_inline_vars[block._key][device_name]
          # 2. device variables_file
          : length(try(local.tp_prov_device_csv_vars[block._key][device_name], [])) > 0
          ? local.tp_prov_device_csv_vars[block._key][device_name]
          # 3. entry-level variables_file
          : (block._composite
            ? try(local.tp_csv_tall_by_file[block.variables_file][device_name], [])
          : try(local.tp_csv_wide_by_file[block.variables_file][device_name], []))
        )
        copying_config      = try(one([for d in block.devices : d.copying_config if d.name == device_name && try(d.copying_config, null) != null]), null)
        force_push_template = try(one([for d in block.devices : d.force_push_template if d.name == device_name && try(d.force_push_template, null) != null]), null)
      }
      if anytrue([for d in try(block.devices, []) : d.name == device_name])
    }
    if contains(keys(local.tp_inventory_by_name), device_name)
  }
}

