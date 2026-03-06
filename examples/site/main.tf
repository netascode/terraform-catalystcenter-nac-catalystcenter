module "catalystcenter" {
  source  = "netascode/nac-catalystcenter/catalystcenter"
  version = "0.4.1"

  yaml_files = ["area.yaml"]
}
