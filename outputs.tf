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

output "minecraft_instance_id" {
  description = "Minecraft instance OCID."
  value       = module.minecraft.instance_id
}

output "minecraft_public_ip" {
  description = "Minecraft instance public IP."
  value       = module.minecraft.public_ip
}

output "private_instance_id" {
  description = "Grafana/shared-storage instance OCID."
  value       = module.private_app.instance_id
}

output "private_instance_private_ip" {
  description = "Grafana/shared-storage private IP."
  value       = module.private_app.private_ip
}

output "ocir_namespace" {
  description = "OCIR namespace."
  value       = var.ocir_namespace
}

output "object_storage_bucket_name" {
  description = "Object Storage bucket name."
  value       = module.object_storage.bucket_name
}

output "object_storage_bucket_id" {
  description = "Object Storage bucket OCID."
  value       = module.object_storage.bucket_id
}
