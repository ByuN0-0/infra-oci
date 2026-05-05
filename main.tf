data "oci_identity_availability_domains" "ads" {
  compartment_id = var.tenancy_ocid
}

locals {
  availability_domain = data.oci_identity_availability_domains.ads.availability_domains[var.availability_domain_index].name
}

module "network" {
  source                    = "./modules/network"
  compartment_ocid          = var.compartment_ocid
  vcn_name                  = var.vcn_name
  vcn_cidr                  = var.vcn_cidr
  public_subnet_cidr        = var.public_subnet_cidr
  private_subnet_cidr       = var.private_subnet_cidr
  my_hub_api_port           = var.my_hub_api_port
  public_http_ingress_cidrs = local.cloudflare_ipv4_cidrs
  providers = {
    oci = oci
  }
}

# OCI Bastion Service (관리형 배스천)
resource "oci_bastion_bastion" "this" {
  bastion_type                 = "STANDARD"
  compartment_id               = var.compartment_ocid
  target_subnet_id             = module.network.private_subnet_id
  client_cidr_block_allow_list = ["0.0.0.0/0"]
  name                         = "bastion-service"
  max_session_ttl_in_seconds   = 10800 # 3시간
}

module "object_storage" {
  source            = "./modules/storage"
  compartment_ocid  = var.compartment_ocid
  namespace         = var.namespace
  bucket_name       = var.object_storage_bucket_name
  access_type       = var.object_storage_access_type
  providers = {
    oci = oci
  }
}
