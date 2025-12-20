variable "compartment_ocid" {
  type        = string
  description = "Compartment OCID."
}

variable "namespace" {
  type        = string
  description = "Object Storage namespace."
}

variable "bucket_name" {
  type        = string
  description = "Bucket name."
}

variable "access_type" {
  type        = string
  description = "Bucket access type."
}
