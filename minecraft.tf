locals {
  minecraft_backup_prefix = "minecraft/cte2/backups/"
}

resource "oci_core_network_security_group" "minecraft_nlb" {
  compartment_id = var.compartment_ocid
  vcn_id         = module.network.vcn_id
  display_name   = "minecraft-nlb-nsg"
}

resource "oci_core_network_security_group_security_rule" "minecraft_nlb_ingress" {
  network_security_group_id = oci_core_network_security_group.minecraft_nlb.id
  direction                 = "INGRESS"
  protocol                  = "6"
  source                    = "0.0.0.0/0"
  source_type               = "CIDR_BLOCK"

  tcp_options {
    destination_port_range {
      min = var.minecraft_port
      max = var.minecraft_port
    }
  }
}

resource "oci_core_network_security_group_security_rule" "minecraft_nlb_egress" {
  network_security_group_id = oci_core_network_security_group.minecraft_nlb.id
  direction                 = "EGRESS"
  protocol                  = "6"
  destination               = var.private_subnet_cidr
  destination_type          = "CIDR_BLOCK"

  tcp_options {
    destination_port_range {
      min = var.minecraft_port
      max = var.minecraft_port
    }
  }
}

resource "oci_core_network_security_group_security_rule" "minecraft_compute_ingress" {
  network_security_group_id = oci_core_network_security_group.my_hub_api_compute.id
  direction                 = "INGRESS"
  protocol                  = "6"
  source                    = "0.0.0.0/0"
  source_type               = "CIDR_BLOCK"

  tcp_options {
    destination_port_range {
      min = var.minecraft_port
      max = var.minecraft_port
    }
  }
}

resource "oci_network_load_balancer_network_load_balancer" "minecraft" {
  compartment_id                 = var.compartment_ocid
  display_name                   = "craft-to-exile-2-nlb"
  subnet_id                      = module.network.public_subnet_id
  is_private                     = false
  is_preserve_source_destination = false
  network_security_group_ids     = [oci_core_network_security_group.minecraft_nlb.id]
}

resource "oci_network_load_balancer_backend_set" "minecraft" {
  name                     = "craft-to-exile-2-backend-set"
  network_load_balancer_id = oci_network_load_balancer_network_load_balancer.minecraft.id
  policy                   = "FIVE_TUPLE"
  is_preserve_source       = true

  health_checker {
    protocol           = "TCP"
    port               = var.minecraft_port
    interval_in_millis = 10000
    timeout_in_millis  = 3000
    retries            = 3
  }
}

resource "oci_network_load_balancer_backend" "minecraft" {
  backend_set_name         = oci_network_load_balancer_backend_set.minecraft.name
  network_load_balancer_id = oci_network_load_balancer_network_load_balancer.minecraft.id
  ip_address               = oci_core_instance.my_hub_api.private_ip
  port                     = var.minecraft_port
  weight                   = 1
}

resource "oci_network_load_balancer_listener" "minecraft" {
  default_backend_set_name = oci_network_load_balancer_backend_set.minecraft.name
  name                     = "craft-to-exile-2-tcp"
  network_load_balancer_id = oci_network_load_balancer_network_load_balancer.minecraft.id
  port                     = var.minecraft_port
  protocol                 = "TCP"
  tcp_idle_timeout         = 1800
}

resource "oci_identity_dynamic_group" "minecraft_instance" {
  compartment_id = var.tenancy_ocid
  name           = "minecraft-instance"
  description    = "Minecraft compute instance allowed to read releases and write backups."
  matching_rule  = "ALL {instance.id = '${oci_core_instance.my_hub_api.id}'}"
}

resource "oci_identity_policy" "minecraft_object_storage" {
  compartment_id = var.tenancy_ocid
  name           = "minecraft-object-storage"
  description    = "Allow the Minecraft instance to read its release and manage backups."
  statements = [
    "Allow dynamic-group ${oci_identity_dynamic_group.minecraft_instance.name} to inspect buckets in compartment id ${var.compartment_ocid}",
    "Allow dynamic-group ${oci_identity_dynamic_group.minecraft_instance.name} to manage objects in compartment id ${var.compartment_ocid} where target.bucket.name = '${module.object_storage.bucket_name}'",
    "Allow service objectstorage-${var.region} to manage object-family in compartment id ${var.compartment_ocid} where target.bucket.name = '${module.object_storage.bucket_name}'",
  ]
}

resource "oci_objectstorage_object_lifecycle_policy" "minecraft_backups" {
  namespace = var.namespace
  bucket    = module.object_storage.bucket_name

  depends_on = [oci_identity_policy.minecraft_object_storage]

  rules {
    action      = "DELETE"
    is_enabled  = true
    name        = "expire-minecraft-backups"
    target      = "objects"
    time_amount = var.minecraft_backup_retention_days
    time_unit   = "DAYS"

    object_name_filter {
      inclusion_prefixes = [local.minecraft_backup_prefix]
    }
  }
}
