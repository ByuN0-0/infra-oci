variable "compartment_ocid" {
  type        = string
  description = "Compartment OCID."
}

variable "availability_domain" {
  type        = string
  description = "Availability domain name."
}

variable "subnet_id" {
  type        = string
  description = "Subnet OCID."
}

variable "display_name" {
  type        = string
  description = "Instance display name."
}

variable "hostname_label" {
  type        = string
  description = "VNIC hostname label."
}

variable "shape" {
  type        = string
  description = "Instance shape."
}

variable "ocpus" {
  type        = number
  description = "Number of OCPUs."
}

variable "memory_in_gbs" {
  type        = number
  description = "Memory in GB."
}

variable "ssh_authorized_keys" {
  type        = string
  description = "SSH public key."
}

variable "assign_public_ip" {
  type        = bool
  description = "Assign a public IP to the VNIC."
}

variable "user_data" {
  type        = string
  description = "Cloud-init user data."
  default     = ""
}
