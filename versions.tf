terraform {
  cloud {
    organization = "biyeon"
    workspaces {
      name = "myOCI"
    }
  }

  required_version = "1.14.3"

  required_providers {
    oci = {
      source  = "oracle/oci"
      version = ">= 7.26.1"
    }
  }
}
