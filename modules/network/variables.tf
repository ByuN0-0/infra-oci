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

variable "my_hub_api_port" {
  type        = number
  description = "Port exposed by the my-hub API."
}

variable "public_http_ingress_cidrs" {
  type        = set(string)
  description = "CIDR blocks allowed to reach HTTP/HTTPS resources in the public subnet."
  default     = []
}
