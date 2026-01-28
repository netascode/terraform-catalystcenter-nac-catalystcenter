## 0.3.1 (unreleased)

**New Features:**
- Add support for 6 additional site hierarchy area levels, extending total support to 10 area levels enabling deep organizational hierarchies up to `Global/area/area/area/area/area/area/area/area/area/area`

**Improvements:**
- Add bulk site resource support via `use_bulk_api` flag for areas, buildings, and floors using new map-based provider resource (`catalystcenter_areas`, `catalystcenter_buildings`, `catalystcenter_floors`)
- Add sequential dependencies to network settings resources to prevent concurrent operations and "Global Settings Save is in progress" API errors
- Add `device_discovery_validation` check block to validate device presence in Catalyst Center inventory during plan phase, and improve error handling for devices not found in inventory by filtering them out from resource operations instead of failing with coalesce errors
- Add validation for `managed_sites` variable to ensure all sites specified exist in YAML configuration with precondition check
- Add validation for `bulk_site_provisioning` variable to verify site hierarchy format and existence in YAML configuration

**Bug Fixes:**
- Fix template parameter handling to correctly process both single string values and list values during deployment
- Fix issue with L2 virtual networks while using single state deployment
- Fix credential assignment to Global site in multi-state deployments
- Fix `bulk_site_provisioning_validation` to only run when bulk provisioning is enabled
- Fix fabric zones not being created in multi-state deployments due to incorrect site filtering
- Fix L3 virtual networks not being attached to fabric zones in multi-state deployments

## 0.3.0

**New Features:**
- Add support for Fabric Multicast
- Add support for Fabric Extranet Policies
- Add `bulk_site_provisioning` variable for hierarchical device provisioning filtering
- Add `device_name_to_ip` lookup map to support name and FQDN-based device IP resolution for border device mapping
- Add support for system settings Authentication Policy Servers
- Add support for provisioning Access Points
- Add Fabric Embedded_Wireless_Controller_Node support
- Add `interface_description` support for `port_assignments`
- Add `group_based_policy_enforcement_enabled` to `anycast_gateway(s)` for `EXTENDED_NODE` pool types
- Add support for PNP access points
- Add `reconfigure` attribute to `fabric_site` for applying pending fabric configuration events
- Add MD5 checksum to templates variable to trigger redeployment when template variables change
- Add flag `use_bulk_api` to enable bulk API operations for faster execution

**Improvements:**
  - Refactor template deployment mechanism to enable batch deployments (deploy multiple devices with same template in single API call)
  - Consolidate template deployment resources from per-device-template to per-template grouping for improved scalability
  - Add per-device `redeploy_template` control within `target_info` for granular deployment management

**Bug Fixes:**
- Fix issue with Vlan to SSID mappings while using `use_bulk_api`
- Fix issue when creating L2 VN while using multi state
- Fix issue when creating an L3 VN without a fabric site assignment
- Fix issue with sites hierarchy while using multi state
- Fix issue with ip pools reservations while using multi state
- Fix issue with assigning cli credentials to site while using multi state
- Fix idempotency issue during brownfield import of border devices
- Fix issue with assigning ip pool type `management` and `service` in ip pools reservations
- Fix EWLC provisioning
- Fix issue with provision edge device while using embedded wireless controller
- Fix multicast resource to tolerate both hostname and FQDN device names
- Fix floor width, length, height rounding to 3 decimal places
- Fix transit configuration and L2 handoff dependencies

**Breaking Changes:**
- BREAKING CHANGE: Update several resources to align with provider version 0.4.0 schema changes (removal of deprecated and internal API attributes)

## 0.2.0

- Add AP Zones support under Wireless Network Profile
- BREAKING CHANGE: change `hostname` to `fqdn_name` in inventory devices
- BREAKING CHANGE: Modify template redeployment, replace `deploy_state` with `redeploy_template` attribute with values `ALWAYS`, `ON_CHANGE`, `NEVER`
- BREAKING CHANGE: Add `ip_pool_name` and rename `name` to `l3_virtual_network` under `l2_handoff` with anycast gateway
- BREAKING CHANGE: rename `catalystcenter_fabric_l3_handoff_ip_transit` to `catalystcenter_fabric_l3_handoff_ip_transits`
- BREAKING CHANGE: Replace `name` with `ip_pool_name` under Anycast Gateway data model
- BREAKING CHANGE: Modify data model for Lan Automation
- Fix issue with assigning Local to VLAN to wireless profile for Flex Connect Local Switching
- Fix issue with assigning L3 Virtual Networks to Fabric Zones.
- BREAKING_CHANGE: Fix issue with assigning UseLoopBack as preferred_mgmt_ip_method to Discovery.
- Fix issue with assigning global_credential_id_list to Discovery.
- BREAKING CHANGE: Replace resource `catalystcenter_associate_site_to_network_profile` with `catalystcenter_network_profile_for_site_assignments`

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