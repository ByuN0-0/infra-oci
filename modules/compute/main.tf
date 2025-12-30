data "oci_core_images" "this" {
  compartment_id           = var.compartment_ocid
  operating_system         = "Oracle Linux"
  operating_system_version = "8"
  shape                    = var.shape
  sort_by                  = "TIMECREATED"
  sort_order               = "DESC"
}

locals {
  metadata = var.user_data != "" ? {
    ssh_authorized_keys = var.ssh_authorized_keys
    user_data           = base64encode(var.user_data)
  } : {
    ssh_authorized_keys = var.ssh_authorized_keys
  }
}

resource "oci_core_instance" "this" {
  compartment_id      = var.compartment_ocid
  availability_domain = var.availability_domain
  display_name        = var.display_name
  shape               = var.shape

  shape_config {
    ocpus         = var.ocpus
    memory_in_gbs = var.memory_in_gbs
  }

  create_vnic_details {
    subnet_id        = var.subnet_id
    assign_public_ip = var.assign_public_ip
    hostname_label   = var.hostname_label
  }

  metadata = local.metadata

  source_details {
    source_type = "image"
    source_id   = data.oci_core_images.this.images[0].id
  }
}

data "oci_core_vnic_attachments" "this" {
  compartment_id = var.compartment_ocid
  instance_id    = oci_core_instance.this.id
}

data "oci_core_vnic" "this" {
  vnic_id = data.oci_core_vnic_attachments.this.vnic_attachments[0].vnic_id
}

# 블록 볼륨 생성 (선택 사항)
resource "oci_core_volume" "this" {
  count               = var.block_storage_size_in_gbs > 0 ? 1 : 0
  compartment_id      = var.compartment_ocid
  availability_domain = var.availability_domain
  display_name        = "${var.display_name}-data"
  size_in_gbs         = var.block_storage_size_in_gbs
}

# 볼륨을 인스턴스에 연결
resource "oci_core_volume_attachment" "this" {
  count           = var.block_storage_size_in_gbs > 0 ? 1 : 0
  attachment_type = "paravirtualized" # 설정이 간편한 Paravirtualized 모드 사용
  instance_id     = oci_core_instance.this.id
  volume_id       = oci_core_volume.this[0].id
  display_name    = "${var.display_name}-data-attachment"
  
  # Paravirtualized 모드에서는 device 이름을 지정하지 않아도 OS에서 자동으로 잡힙니다.
}
