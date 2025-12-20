output "instance_id" {
  description = "Instance OCID."
  value       = oci_core_instance.this.id
}

output "private_ip" {
  description = "Primary private IP."
  value       = data.oci_core_vnic.this.private_ip_address
}

output "public_ip" {
  description = "Public IP if assigned."
  value       = data.oci_core_vnic.this.public_ip_address
}
