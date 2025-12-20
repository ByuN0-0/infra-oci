terraform {
  cloud {
    organization = "biyeon"
    workspaces {
      name = "myOCI"
    }
  }

  required_version = ">= 1.5.0"

  required_providers {
    oci = {
      source  = "oracle/oci"
      version = ">= 5.0.0"
    }
  }
}
