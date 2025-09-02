<!-- BEGIN_TF_DOCS -->
# Terraform Network-as-Code Cisco Catalyst Center Module

A Terraform module to configure Cisco Catalyst Center.

## Usage

This module supports an inventory driven approach, where a complete Catalyst Center configuration or parts of it are either modeled in one or more YAML files or natively using Terraform variables.

## Examples

Configuring an area under `Design -> Network Hierarchy` using YAML:

#### `area.yaml`

```yaml
---
catalyst_center:
  sites:
    areas:
      - name: Site1
        parent_name: Global
```

#### `main.tf`

```hcl
module "catalystcenter" {
  source  = "netascode/nac-catalystcenter/catalystcenter"
  version = "0.1.1"

  yaml_files = ["area.yaml"]
}
```

## Requirements

| Name | Version |
|------|---------|
| <a name="requirement_terraform"></a> [terraform](#requirement\_terraform) | >= 1.8.0 |
| <a name="requirement_catalystcenter"></a> [catalystcenter](#requirement\_catalystcenter) | >= 0.3.2 |
| <a name="requirement_local"></a> [local](#requirement\_local) | >= 2.3.0 |
| <a name="requirement_time"></a> [time](#requirement\_time) | >= 0.12.1 |
| <a name="requirement_utils"></a> [utils](#requirement\_utils) | >= 1.0.0 |
## Inputs

| Name | Description | Type | Default | Required |
|------|-------------|------|---------|:--------:|
| <a name="input_manage_global_settings"></a> [manage\_global\_settings](#input\_manage\_global\_settings) | Flag indicating whether global settings should be managed, used in combination with managed\_sites. | `bool` | `false` | no |
| <a name="input_manage_specific_sites_only"></a> [manage\_specific\_sites\_only](#input\_manage\_specific\_sites\_only) | If true, manage only the specified site listed in managed\_sites. If false, also manage all child sites under each managed site. | `bool` | `false` | no |
| <a name="input_managed_sites"></a> [managed\_sites](#input\_managed\_sites) | List of sites to be managed. By default all sites will be managed. | `list(string)` | `[]` | no |
| <a name="input_model"></a> [model](#input\_model) | As an alternative to YAML files, a native Terraform data structure can be provided as well. | `map(any)` | `{}` | no |
| <a name="input_templates_directories"></a> [templates\_directories](#input\_templates\_directories) | List of paths to templates directories. | `list(string)` | `[]` | no |
| <a name="input_write_default_values_file"></a> [write\_default\_values\_file](#input\_write\_default\_values\_file) | Write all default values to a YAML file. Value is a path pointing to the file to be created. | `string` | `""` | no |
| <a name="input_yaml_directories"></a> [yaml\_directories](#input\_yaml\_directories) | List of paths to YAML directories. | `list(string)` | `[]` | no |
| <a name="input_yaml_files"></a> [yaml\_files](#input\_yaml\_files) | List of paths to YAML files. | `list(string)` | `[]` | no |
## Outputs

| Name | Description |
|------|-------------|
| <a name="output_default_values"></a> [default\_values](#output\_default\_values) | All default values. |
| <a name="output_model"></a> [model](#output\_model) | Full model. |
| <a name="output_sites"></a> [sites](#output\_sites) | List of sites to be managed |
## Resources

| Name | Type |
|------|------|
| [catalystcenter_aaa_settings.aaa_servers](https://registry.terraform.io/providers/CiscoDevNet/catalystcenter/latest/docs/resources/aaa_settings) | resource |
| [catalystcenter_aaa_settings.global_aaa_servers](https://registry.terraform.io/providers/CiscoDevNet/catalystcenter/latest/docs/resources/aaa_settings) | resource |
| [catalystcenter_anycast_gateway.anycast_gateway](https://registry.terraform.io/providers/CiscoDevNet/catalystcenter/latest/docs/resources/anycast_gateway) | resource |
| [catalystcenter_area.area_0](https://registry.terraform.io/providers/CiscoDevNet/catalystcenter/latest/docs/resources/area) | resource |
| [catalystcenter_area.area_1](https://registry.terraform.io/providers/CiscoDevNet/catalystcenter/latest/docs/resources/area) | resource |
| [catalystcenter_area.area_2](https://registry.terraform.io/providers/CiscoDevNet/catalystcenter/latest/docs/resources/area) | resource |
| [catalystcenter_area.area_3](https://registry.terraform.io/providers/CiscoDevNet/catalystcenter/latest/docs/resources/area) | resource |
| [catalystcenter_assign_credentials.assign_credentials](https://registry.terraform.io/providers/CiscoDevNet/catalystcenter/latest/docs/resources/assign_credentials) | resource |
| [catalystcenter_assign_credentials.global_assign_credentials](https://registry.terraform.io/providers/CiscoDevNet/catalystcenter/latest/docs/resources/assign_credentials) | resource |
| [catalystcenter_assign_device_to_site.devices_to_site](https://registry.terraform.io/providers/CiscoDevNet/catalystcenter/latest/docs/resources/assign_device_to_site) | resource |
| [catalystcenter_assign_device_to_site.wireless_devices_to_site](https://registry.terraform.io/providers/CiscoDevNet/catalystcenter/latest/docs/resources/assign_device_to_site) | resource |
| [catalystcenter_assign_devices_to_tag.device_to_tag](https://registry.terraform.io/providers/CiscoDevNet/catalystcenter/latest/docs/resources/assign_devices_to_tag) | resource |
| [catalystcenter_assign_managed_ap_locations.managed_ap_locations](https://registry.terraform.io/providers/CiscoDevNet/catalystcenter/latest/docs/resources/assign_managed_ap_locations) | resource |
| [catalystcenter_assign_templates_to_tag.template_to_tag](https://registry.terraform.io/providers/CiscoDevNet/catalystcenter/latest/docs/resources/assign_templates_to_tag) | resource |
| [catalystcenter_banner_settings.banner](https://registry.terraform.io/providers/CiscoDevNet/catalystcenter/latest/docs/resources/banner_settings) | resource |
| [catalystcenter_banner_settings.global_banner](https://registry.terraform.io/providers/CiscoDevNet/catalystcenter/latest/docs/resources/banner_settings) | resource |
| [catalystcenter_building.building](https://registry.terraform.io/providers/CiscoDevNet/catalystcenter/latest/docs/resources/building) | resource |
| [catalystcenter_credentials_cli.cli_credentials](https://registry.terraform.io/providers/CiscoDevNet/catalystcenter/latest/docs/resources/credentials_cli) | resource |
| [catalystcenter_credentials_https_read.https_read_credentials](https://registry.terraform.io/providers/CiscoDevNet/catalystcenter/latest/docs/resources/credentials_https_read) | resource |
| [catalystcenter_credentials_https_write.https_write_credentials](https://registry.terraform.io/providers/CiscoDevNet/catalystcenter/latest/docs/resources/credentials_https_write) | resource |
| [catalystcenter_credentials_snmpv2_read.snmpv2_read_credentials](https://registry.terraform.io/providers/CiscoDevNet/catalystcenter/latest/docs/resources/credentials_snmpv2_read) | resource |
| [catalystcenter_credentials_snmpv2_write.snmpv2_write_credentials](https://registry.terraform.io/providers/CiscoDevNet/catalystcenter/latest/docs/resources/credentials_snmpv2_write) | resource |
| [catalystcenter_credentials_snmpv3.snmpv3_credentials](https://registry.terraform.io/providers/CiscoDevNet/catalystcenter/latest/docs/resources/credentials_snmpv3) | resource |
| [catalystcenter_deploy_template.composite_template_deploy](https://registry.terraform.io/providers/CiscoDevNet/catalystcenter/latest/docs/resources/deploy_template) | resource |
| [catalystcenter_deploy_template.composite_template_redeploy](https://registry.terraform.io/providers/CiscoDevNet/catalystcenter/latest/docs/resources/deploy_template) | resource |
| [catalystcenter_deploy_template.regular_template_deploy](https://registry.terraform.io/providers/CiscoDevNet/catalystcenter/latest/docs/resources/deploy_template) | resource |
| [catalystcenter_deploy_template.regular_template_redeploy](https://registry.terraform.io/providers/CiscoDevNet/catalystcenter/latest/docs/resources/deploy_template) | resource |
| [catalystcenter_device_role.role](https://registry.terraform.io/providers/CiscoDevNet/catalystcenter/latest/docs/resources/device_role) | resource |
| [catalystcenter_dhcp_settings.dhcp_servers](https://registry.terraform.io/providers/CiscoDevNet/catalystcenter/latest/docs/resources/dhcp_settings) | resource |
| [catalystcenter_dhcp_settings.global_dhcp_servers](https://registry.terraform.io/providers/CiscoDevNet/catalystcenter/latest/docs/resources/dhcp_settings) | resource |
| [catalystcenter_discovery.discovery](https://registry.terraform.io/providers/CiscoDevNet/catalystcenter/latest/docs/resources/discovery) | resource |
| [catalystcenter_dns_settings.dns_settings](https://registry.terraform.io/providers/CiscoDevNet/catalystcenter/latest/docs/resources/dns_settings) | resource |
| [catalystcenter_dns_settings.global_dns_settings](https://registry.terraform.io/providers/CiscoDevNet/catalystcenter/latest/docs/resources/dns_settings) | resource |
| [catalystcenter_fabric_device.border_device](https://registry.terraform.io/providers/CiscoDevNet/catalystcenter/latest/docs/resources/fabric_device) | resource |
| [catalystcenter_fabric_device.edge_device](https://registry.terraform.io/providers/CiscoDevNet/catalystcenter/latest/docs/resources/fabric_device) | resource |
| [catalystcenter_fabric_device.wireless_controller](https://registry.terraform.io/providers/CiscoDevNet/catalystcenter/latest/docs/resources/fabric_device) | resource |
| [catalystcenter_fabric_l2_handoff.l2_handoff](https://registry.terraform.io/providers/CiscoDevNet/catalystcenter/latest/docs/resources/fabric_l2_handoff) | resource |
| [catalystcenter_fabric_l2_handoff.l2_handoff_no_anycast](https://registry.terraform.io/providers/CiscoDevNet/catalystcenter/latest/docs/resources/fabric_l2_handoff) | resource |
| [catalystcenter_fabric_l2_virtual_network.l2_vn](https://registry.terraform.io/providers/CiscoDevNet/catalystcenter/latest/docs/resources/fabric_l2_virtual_network) | resource |
| [catalystcenter_fabric_l3_handoff_ip_transits.l3_handoff_ip_transits](https://registry.terraform.io/providers/CiscoDevNet/catalystcenter/latest/docs/resources/fabric_l3_handoff_ip_transits) | resource |
| [catalystcenter_fabric_l3_handoff_sda_transit.sda_transit](https://registry.terraform.io/providers/CiscoDevNet/catalystcenter/latest/docs/resources/fabric_l3_handoff_sda_transit) | resource |
| [catalystcenter_fabric_l3_virtual_network.global_l3_vn](https://registry.terraform.io/providers/CiscoDevNet/catalystcenter/latest/docs/resources/fabric_l3_virtual_network) | resource |
| [catalystcenter_fabric_l3_virtual_network.l3_vn](https://registry.terraform.io/providers/CiscoDevNet/catalystcenter/latest/docs/resources/fabric_l3_virtual_network) | resource |
| [catalystcenter_fabric_port_assignments.port_assignments](https://registry.terraform.io/providers/CiscoDevNet/catalystcenter/latest/docs/resources/fabric_port_assignments) | resource |
| [catalystcenter_fabric_provision_device.provision_device](https://registry.terraform.io/providers/CiscoDevNet/catalystcenter/latest/docs/resources/fabric_provision_device) | resource |
| [catalystcenter_fabric_site.fabric_site](https://registry.terraform.io/providers/CiscoDevNet/catalystcenter/latest/docs/resources/fabric_site) | resource |
| [catalystcenter_fabric_vlan_to_ssid.vlan_to_ssid](https://registry.terraform.io/providers/CiscoDevNet/catalystcenter/latest/docs/resources/fabric_vlan_to_ssid) | resource |
| [catalystcenter_fabric_zone.fabric_zone](https://registry.terraform.io/providers/CiscoDevNet/catalystcenter/latest/docs/resources/fabric_zone) | resource |
| [catalystcenter_floor.floor](https://registry.terraform.io/providers/CiscoDevNet/catalystcenter/latest/docs/resources/floor) | resource |
| [catalystcenter_ip_pool.ip_pool_v4](https://registry.terraform.io/providers/CiscoDevNet/catalystcenter/latest/docs/resources/ip_pool) | resource |
| [catalystcenter_ip_pool.ip_pool_v6](https://registry.terraform.io/providers/CiscoDevNet/catalystcenter/latest/docs/resources/ip_pool) | resource |
| [catalystcenter_ip_pool_reservation.pool_reservation](https://registry.terraform.io/providers/CiscoDevNet/catalystcenter/latest/docs/resources/ip_pool_reservation) | resource |
| [catalystcenter_lan_automation.lanauto_edge](https://registry.terraform.io/providers/CiscoDevNet/catalystcenter/latest/docs/resources/lan_automation) | resource |
| [catalystcenter_lan_automation.lanauto_link](https://registry.terraform.io/providers/CiscoDevNet/catalystcenter/latest/docs/resources/lan_automation) | resource |
| [catalystcenter_network_profile.switching_network_profile](https://registry.terraform.io/providers/CiscoDevNet/catalystcenter/latest/docs/resources/network_profile) | resource |
| [catalystcenter_network_profile_for_sites_assignments.site_to_network_profile](https://registry.terraform.io/providers/CiscoDevNet/catalystcenter/latest/docs/resources/network_profile_for_sites_assignments) | resource |
| [catalystcenter_network_profile_for_sites_assignments.site_to_wireless_network_profile](https://registry.terraform.io/providers/CiscoDevNet/catalystcenter/latest/docs/resources/network_profile_for_sites_assignments) | resource |
| [catalystcenter_ntp_settings.global_ntp_servers](https://registry.terraform.io/providers/CiscoDevNet/catalystcenter/latest/docs/resources/ntp_settings) | resource |
| [catalystcenter_ntp_settings.ntp_servers](https://registry.terraform.io/providers/CiscoDevNet/catalystcenter/latest/docs/resources/ntp_settings) | resource |
| [catalystcenter_pnp_config_preview.config_preview](https://registry.terraform.io/providers/CiscoDevNet/catalystcenter/latest/docs/resources/pnp_config_preview) | resource |
| [catalystcenter_pnp_device.pnp_device](https://registry.terraform.io/providers/CiscoDevNet/catalystcenter/latest/docs/resources/pnp_device) | resource |
| [catalystcenter_pnp_device_claim_site.claim_device](https://registry.terraform.io/providers/CiscoDevNet/catalystcenter/latest/docs/resources/pnp_device_claim_site) | resource |
| [catalystcenter_project.project](https://registry.terraform.io/providers/CiscoDevNet/catalystcenter/latest/docs/resources/project) | resource |
| [catalystcenter_tag.tag](https://registry.terraform.io/providers/CiscoDevNet/catalystcenter/latest/docs/resources/tag) | resource |
| [catalystcenter_telemetry_settings.global_telemetry_settings](https://registry.terraform.io/providers/CiscoDevNet/catalystcenter/latest/docs/resources/telemetry_settings) | resource |
| [catalystcenter_telemetry_settings.telemetry_settings](https://registry.terraform.io/providers/CiscoDevNet/catalystcenter/latest/docs/resources/telemetry_settings) | resource |
| [catalystcenter_template.composite_template](https://registry.terraform.io/providers/CiscoDevNet/catalystcenter/latest/docs/resources/template) | resource |
| [catalystcenter_template.regular_template](https://registry.terraform.io/providers/CiscoDevNet/catalystcenter/latest/docs/resources/template) | resource |
| [catalystcenter_template_version.composite_commit_version](https://registry.terraform.io/providers/CiscoDevNet/catalystcenter/latest/docs/resources/template_version) | resource |
| [catalystcenter_template_version.regular_commit_version](https://registry.terraform.io/providers/CiscoDevNet/catalystcenter/latest/docs/resources/template_version) | resource |
| [catalystcenter_timezone_settings.global_timezone](https://registry.terraform.io/providers/CiscoDevNet/catalystcenter/latest/docs/resources/timezone_settings) | resource |
| [catalystcenter_timezone_settings.timezone](https://registry.terraform.io/providers/CiscoDevNet/catalystcenter/latest/docs/resources/timezone_settings) | resource |
| [catalystcenter_transit_network.transit](https://registry.terraform.io/providers/CiscoDevNet/catalystcenter/latest/docs/resources/transit_network) | resource |
| [catalystcenter_update_authentication_profile.closed_authentication](https://registry.terraform.io/providers/CiscoDevNet/catalystcenter/latest/docs/resources/update_authentication_profile) | resource |
| [catalystcenter_update_authentication_profile.global_authentication_template](https://registry.terraform.io/providers/CiscoDevNet/catalystcenter/latest/docs/resources/update_authentication_profile) | resource |
| [catalystcenter_update_authentication_profile.low_impact](https://registry.terraform.io/providers/CiscoDevNet/catalystcenter/latest/docs/resources/update_authentication_profile) | resource |
| [catalystcenter_update_authentication_profile.open_authentication](https://registry.terraform.io/providers/CiscoDevNet/catalystcenter/latest/docs/resources/update_authentication_profile) | resource |
| [catalystcenter_virtual_network_to_fabric_site.l3_vn_to_fabric_site](https://registry.terraform.io/providers/CiscoDevNet/catalystcenter/latest/docs/resources/virtual_network_to_fabric_site) | resource |
| [catalystcenter_wireless_device_provision.wireless_controller](https://registry.terraform.io/providers/CiscoDevNet/catalystcenter/latest/docs/resources/wireless_device_provision) | resource |
| [catalystcenter_wireless_profile.wireless_profile](https://registry.terraform.io/providers/CiscoDevNet/catalystcenter/latest/docs/resources/wireless_profile) | resource |
| [catalystcenter_wireless_rf_profile.rf_profile](https://registry.terraform.io/providers/CiscoDevNet/catalystcenter/latest/docs/resources/wireless_rf_profile) | resource |
| [catalystcenter_wireless_ssid.ssid](https://registry.terraform.io/providers/CiscoDevNet/catalystcenter/latest/docs/resources/wireless_ssid) | resource |
| [local_sensitive_file.defaults](https://registry.terraform.io/providers/hashicorp/local/latest/docs/resources/sensitive_file) | resource |
| [terraform_data.validation](https://registry.terraform.io/providers/hashicorp/terraform/latest/docs/resources/data) | resource |
| [time_sleep.provision_device_wait](https://registry.terraform.io/providers/hashicorp/time/latest/docs/resources/sleep) | resource |
| [time_sleep.template_wait](https://registry.terraform.io/providers/hashicorp/time/latest/docs/resources/sleep) | resource |
| [catalystcenter_area.global](https://registry.terraform.io/providers/CiscoDevNet/catalystcenter/latest/docs/data-sources/area) | data source |
| [catalystcenter_assign_credentials.global_assign_credentials](https://registry.terraform.io/providers/CiscoDevNet/catalystcenter/latest/docs/data-sources/assign_credentials) | data source |
| [catalystcenter_fabric_l3_virtual_network.l3_vn](https://registry.terraform.io/providers/CiscoDevNet/catalystcenter/latest/docs/data-sources/fabric_l3_virtual_network) | data source |
| [catalystcenter_fabric_sites.fabric_sites](https://registry.terraform.io/providers/CiscoDevNet/catalystcenter/latest/docs/data-sources/fabric_sites) | data source |
| [catalystcenter_network_devices.all_devices](https://registry.terraform.io/providers/CiscoDevNet/catalystcenter/latest/docs/data-sources/network_devices) | data source |
| [catalystcenter_network_profile.switching_network_profile](https://registry.terraform.io/providers/CiscoDevNet/catalystcenter/latest/docs/data-sources/network_profile) | data source |
| [catalystcenter_project.onboarding](https://registry.terraform.io/providers/CiscoDevNet/catalystcenter/latest/docs/data-sources/project) | data source |
| [catalystcenter_project.project](https://registry.terraform.io/providers/CiscoDevNet/catalystcenter/latest/docs/data-sources/project) | data source |
| [catalystcenter_sites.all_sites](https://registry.terraform.io/providers/CiscoDevNet/catalystcenter/latest/docs/data-sources/sites) | data source |
| [catalystcenter_template.template](https://registry.terraform.io/providers/CiscoDevNet/catalystcenter/latest/docs/data-sources/template) | data source |
| [catalystcenter_transit_network.transit](https://registry.terraform.io/providers/CiscoDevNet/catalystcenter/latest/docs/data-sources/transit_network) | data source |
| [catalystcenter_wireless_profile.wireless_profile](https://registry.terraform.io/providers/CiscoDevNet/catalystcenter/latest/docs/data-sources/wireless_profile) | data source |
## Modules

No modules.
<!-- END_TF_DOCS -->