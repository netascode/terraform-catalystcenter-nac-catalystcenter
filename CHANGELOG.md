## 0.1.2 (unreleased)

- BREAKING CHANGE: Modify template redeployment, replace `deploy_state` with `redeploy_template` attribute with values `ALWAYS`, `ON_CHANGE`, `NEVER`
- BREAKING CHANGE: Add ip_pool_name and rename name to l3_virtual_network under l2_handoff with anycast gateway
- BREAKING CHANGE: rename `catalystcenter_fabric_l3_handoff_ip_transit` to `catalystcenter_fabric_l3_handoff_ip_transits`
- BREAKING CHANGE: Replace `name` with `ip_pool_name` under Anycast Gateway data model
- BREAKING CHANGE: Modify data model for Lan Automation
- BREAKING CHANGE: rename `catalystcenter_associate_site_to_network_profile` to `catalystcenter_network_profile_for_site_assignments`
- Fix issue with assigning Local to VLAN to wireless profile for Flex Connect Local Switching
- Fix issue with assigning L3 Virtual Networks to Fabric Zones.
- Fix issue with assigning UseLoopBack as preferred_ip_method to Discovery.
- Fix issue with assigning global_credential_id_list to Discovery.

## 0.1.1

- Add support for a new hierarchy area level: `Global/area/area/area/area`
- Fix issue with assigning `security_group_name` to fabric port assignments
- BREAKING CHANGE: Change data model struture for `l3_virtual_networks` to support L3 VNs on global level
- Add support for reprovisioning wireless controller device
- Add `manage_global_settings` variable to the module. This flag indicates if global settings should be managed.
- Add `managed_sites` variable to the module. This variable defines a list of site names to manage. If not specified, all sites will be managed by default.
- Add `manage_specific_sites_only` variable to the module. If set to true only sites listed under `managed_sites` will be managed. If false, also all child sites under managed_sites will be managed.
- BREAKING CHANGE: Modify `catalystcenter_fabric_provision_device` resource instance to fix issue with initial provisioning followed by reprovisioning after adding `fabric_site`

## 0.1.0

- Add support for assigning tag to device
- Add support for `CORE` and `DISTRIBUTION` role
- Fix wireless ssid radio type mapping to match API response
- Fix issue with ssid to vlan mapping in fabric
- Add support for same `l3_virtual_network` under multiple `anycast_gateways`
- Add `fabric_zone` support and adding `l3_virtual_networks` under fabric zone
- BREAKING CHANGE: Add support to update `authentication_template` settings globally and on fabric site level
- Add `ASSIGN` state for assigning device to site without provisioning
- Fix pnp issue when adding multiple devices
- Add support for `.vtl` and `.vlt` extensions for velocity templates
- Add support for `INFRA_VN` and `DEFAULT_VN` layer3 virtual networks
- Add support for saving running config to startup config while deploying regular templates
- Fix issue with anycast_gateway dependencies to fabric_vlan_to_ssid

## 0.0.4-beta1

- BREAKING CHANGE: Fix issue with assigning the same VLAN to different anycast gateways from different fabric sites
- Fix issue with provision non fabric wireless controller
- Add support for SDA Transit

## 0.0.3-beta1

- BREAKING CHANGE: add support for multple interfaces under l3_handoffs
- Add redeploy option to `catalystcenter_deploy_template`
- Add non fabric device provisioning
- Update banner settings to use allow banner settings to be assigned to Global area
- BREAKING CHANGE: rename `catalystcenter_fabric_port_assignment` to `catalystcenter_fabric_port_assignments`
- Fix issue with assiging same L3 VN to multiple fabric_sites
- Removed `network_profile` dependencies for deploying templates
- Fix issue with pnp onboarding templates

## 0.0.2-beta1

- BREAKING CHANGE: replace `catalystcenter_fabric_virtual_network` and `catalystcenter_virtual_network_to_fabric_site` resources with `catalystcenter_fabric_l3_virtual_network` resource

## 0.0.1-beta1

- Initial release