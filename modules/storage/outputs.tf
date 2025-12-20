output "bucket_name" {
  description = "Bucket name."
  value       = oci_objectstorage_bucket.this.name
}

output "bucket_id" {
  description = "Bucket OCID."
  value       = oci_objectstorage_bucket.this.id
}
