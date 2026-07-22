module "catalystcenter" {
  source  = "netascode/nac-catalystcenter/catalystcenter"
  version = "0.4.5"

  yaml_files = ["area.yaml"]
}
