resource "oci_identity_policy" "mysql_heatwave_management" {
  count          = var.enable_mysql_heatwave && var.mysql_iam_policy_group_name != null ? 1 : 0
  compartment_id = var.tenancy_ocid
  name           = "blog-mysql-heatwave-management"
  description    = "Allow Terraform operators to create and attach MySQL HeatWave DB systems."

  statements = [
    "Allow group ${var.mysql_iam_policy_group_name} to manage mysql-family in compartment id ${var.compartment_ocid}",
    "Allow group ${var.mysql_iam_policy_group_name} to manage virtual-network-family in compartment id ${var.compartment_ocid}",
    "Allow group ${var.mysql_iam_policy_group_name} to inspect compartments in tenancy",
    "Allow any-user to {NETWORK_SECURITY_GROUP_UPDATE_MEMBERS} in compartment id ${var.compartment_ocid} where all {request.principal.type='mysqldbsystem', request.resource.compartment.id='${var.compartment_ocid}'}",
    "Allow any-user to {VNIC_CREATE, VNIC_UPDATE, VNIC_ASSOCIATE_NETWORK_SECURITY_GROUP, VNIC_DISASSOCIATE_NETWORK_SECURITY_GROUP} in compartment id ${var.compartment_ocid} where all {request.principal.type='mysqldbsystem', request.resource.compartment.id='${var.compartment_ocid}'}"
  ]
}
