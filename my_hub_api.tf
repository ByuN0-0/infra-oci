locals {
  ocir_endpoint      = "${var.region}.ocir.io"
  my_hub_api_image_url = "${local.ocir_endpoint}/${var.namespace}/${var.my_hub_api_repository_name}:${var.my_hub_api_image_tag}"

  my_hub_api_environment_variables = merge(
    {
      PORT = tostring(var.my_hub_api_port)
    },
    var.enable_mysql_heatwave ? {
      MYSQL_HOST = oci_mysql_mysql_db_system.my_hub[0].endpoints[0].hostname
      MYSQL_PORT = tostring(oci_mysql_mysql_db_system.my_hub[0].endpoints[0].port)
      MYSQL_USER = var.mysql_admin_username
      MYSQL_PASSWORD = var.mysql_admin_password
    } : {},
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
  network_security_group_id = oci_core_network_security_group.my_hub_api_lb.id
  direction                 = "INGRESS"
  protocol                  = "6"
  source                    = "0.0.0.0/0"
  source_type               = "CIDR_BLOCK"

  tcp_options {
    destination_port_range {
      min = 80
      max = 80
    }
  }
}

resource "oci_core_network_security_group_security_rule" "lb_ingress_https" {
  network_security_group_id = oci_core_network_security_group.my_hub_api_lb.id
  direction                 = "INGRESS"
  protocol                  = "6"
  source                    = "0.0.0.0/0"
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
      my_hub_api_image_url             = local.my_hub_api_image_url
      my_hub_api_environment_variables = local.my_hub_api_environment_variables
    }))
    ssh_authorized_keys = var.ssh_authorized_keys
  }

  depends_on = [
    oci_artifacts_container_repository.my_hub_api,
    oci_identity_policy.my_hub_api_compute_ocir_read
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
