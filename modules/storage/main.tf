resource "oci_objectstorage_bucket" "this" {
  compartment_id = var.compartment_ocid
  name           = var.bucket_name
  namespace      = var.namespace
  access_type    = var.access_type
}
