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

output "nat_gateway_ip" {
  description = "Public IP address used by the NAT gateway."
  value       = module.network.nat_gateway_ip
}

output "my_hub_api_compute_instance_id" {
  description = "my-hub API compute instance OCID."
  value       = oci_core_instance.my_hub_api.id
}

output "my_hub_api_image_url" {
  description = "OCIR image URL used by the my-hub API."
  value       = local.my_hub_api_image_url
}

output "my_hub_api_repository_id" {
  description = "OCIR repository OCID for the my-hub API image."
  value       = oci_artifacts_container_repository.my_hub_api.id
}

output "my_hub_api_private_ip" {
  description = "my-hub API compute instance private IP."
  value       = oci_core_instance.my_hub_api.private_ip
}

output "my_hub_api_lb_ip" {
  description = "my-hub API public load balancer IP."
  value       = oci_load_balancer_load_balancer.my_hub_api.ip_address_details[0].ip_address
}

output "my_hub_api_hostname" {
  description = "my-hub API public hostname."
  value       = var.my_hub_api_hostname
}

output "bastion_service_id" {
  description = "OCI Bastion Service OCID."
  value       = oci_bastion_bastion.this.id
}

output "bastion_service_name" {
  description = "OCI Bastion Service name."
  value       = oci_bastion_bastion.this.name
}

output "mysql_heatwave_db_system_id" {
  description = "MySQL HeatWave DB system OCID."
  value       = var.enable_mysql_heatwave ? oci_mysql_mysql_db_system.my_hub[0].id : null
}

output "mysql_heatwave_endpoint" {
  description = "MySQL HeatWave private endpoint hostname."
  value       = var.enable_mysql_heatwave ? oci_mysql_mysql_db_system.my_hub[0].endpoints[0].hostname : null
}

output "autonomous_json_database_id" {
  description = "Autonomous JSON Database OCID."
  value       = var.enable_autonomous_json_database ? oci_database_autonomous_database.json[0].id : null
}

output "autonomous_data_warehouse_id" {
  description = "Autonomous Data Warehouse OCID."
  value       = var.enable_autonomous_data_warehouse ? oci_database_autonomous_database.warehouse[0].id : null
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
