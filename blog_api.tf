locals {
  ocir_endpoint      = "${var.region}.ocir.io"
  blog_api_image_url = "${local.ocir_endpoint}/${var.namespace}/${var.blog_api_repository_name}:${var.blog_api_image_tag}"

  blog_api_environment_variables = merge(
    {
      PORT = tostring(var.blog_api_port)
    },
    var.enable_mysql_heatwave ? {
      MYSQL_HOST = oci_mysql_mysql_db_system.blog_api[0].endpoints[0].hostname
      MYSQL_PORT = tostring(oci_mysql_mysql_db_system.blog_api[0].endpoints[0].port)
      MYSQL_USER = var.mysql_admin_username
      MYSQL_PASSWORD = var.mysql_admin_password
    } : {},
    var.blog_api_environment_variables
  )
}

resource "oci_artifacts_container_repository" "blog_api" {
  compartment_id = var.compartment_ocid
  display_name   = var.blog_api_repository_name
  is_public      = false
}

resource "oci_identity_dynamic_group" "container_instances" {
  compartment_id = var.tenancy_ocid
  name           = "blog-api-container-instances"
  description    = "Container instances that can pull private images from OCIR."
  matching_rule  = "ALL {resource.type = 'computecontainerinstance', resource.compartment.id = '${var.compartment_ocid}'}"
}

resource "oci_identity_policy" "container_instances_ocir_read" {
  compartment_id = var.tenancy_ocid
  name           = "blog-api-container-instances-ocir-read"
  description    = "Allow blog API container instances to pull private images from OCIR."
  statements = [
    "Allow dynamic-group ${oci_identity_dynamic_group.container_instances.name} to read repos in tenancy"
  ]
}

resource "oci_core_network_security_group" "blog_api_lb" {
  compartment_id = var.compartment_ocid
  vcn_id         = module.network.vcn_id
  display_name   = "blog-api-lb-nsg"
}

resource "oci_core_network_security_group" "blog_api_container" {
  compartment_id = var.compartment_ocid
  vcn_id         = module.network.vcn_id
  display_name   = "blog-api-container-nsg"
}

resource "oci_core_network_security_group_security_rule" "lb_ingress_http" {
  network_security_group_id = oci_core_network_security_group.blog_api_lb.id
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
  network_security_group_id = oci_core_network_security_group.blog_api_lb.id
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
  network_security_group_id = oci_core_network_security_group.blog_api_lb.id
  direction                 = "EGRESS"
  protocol                  = "6"
  destination               = var.private_subnet_cidr
  destination_type          = "CIDR_BLOCK"

  tcp_options {
    destination_port_range {
      min = var.blog_api_port
      max = var.blog_api_port
    }
  }
}

resource "oci_core_network_security_group_security_rule" "api_ingress_lb" {
  network_security_group_id = oci_core_network_security_group.blog_api_container.id
  direction                 = "INGRESS"
  protocol                  = "6"
  source                    = var.public_subnet_cidr
  source_type               = "CIDR_BLOCK"

  tcp_options {
    destination_port_range {
      min = var.blog_api_port
      max = var.blog_api_port
    }
  }
}

resource "oci_core_network_security_group_security_rule" "api_egress_all" {
  network_security_group_id = oci_core_network_security_group.blog_api_container.id
  direction                 = "EGRESS"
  protocol                  = "all"
  destination               = "0.0.0.0/0"
  destination_type          = "CIDR_BLOCK"
}

resource "oci_container_instances_container_instance" "blog_api" {
  availability_domain = local.availability_domain
  compartment_id      = var.compartment_ocid
  display_name        = "blog-api"
  shape               = var.blog_api_container_shape

  shape_config {
    ocpus         = var.blog_api_ocpus
    memory_in_gbs = var.blog_api_memory_gbs
  }

  vnics {
    subnet_id              = module.network.private_subnet_id
    display_name           = "blog-api-vnic"
    hostname_label         = "blog-api"
    is_public_ip_assigned  = false
    nsg_ids                = [oci_core_network_security_group.blog_api_container.id]
    skip_source_dest_check = false
  }

  containers {
    image_url                      = local.blog_api_image_url
    display_name                   = "blog-api"
    environment_variables          = local.blog_api_environment_variables
    is_resource_principal_disabled = false

    health_checks {
      health_check_type        = "HTTP"
      name                     = "blog-api-health"
      path                     = var.blog_api_health_path
      port                     = var.blog_api_port
      initial_delay_in_seconds = 30
      interval_in_seconds      = 30
      timeout_in_seconds       = 5
      success_threshold        = 1
      failure_threshold        = 3
      failure_action           = "KILL"
    }

    resource_config {
      memory_limit_in_gbs = var.blog_api_memory_gbs
      vcpus_limit         = var.blog_api_ocpus
    }
  }

  container_restart_policy = "ALWAYS"

  depends_on = [
    oci_artifacts_container_repository.blog_api,
    oci_identity_policy.container_instances_ocir_read
  ]
}

data "oci_core_vnic" "blog_api" {
  vnic_id = oci_container_instances_container_instance.blog_api.vnics[0].vnic_id
}

resource "oci_load_balancer_load_balancer" "blog_api" {
  compartment_id             = var.compartment_ocid
  display_name               = "blog-api-lb"
  shape                      = "flexible"
  subnet_ids                 = [module.network.public_subnet_id]
  is_private                 = false
  network_security_group_ids = [oci_core_network_security_group.blog_api_lb.id]

  shape_details {
    minimum_bandwidth_in_mbps = var.blog_api_lb_min_bandwidth_mbps
    maximum_bandwidth_in_mbps = var.blog_api_lb_max_bandwidth_mbps
  }
}

resource "oci_load_balancer_backend_set" "blog_api" {
  load_balancer_id = oci_load_balancer_load_balancer.blog_api.id
  name             = "blog-api-backend-set"
  policy           = "ROUND_ROBIN"

  health_checker {
    protocol          = "HTTP"
    port              = var.blog_api_port
    url_path          = var.blog_api_health_path
    return_code       = 200
    interval_ms       = 10000
    timeout_in_millis = 3000
    retries           = 3
  }
}

resource "oci_load_balancer_backend" "blog_api" {
  load_balancer_id = oci_load_balancer_load_balancer.blog_api.id
  backendset_name  = oci_load_balancer_backend_set.blog_api.name
  ip_address       = data.oci_core_vnic.blog_api.private_ip_address
  port             = var.blog_api_port
  weight           = 1
}

resource "oci_load_balancer_listener" "blog_api_http" {
  load_balancer_id         = oci_load_balancer_load_balancer.blog_api.id
  name                     = "blog-api-http"
  default_backend_set_name = oci_load_balancer_backend_set.blog_api.name
  port                     = 80
  protocol                 = "HTTP"
}
