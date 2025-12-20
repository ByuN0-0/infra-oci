provider "oci" {
  tenancy_ocid     = var.tenancy_ocid
  user_ocid        = var.user_ocid
  fingerprint      = var.fingerprint
  private_key_path = var.private_key_path
  region           = var.region
}

data "oci_identity_availability_domains" "ads" {
  compartment_id = var.tenancy_ocid
}

locals {
  availability_domain = data.oci_identity_availability_domains.ads.availability_domains[var.availability_domain_index].name
}

module "network" {
  source               = "./modules/network"
  compartment_ocid     = var.compartment_ocid
  vcn_name             = var.vcn_name
  vcn_cidr             = var.vcn_cidr
  public_subnet_cidr   = var.public_subnet_cidr
  private_subnet_cidr  = var.private_subnet_cidr
}

module "minecraft" {
  source              = "./modules/compute"
  compartment_ocid    = var.compartment_ocid
  availability_domain = local.availability_domain
  subnet_id           = module.network.public_subnet_id
  display_name        = "minecraft"
  hostname_label      = "minecraft"
  shape               = var.minecraft_shape
  ocpus               = var.minecraft_ocpus
  memory_in_gbs       = var.minecraft_memory_gbs
  ssh_authorized_keys = var.ssh_authorized_keys
  assign_public_ip    = true
  user_data           = templatefile("${path.module}/templates/docker-user-data.sh.tftpl", {
    hostname = "minecraft"
  })
}

module "private_app" {
  source              = "./modules/compute"
  compartment_ocid    = var.compartment_ocid
  availability_domain = local.availability_domain
  subnet_id           = module.network.private_subnet_id
  display_name        = "grafana-shared-storage"
  hostname_label      = "grafana"
  shape               = var.private_shape
  ocpus               = var.private_ocpus
  memory_in_gbs       = var.private_memory_gbs
  ssh_authorized_keys = var.ssh_authorized_keys
  assign_public_ip    = false
  user_data           = templatefile("${path.module}/templates/cloudflared-user-data.sh.tftpl", {
    cloudflare_tunnel_token = var.cloudflare_tunnel_token
    hostname                = "grafana"
  })
}

module "object_storage" {
  source            = "./modules/storage"
  compartment_ocid  = var.compartment_ocid
  namespace         = var.ocir_namespace
  bucket_name       = var.object_storage_bucket_name
  access_type       = var.object_storage_access_type
}
