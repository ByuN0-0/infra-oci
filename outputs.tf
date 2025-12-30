output "vcn_id" {
  description = "VCN OCID."
  value       = module.network.vcn_id
}

output "public_subnet_id" {
  description = "Public subnet OCID."
  value       = module.network.public_subnet_id
}

output "private_subnet_id" {
  description = "Private subnet OCID."
  value       = module.network.private_subnet_id
}

output "mc_server_instance_id" {
  description = "MC server instance OCID."
  value       = module.mc_server.instance_id
}

output "mc_server_public_ip" {
  description = "MC server instance public IP."
  value       = module.mc_server.public_ip
}

output "bastion_service_id" {
  description = "OCI Bastion Service OCID."
  value       = oci_bastion_bastion.this.id
}

output "bastion_service_name" {
  description = "OCI Bastion Service name."
  value       = oci_bastion_bastion.this.name
}

output "monitor_instance_id" {
  description = "Monitor instance OCID."
  value       = module.monitor_app.instance_id
}

output "monitor_instance_private_ip" {
  description = "Monitor instance private IP."
  value       = module.monitor_app.private_ip
}

output "namespace" {
  description = "Object Storage namespace."
  value       = var.namespace
}

output "object_storage_bucket_name" {
  description = "Object Storage bucket name."
  value       = module.object_storage.bucket_name
}

output "object_storage_bucket_id" {
  description = "Object Storage bucket OCID."
  value       = module.object_storage.bucket_id
}
