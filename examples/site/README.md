<!-- BEGIN_TF_DOCS -->
# Cisco Catalyst Center Site Example

Set environment variables pointing to Catalyst Center:

```bash
export CC_USERNAME=admin
export CC_PASSWORD=Cisco123
export CC_URL=https://10.1.1.1
```

To run this example you need to execute:

```bash
$ terraform init
$ terraform plan
$ terraform apply
```

Note that this example will create resources. Resources can be destroyed with `terraform destroy`.

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
  version = "0.1.0"

  yaml_files = ["area.yaml"]
}
```
<!-- END_TF_DOCS -->