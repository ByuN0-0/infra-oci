locals {
  ocir_endpoint        = "${var.region}.ocir.io"
  my_hub_api_image_url = "${local.ocir_endpoint}/${var.namespace}/${var.my_hub_api_repository_name}:${var.my_hub_api_image_tag}"
  public_http_ingress_cidrs = toset(["0.0.0.0/0"])

  # Cloudflare proxy mode used these CIDRs instead of public ingress.
  # Keep the list here so switching back is just a local reference change.
  # cloudflare_ipv4_cidrs = toset([
  #   "103.21.244.0/22",
  #   "103.22.200.0/22",
  #   "103.31.4.0/22",
  #   "104.16.0.0/13",
  #   "104.24.0.0/14",
  #   "108.162.192.0/18",
  #   "131.0.72.0/22",
  #   "141.101.64.0/18",
  #   "162.158.0.0/15",
  #   "172.64.0.0/13",
  #   "173.245.48.0/20",
  #   "188.114.96.0/20",
  #   "190.93.240.0/20",
  #   "197.234.240.0/22",
  #   "198.41.128.0/17",
  # ])

  my_hub_api_environment_variables = merge(
    {
      PORT                = tostring(var.my_hub_api_port)
      OCI_REGION          = var.region
      OCI_VAULT_ID        = oci_kms_vault.my_hub.id
      OCI_SECRETS_ENABLED = "true"
      OCI_ENV_SECRET      = var.my_hub_api_environment_secret_name
    },
    var.my_hub_api_environment_variables
  )
}

resource "oci_artifacts_container_repository" "my_hub_api" {
  compartment_id = var.compartment_ocid
  display_name   = var.my_hub_api_repository_name
  is_public      = false
}

resource "oci_identity_dynamic_group" "my_hub_api_compute_instances" {
  compartment_id = var.tenancy_ocid
  name           = "my-hub-api-compute-instances"
  description    = "Compute instances that can pull private images from OCIR."
  matching_rule  = "ALL {instance.compartment.id = '${var.compartment_ocid}'}"
}

resource "oci_identity_policy" "my_hub_api_compute_ocir_read" {
  compartment_id = var.tenancy_ocid
  name           = "my-hub-api-compute-ocir-read"
  description    = "Allow my-hub API compute instances to pull private images from OCIR."
  statements = [
    "Allow dynamic-group ${oci_identity_dynamic_group.my_hub_api_compute_instances.name} to read repos in tenancy"
  ]
}

resource "oci_core_network_security_group" "my_hub_api_lb" {
  compartment_id = var.compartment_ocid
  vcn_id         = module.network.vcn_id
  display_name   = "my-hub-api-lb-nsg"
}

resource "oci_core_network_security_group" "my_hub_api_compute" {
  compartment_id = var.compartment_ocid
  vcn_id         = module.network.vcn_id
  display_name   = "my-hub-api-compute-nsg"
}

resource "oci_core_network_security_group_security_rule" "lb_ingress_http" {
  for_each                  = local.public_http_ingress_cidrs
  network_security_group_id = oci_core_network_security_group.my_hub_api_lb.id
  direction                 = "INGRESS"
  protocol                  = "6"
  source                    = each.value
  source_type               = "CIDR_BLOCK"

  tcp_options {
    destination_port_range {
      min = 80
      max = 80
    }
  }
}

resource "oci_core_network_security_group_security_rule" "lb_ingress_https" {
  for_each                  = local.public_http_ingress_cidrs
  network_security_group_id = oci_core_network_security_group.my_hub_api_lb.id
  direction                 = "INGRESS"
  protocol                  = "6"
  source                    = each.value
  source_type               = "CIDR_BLOCK"

  tcp_options {
    destination_port_range {
      min = 443
      max = 443
    }
  }
}

resource "oci_core_network_security_group_security_rule" "lb_egress_api" {
  network_security_group_id = oci_core_network_security_group.my_hub_api_lb.id
  direction                 = "EGRESS"
  protocol                  = "6"
  destination               = var.private_subnet_cidr
  destination_type          = "CIDR_BLOCK"

  tcp_options {
    destination_port_range {
      min = var.my_hub_api_port
      max = var.my_hub_api_port
    }
  }
}

resource "oci_core_network_security_group_security_rule" "api_ingress_lb" {
  network_security_group_id = oci_core_network_security_group.my_hub_api_compute.id
  direction                 = "INGRESS"
  protocol                  = "6"
  source                    = var.public_subnet_cidr
  source_type               = "CIDR_BLOCK"

  tcp_options {
    destination_port_range {
      min = var.my_hub_api_port
      max = var.my_hub_api_port
    }
  }
}

resource "oci_core_network_security_group_security_rule" "api_ingress_ssh_vcn" {
  network_security_group_id = oci_core_network_security_group.my_hub_api_compute.id
  direction                 = "INGRESS"
  protocol                  = "6"
  source                    = var.vcn_cidr
  source_type               = "CIDR_BLOCK"

  tcp_options {
    destination_port_range {
      min = 22
      max = 22
    }
  }
}

resource "oci_core_network_security_group_security_rule" "api_egress_all" {
  network_security_group_id = oci_core_network_security_group.my_hub_api_compute.id
  direction                 = "EGRESS"
  protocol                  = "all"
  destination               = "0.0.0.0/0"
  destination_type          = "CIDR_BLOCK"
}

