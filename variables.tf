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

variable "vcn_name" {
  type        = string
  description = "VCN display name."
  default     = "my-hub-vcn"
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

variable "my_hub_api_hostname" {
  type        = string
  description = "Public hostname to point manually at the my-hub API load balancer."
  default     = "blog-api.biyeon.net"
}

variable "my_hub_api_compute_shape" {
  type        = string
  description = "Shape for the my-hub API compute instance."
  default     = "VM.Standard.A1.Flex"
}

variable "my_hub_api_ocpus" {
  type        = number
  description = "OCPUs for the my-hub API compute instance."
  default     = 2
}

variable "my_hub_api_memory_gbs" {
  type        = number
  description = "Memory (GB) for the my-hub API compute instance."
  default     = 18
}

variable "my_hub_api_boot_volume_size_gbs" {
  type        = number
  description = "Boot volume size in GBs for the my-hub API compute instance."
  default     = 200
}

variable "ssh_authorized_keys" {
  type        = string
  description = "SSH public key for instance access."
}

variable "my_hub_api_repository_name" {
  type        = string
  description = "OCIR repository name for the my-hub API image."
  default     = "my-hub-api"
}

variable "my_hub_api_image_tag" {
  type        = string
  description = "OCIR image tag for the my-hub API image."
  default     = "latest"
}

variable "my_hub_api_port" {
  type        = number
  description = "Port exposed by the my-hub API."
  default     = 8080
}

variable "my_hub_api_health_path" {
  type        = string
  description = "HTTP health check path exposed by the my-hub API."
  default     = "/health"
}

variable "my_hub_api_environment_variables" {
  type        = map(string)
  description = "Additional non-secret environment variables for the my-hub API."
  default     = {}
}

variable "my_hub_api_lb_min_bandwidth_mbps" {
  type        = number
  description = "Minimum bandwidth for the flexible public load balancer."
  default     = 10
}

variable "my_hub_api_lb_max_bandwidth_mbps" {
  type        = number
  description = "Maximum bandwidth for the flexible public load balancer."
  default     = 10
}

variable "my_hub_api_origin_certificate_public_certificate" {
  type        = string
  description = "Public certificate PEM for the my-hub API HTTPS load balancer listener, for example a Cloudflare Origin Certificate."
  default     = null
}

variable "my_hub_api_origin_certificate_private_key" {
  type        = string
  description = "Private key PEM for the my-hub API HTTPS load balancer listener."
  sensitive   = true
  default     = null
}

variable "my_hub_api_origin_certificate_ca_certificate" {
  type        = string
  description = "Optional CA certificate PEM chain for the my-hub API HTTPS load balancer listener."
  default     = null
}

variable "mysql_admin_username" {
  type        = string
  description = "Admin username for MySQL HeatWave."
  default     = "admin"
}

variable "mysql_admin_password" {
  type        = string
  description = "Admin password for MySQL HeatWave."
  sensitive   = true
  default     = null
}

variable "enable_mysql_heatwave" {
  type        = bool
  description = "Whether to create the MySQL HeatWave Always Free DB system."
  default     = true
}

variable "mysql_iam_policy_group_name" {
  type        = string
  description = "OCI IAM group name that Terraform should grant permissions for managing MySQL HeatWave resources. Use the identity-domain syntax, for example 'Default'/'TerraformAdmins', when required."
  default     = null
}

variable "mysql_shape_name" {
  type        = string
  description = "MySQL HeatWave DB system shape."
  default     = "MySQL.Free"
}

variable "mysql_data_storage_size_in_gb" {
  type        = number
  description = "MySQL HeatWave data storage size in GB."
  default     = 50
}

variable "autonomous_json_admin_password" {
  type        = string
  description = "Admin password for the Autonomous JSON Database."
  sensitive   = true
  default     = null
}

variable "autonomous_data_warehouse_admin_password" {
  type        = string
  description = "Admin password for the Autonomous Data Warehouse."
  sensitive   = true
  default     = null
}

variable "enable_autonomous_json_database" {
  type        = bool
  description = "Whether to create an Always Free Autonomous JSON Database."
  default     = true
}

variable "enable_autonomous_data_warehouse" {
  type        = bool
  description = "Whether to create the Always Free Autonomous Data Warehouse."
  default     = true
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
