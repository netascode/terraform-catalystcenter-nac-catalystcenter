### Secret Day-N template parameters

Add a `<parameter>_version` variable beside a parameter to make its value
write-only. The version must be a positive integer. For example:

```yaml
catalyst_center:
  inventory:
    devices:
      - name: BR10
        state: PROVISION
        site: Global/Test
        dayn_templates:
          regular:
            - name: MyProject#ConfigurePassword
              redeploy_template: ON_CHANGE
              variables:
                - name: description
                  value: Branch switch
                - name: password
                  value: example-secret
                - name: password_version
                  value: 1
```

This fragment belongs in the normal model with the device, site and template
definitions or references. Supply it through `yaml_files`, `yaml_directories`,
or `model` as usual. The provider must support `secret_params`.

The module sends `description` as a public parameter, `password` through the
provider's write-only input, and `password_version` as version metadata. The
version marker is not sent to Catalyst Center. Resource state contains the
parameter name and version, with a null write-only value. The module's `model`
output replaces marked secret values with null and retains the companion versions.

Increment the version when rotating the secret. Changing only its value does
not cause deployment. Whenever public inputs change and redeploy policy permits
deployment, all current secrets are sent again, so supply them on each apply.
Versions follow the existing `ON_CHANGE`, `ALWAYS`, and `NEVER` policies. Removing
both variables stops managing that secret; it does not erase a device password.

List-valued parameters use the same convention. In composite template variables,
set `template_name` on both the value and its version:

```yaml
variables:
  - template_name: ConfigurePassword
    name: password
    value: example-secret
  - template_name: ConfigurePassword
    name: password_version
    value: 2
```

Pairing is local to one device, deployment template and composite member. This
works for managed and discovered composites. A name ending in `_version` without
a matching base parameter remains an ordinary public parameter. Companion
versions belong to device-side Day-N variables, not template parameter definitions
or onboarding claim parameters.
Chains such as `password`, `password_version`, and
`password_version_version` are rejected.

Write-only resource inputs do not make ordinary Terraform input variables
ephemeral. A secret supplied through a non-ephemeral root variable can still
appear in a saved plan's input variables. Previously public values remain in
older state backups.

Upgrading without secret pairs keeps existing behavior for public parameters.
Adding a companion version migrates that parameter to write-only handling.
