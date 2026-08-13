variable "logen_worker_shape" {
  type        = string
  description = "OCI compute shape for the Logen integration worker."
  default     = "VM.Standard.E2.1.Micro"

  validation {
    condition     = var.logen_worker_shape == "VM.Standard.E2.1.Micro"
    error_message = "The Logen worker is intentionally pinned to the Always Free VM.Standard.E2.1.Micro shape."
  }
}

variable "logen_worker_image_ocid" {
  type        = string
  description = "Pinned Oracle Linux image OCID for the Logen worker."
  default     = "ocid1.image.oc1.ap-chuncheon-1.aaaaaaaa6cydynum45yr6y6sawo4djfkfzgwjvia23o44ivzimlgllop6nrq"
}

variable "logen_worker_boot_volume_size_gbs" {
  type        = number
  description = "Boot volume size in GB for the Logen worker."
  default     = 50

  validation {
    condition     = var.logen_worker_boot_volume_size_gbs >= 50 && var.logen_worker_boot_volume_size_gbs <= 32768
    error_message = "OCI boot volumes must be between 50 GB and 32,768 GB."
  }
}

variable "logen_worker_environment_secret_name" {
  type        = string
  description = "OCI Vault secret containing the Logen worker dotenv environment."
  default     = "logen-worker-env"
}

resource "oci_core_network_security_group" "logen_worker" {
  compartment_id = var.compartment_ocid
  vcn_id         = module.network.vcn_id
  display_name   = "logen-worker-nsg"
}

# OCI Bastion connects to the target over the VCN. The instance has no public IP.
resource "oci_core_network_security_group_security_rule" "logen_worker_ingress_ssh_vcn" {
  network_security_group_id = oci_core_network_security_group.logen_worker.id
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

resource "oci_core_instance" "logen_worker" {
  availability_domain = local.availability_domain
  compartment_id      = var.compartment_ocid
  display_name        = "logen-worker"
  shape               = var.logen_worker_shape

  availability_config {
    recovery_action = "RESTORE_INSTANCE"
  }

  create_vnic_details {
    subnet_id              = module.network.private_subnet_id
    display_name           = "logen-worker-vnic"
    hostname_label         = "logen-worker"
    assign_public_ip       = false
    nsg_ids                = [oci_core_network_security_group.logen_worker.id]
    skip_source_dest_check = false
  }

  source_details {
    source_type             = "image"
    source_id               = var.logen_worker_image_ocid
    boot_volume_size_in_gbs = var.logen_worker_boot_volume_size_gbs
  }

  metadata = {
    user_data = base64encode(templatefile("${path.module}/cloud-init-logen-worker.yaml.tftpl", {
      vault_id    = oci_kms_vault.my_hub.id
      secret_name = var.logen_worker_environment_secret_name
    }))
    ssh_authorized_keys = var.ssh_authorized_keys
  }

  freeform_tags = {
    service = "logen-worker"
    tier    = "always-free"
  }

  lifecycle {
    ignore_changes = [
      metadata["user_data"]
    ]
  }
}

output "logen_worker_instance_id" {
  description = "Logen worker compute instance OCID."
  value       = oci_core_instance.logen_worker.id
}

output "logen_worker_private_ip" {
  description = "Private IP address of the Logen worker."
  value       = oci_core_instance.logen_worker.private_ip
}

output "logen_worker_egress_ip" {
  description = "NAT public IP to register in the Logen Open API portal. It remains stable while the NAT gateway exists."
  value       = module.network.nat_gateway_ip
}

output "logen_worker_environment_secret_name" {
  description = "OCI Vault secret name read by the Logen worker."
  value       = var.logen_worker_environment_secret_name
}
