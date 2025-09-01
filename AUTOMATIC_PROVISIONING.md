# Automatic Device Provisioning on Template Changes

This document explains how the automatic device provisioning system works in the Terraform Catalyst Center NAC module.

## Overview

The system automatically detects when template content changes and triggers device reprovisioning and template redeployment without manual intervention. This ensures that devices are always configured with the latest template configurations.

## How It Works

### 1. Template Content Detection

The system monitors template files in the `templates_directories` and creates MD5 hashes of their content:

```hcl
# Create content hash triggers for automatic reprovisioning
template_content_triggers = {
  for template_name, content in local.templates_content : template_name => {
    content_hash = md5(content)
    # This will change whenever template content changes, triggering dependent resources
  }
}
```

### 2. Change Detection

When a template file is modified, its MD5 hash changes, which triggers the `null_resource.template_change_trigger` resource:

```hcl
resource "null_resource" "template_change_trigger" {
  for_each = { for device in local.devices_needing_reprovision : "${device.device_name}-${device.template_name}" => device }

  triggers = {
    # This will change whenever template content changes, triggering reprovisioning
    template_content_hash = local.template_content_triggers[each.value.template_name].content_hash
    device_name = each.value.device_name
    template_name = each.value.template_name
  }
}
```

### 3. Automatic Device Reprovisioning

The device provisioning resources use `replace_triggered_by` lifecycle rules to automatically reprovision when templates change:

```hcl
resource "catalystcenter_fabric_provision_device" "provision_device" {
  # ... existing configuration ...

  lifecycle {
    replace_triggered_by = [
      # This will trigger reprovisioning when any template used by this device changes
      for template in try(each.value.dayn_templates.regular, []) : 
        try(module.catalyst_center.null_resource.template_change_trigger["${each.value.name}-${template.name}"], null)
      if contains(keys(try(module.catalyst_center.null_resource.template_change_trigger, {})), "${each.value.name}-${template.name}")
    ]
  }
}
```

### 4. Template Redeployment

Template deployment resources also automatically redeploy when their content changes:

```hcl
resource "catalystcenter_deploy_template" "regular_template_deploy" {
  # ... existing configuration ...

  lifecycle {
    replace_triggered_by = [
      # This will trigger redeployment when the template content changes
      try(null_resource.template_change_trigger["${each.value.name}-${each.value.template}"], null)
    ]
  }
}
```

## Workflow

1. **Template Change**: User modifies a template file (`.j2`, `.vlt`, or `.vtl`)
2. **Hash Update**: Terraform detects the MD5 hash change in `template_content_triggers`
3. **Trigger Activation**: `null_resource.template_change_trigger` is updated
4. **Device Reprovisioning**: Affected devices are automatically reprovisioned
5. **Template Redeployment**: Templates are redeployed to the reprovisioned devices
6. **Configuration Update**: Devices receive the new configuration from updated templates

## Benefits

- **Zero Manual Intervention**: No need to manually trigger reprovisioning
- **Consistency**: Ensures all devices are always up-to-date
- **Reliability**: Automatic detection prevents configuration drift
- **Efficiency**: Only reprovisions devices affected by template changes

## Configuration

The system automatically works with existing configurations. No additional setup is required beyond the standard template and device configurations.

## Monitoring

You can monitor the automatic provisioning process by:

1. **Terraform Plan**: Shows which resources will be replaced due to template changes
2. **Terraform Apply**: Executes the automatic reprovisioning and redeployment
3. **Catalyst Center UI**: Shows device provisioning status and template deployment progress

## Example

When you modify a template file:

```bash
# Edit template file
vim data/templates/switch_config.j2

# Run Terraform
terraform plan
# Shows: catalystcenter_fabric_provision_device.provision_device["switch1"] will be replaced
# Shows: catalystcenter_deploy_template.regular_template_deploy["switch1#_#switch_config"] will be replaced

terraform apply
# Automatically reprovisions devices and redeploys templates
```

## Troubleshooting

If automatic provisioning isn't working:

1. **Check Template Paths**: Ensure templates are in the correct `templates_directories`
2. **Verify Dependencies**: Check that device configurations reference the correct templates
3. **Review Lifecycle Rules**: Ensure `replace_triggered_by` rules are properly configured
4. **Check Terraform State**: Verify that the trigger resources exist in the state

## Limitations

- Only works with Day-N templates (not onboarding templates)
- Requires devices to be in "PROVISION" state
- Template changes trigger full device reprovisioning (not incremental updates)
- Composite templates trigger reprovisioning when any member template changes
