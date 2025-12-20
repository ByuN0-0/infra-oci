variable "compartment_ocid" {
  type        = string
  description = "Compartment OCID."
}

variable "vcn_name" {
  type        = string
  description = "VCN name."
}

variable "vcn_cidr" {
  type        = string
  description = "VCN CIDR."
}

variable "public_subnet_cidr" {
  type        = string
  description = "Public subnet CIDR."
}

variable "private_subnet_cidr" {
  type        = string
  description = "Private subnet CIDR."
}
