## 0.0.3-beta1 (unreleased)

- BREAKING CHANGE: add support for multple interfaces under l3_handoffs
- Add redeploy option to templates
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