data "oci_core_images" "my_hub_api" {
  compartment_id           = var.compartment_ocid
  operating_system         = "Oracle Linux"
  operating_system_version = "8"
  shape                    = var.my_hub_api_compute_shape
  sort_by                  = "TIMECREATED"
  sort_order               = "DESC"
}

resource "oci_core_instance" "my_hub_api" {
  availability_domain = local.availability_domain
  compartment_id      = var.compartment_ocid
  display_name        = "my-hub-api"
  shape               = var.my_hub_api_compute_shape

  shape_config {
    ocpus         = var.my_hub_api_ocpus
    memory_in_gbs = var.my_hub_api_memory_gbs
  }

  create_vnic_details {
    subnet_id                 = module.network.private_subnet_id
    display_name              = "my-hub-api-vnic"
    hostname_label            = "my-hub-api"
    assign_public_ip          = false
    nsg_ids                   = [oci_core_network_security_group.my_hub_api_compute.id]
    skip_source_dest_check    = false
  }

  source_details {
    source_type              = "image"
    source_id                = data.oci_core_images.my_hub_api.images[0].id
    boot_volume_size_in_gbs  = var.my_hub_api_boot_volume_size_gbs
  }

  metadata = {
    user_data = base64encode(templatefile("${path.module}/cloud-init-my-hub-api.yaml.tftpl", {
      ocir_endpoint                    = local.ocir_endpoint
      object_storage_namespace         = var.namespace
      wallet_bucket_name               = module.object_storage.bucket_name
      adw_wallet_object_name           = var.my_hub_api_adw_wallet_object_name
      ajd_wallet_object_name           = var.my_hub_api_ajd_wallet_object_name
      my_hub_api_image_url             = local.my_hub_api_image_url
      my_hub_api_environment_variables = local.my_hub_api_environment_variables
      my_hub_api_port                  = var.my_hub_api_port
    }))
    ssh_authorized_keys = var.ssh_authorized_keys
  }

  lifecycle {
    ignore_changes = [
      metadata["user_data"]
    ]
  }

  depends_on = [
    oci_artifacts_container_repository.my_hub_api,
    oci_identity_policy.my_hub_api_compute_ocir_read,
    oci_identity_policy.my_hub_api_secret_read,
    oci_identity_policy.my_hub_api_wallet_object_read
  ]
}

resource "oci_load_balancer_load_balancer" "my_hub_api" {
  compartment_id             = var.compartment_ocid
  display_name               = "my-hub-api-lb"
  shape                      = "flexible"
  subnet_ids                 = [module.network.public_subnet_id]
  is_private                 = false
  network_security_group_ids = [oci_core_network_security_group.my_hub_api_lb.id]

  shape_details {
    minimum_bandwidth_in_mbps = var.my_hub_api_lb_min_bandwidth_mbps
    maximum_bandwidth_in_mbps = var.my_hub_api_lb_max_bandwidth_mbps
  }
}

resource "oci_load_balancer_backend_set" "my_hub_api" {
  load_balancer_id = oci_load_balancer_load_balancer.my_hub_api.id
  name             = "my-hub-api-backend-set"
  policy           = "ROUND_ROBIN"

  health_checker {
    protocol          = "HTTP"
    port              = var.my_hub_api_port
    url_path          = var.my_hub_api_health_path
    return_code       = 200
    interval_ms       = 10000
    timeout_in_millis = 3000
    retries           = 3
  }
}

resource "oci_load_balancer_backend" "my_hub_api" {
  load_balancer_id = oci_load_balancer_load_balancer.my_hub_api.id
  backendset_name  = oci_load_balancer_backend_set.my_hub_api.name
  ip_address       = oci_core_instance.my_hub_api.private_ip
  port             = var.my_hub_api_port
  weight           = 1
}

resource "oci_load_balancer_listener" "my_hub_api_http" {
  load_balancer_id         = oci_load_balancer_load_balancer.my_hub_api.id
  name                     = "my-hub-api-http"
  default_backend_set_name = oci_load_balancer_backend_set.my_hub_api.name
  port                     = 80
  protocol                 = "HTTP"
}

resource "oci_load_balancer_certificate" "my_hub_api_origin" {
  count              = var.my_hub_api_origin_certificate_public_certificate != null || var.my_hub_api_origin_certificate_private_key != null ? 1 : 0
  load_balancer_id   = oci_load_balancer_load_balancer.my_hub_api.id
  certificate_name   = "my-hub-api-origin"
  public_certificate = var.my_hub_api_origin_certificate_public_certificate
  private_key        = var.my_hub_api_origin_certificate_private_key
  ca_certificate     = var.my_hub_api_origin_certificate_ca_certificate
}

resource "oci_load_balancer_listener" "my_hub_api_https" {
  count                    = length(oci_load_balancer_certificate.my_hub_api_origin)
  load_balancer_id         = oci_load_balancer_load_balancer.my_hub_api.id
  name                     = "my-hub-api-https"
  default_backend_set_name = oci_load_balancer_backend_set.my_hub_api.name
  port                     = 443
  protocol                 = "HTTP"

  ssl_configuration {
    certificate_name        = oci_load_balancer_certificate.my_hub_api_origin[0].certificate_name
    verify_peer_certificate = false
  }
}
