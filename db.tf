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

resource "oci_core_network_security_group" "autonomous" {
  count          = var.enable_autonomous_json_database ? 1 : 0
  compartment_id = var.compartment_ocid
  vcn_id         = module.network.vcn_id
  display_name   = "my-hub-autonomous-nsg"
}

resource "oci_core_network_security_group_security_rule" "autonomous_ingress_api" {
  count                     = var.enable_autonomous_json_database ? 1 : 0
  network_security_group_id = oci_core_network_security_group.autonomous[0].id
  direction                 = "INGRESS"
  protocol                  = "6"
  source                    = oci_core_network_security_group.my_hub_api_compute.id
  source_type               = "NETWORK_SECURITY_GROUP"

  tcp_options {
    destination_port_range {
      min = 1522
      max = 1522
    }
  }
}

resource "oci_database_autonomous_database" "json" {
  count                  = var.enable_autonomous_json_database ? 1 : 0
  compartment_id         = var.compartment_ocid
  admin_password         = var.autonomous_admin_password
  db_name                = "MYHUBJSON"
  db_workload            = "AJD"
  display_name           = "my-hub-json"
  license_model          = "LICENSE_INCLUDED"
  subnet_id              = module.network.private_subnet_id
  private_endpoint_label = "my-hub-json"
  nsg_ids                = [oci_core_network_security_group.autonomous[0].id]
}

resource "oci_database_autonomous_database" "warehouse" {
  count                  = var.enable_autonomous_data_warehouse ? 1 : 0
  compartment_id         = var.compartment_ocid
  admin_password         = var.autonomous_admin_password
  db_name                = "MYHUBADW"
  db_workload            = "DW"
  display_name           = "my-hub-adw"
  is_free_tier           = true
  license_model          = "LICENSE_INCLUDED"
  whitelisted_ips        = [module.network.vcn_id]
}

resource "oci_nosql_table" "my_hub_experiment" {
  count          = var.enable_nosql_table ? 1 : 0
  compartment_id = var.compartment_ocid
  name           = var.nosql_table_name
  ddl_statement  = "CREATE TABLE IF NOT EXISTS ${var.nosql_table_name} (id STRING, payload JSON, created_at TIMESTAMP(6), PRIMARY KEY(id))"

  table_limits {
    capacity_mode      = "PROVISIONED"
    max_read_units     = 50
    max_write_units    = 50
    max_storage_in_gbs = 25
  }
}
