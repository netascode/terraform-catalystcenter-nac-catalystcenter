module "catalystcenter" {
  source  = "netascode/nac-catalystcenter/catalystcenter"
  version = "0.0.4-beta1"

  yaml_files = ["area.yaml"]
}
