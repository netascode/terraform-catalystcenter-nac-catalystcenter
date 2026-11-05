module "catalystcenter" {
  source  = "netascode/nac-catalystcenter/catalystcenter"
  version = "0.6.0"

  yaml_files = ["area.yaml"]
}
