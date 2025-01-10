module "catalystcenter" {
  source  = "netascode/nac-catalystcenter/catalystcenter"
  version = ">= 0.1.0"

  yaml_files = ["area.yaml"]
}
