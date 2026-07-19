terraform {
  backend "azurerm" {
    resource_group_name  = "rg-tfstate-sentinel-sre"
    storage_account_name = "tfstatesentinelsre"
    container_name       = "tfstate"
    key                  = "sentinel-sre/local-emb.tfstate"
  }
}