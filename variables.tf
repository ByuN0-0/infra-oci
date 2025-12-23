variable "tenancy_ocid" {
  type        = string
  description = "OCI tenancy OCID."
}

variable "user_ocid" {
  type        = string
  description = "OCI user OCID."
}

variable "fingerprint" {
  type        = string
  description = "API key fingerprint."
}

variable "private_key" {
  type        = string
  description = "The contents of the OCI API private key."
  sensitive   = true
}

variable "region" {
  type        = string
  description = "OCI region."
  default     = "ap-chuncheon-1"
}

variable "compartment_ocid" {
  type        = string
  description = "Compartment OCID to deploy into."
}

variable "ssh_authorized_keys" {
  type        = string
  description = "SSH public key for instance access."
}

variable "vcn_name" {
  type        = string
  description = "VCN display name."
  default     = "vcn-biyeon"
}

variable "vcn_cidr" {
  type        = string
  description = "VCN CIDR block."
  default     = "10.0.0.0/16"
}

variable "public_subnet_cidr" {
  type        = string
  description = "Public subnet CIDR block."
  default     = "10.0.1.0/24"
}

variable "private_subnet_cidr" {
  type        = string
  description = "Private subnet CIDR block."
  default     = "10.0.2.0/24"
}

variable "availability_domain_index" {
  type        = number
  description = "Availability domain index (0-based)."
  default     = 0
}

variable "minecraft_shape" {
  type        = string
  description = "Shape for the Minecraft instance."
  default     = "VM.Standard.A1.Flex"
}

variable "minecraft_ocpus" {
  type        = number
  description = "OCPUs for the Minecraft instance."
  default     = 1
}

variable "minecraft_memory_gbs" {
  type        = number
  description = "Memory (GB) for the Minecraft instance."
  default     = 10
}

variable "private_shape" {
  type        = string
  description = "Shape for the private instance."
  default     = "VM.Standard.A1.Flex"
}

variable "private_ocpus" {
  type        = number
  description = "OCPUs for the private instance."
  default     = 1
}

variable "private_memory_gbs" {
  type        = number
  description = "Memory (GB) for the private instance."
  default     = 2
}

variable "cloudflare_tunnel_token" {
  type        = string
  description = "Cloudflare Tunnel token for the private instance."
  sensitive   = true
}

variable "namespace" {
  type        = string
  description = "Object Storage namespace."
}

variable "object_storage_bucket_name" {
  type        = string
  description = "Object Storage bucket name."
  default     = "shared-storage"
}

variable "object_storage_access_type" {
  type        = string
  description = "Object Storage access type."
  default     = "NoPublicAccess"
}
