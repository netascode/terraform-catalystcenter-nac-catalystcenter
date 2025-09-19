module "catalystcenter" {
  source  = "netascode/nac-catalystcenter/catalystcenter"
  version = "0.2.0"

  yaml_files = ["area.yaml"]
}
