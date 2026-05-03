resource "oci_mysql_mysql_db_system" "my_hub" {
  depends_on = [oci_identity_policy.mysql_heatwave_management]

  count                  = var.enable_mysql_heatwave ? 1 : 0
  availability_domain    = local.availability_domain
  compartment_id         = var.compartment_ocid
  shape_name             = var.mysql_shape_name
  subnet_id              = module.network.private_subnet_id
  admin_username         = var.mysql_admin_username
  admin_password         = var.mysql_admin_password
  data_storage_size_in_gb = var.mysql_data_storage_size_in_gb
  display_name           = "my-hub-mysql"
  hostname_label         = "my-hub-mysql"
  is_highly_available    = false
  port                   = 3306
  port_x                 = 33060
}

resource "oci_database_autonomous_database" "json" {
  count                  = var.enable_autonomous_json_database ? 1 : 0
  compartment_id         = var.compartment_ocid
  admin_password         = var.autonomous_json_admin_password
  db_name                = "MYHUBJSON"
  db_workload            = "AJD"
  display_name           = "my-hub-json"
  is_free_tier           = true
  license_model          = "LICENSE_INCLUDED"
  whitelisted_ips        = [module.network.nat_gateway_ip]
}

resource "oci_database_autonomous_database" "warehouse" {
  count                  = var.enable_autonomous_data_warehouse ? 1 : 0
  compartment_id         = var.compartment_ocid
  admin_password         = var.autonomous_data_warehouse_admin_password
  db_name                = "MYHUBADW"
  db_workload            = "DW"
  display_name           = "my-hub-adw"
  is_free_tier           = true
  license_model          = "LICENSE_INCLUDED"
  whitelisted_ips        = [module.network.vcn_id]
}
