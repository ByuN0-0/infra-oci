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

variable "blog_api_hostname" {
  type        = string
  description = "Public hostname to point manually at the OCI load balancer."
  default     = "api.blog.biyeon.net"
}

variable "blog_api_container_shape" {
  type        = string
  description = "Shape for the blog API container instance."
  default     = "CI.Standard.A1.Flex"
}

variable "blog_api_ocpus" {
  type        = number
  description = "OCPUs for the blog API container instance."
  default     = 1
}

variable "blog_api_memory_gbs" {
  type        = number
  description = "Memory (GB) for the blog API container instance."
  default     = 4
}

variable "blog_api_repository_name" {
  type        = string
  description = "OCIR repository name for the blog REST API image."
  default     = "blog-rest-api"
}

variable "blog_api_image_tag" {
  type        = string
  description = "OCIR image tag for the blog REST API image."
  default     = "latest"
}

variable "blog_api_port" {
  type        = number
  description = "Container port exposed by the blog REST API."
  default     = 8080
}

variable "blog_api_health_path" {
  type        = string
  description = "HTTP health check path exposed by the blog REST API."
  default     = "/health"
}

variable "blog_api_environment_variables" {
  type        = map(string)
  description = "Additional non-secret environment variables for the blog API container."
  default     = {}
}

variable "blog_api_lb_min_bandwidth_mbps" {
  type        = number
  description = "Minimum bandwidth for the flexible public load balancer."
  default     = 10
}

variable "blog_api_lb_max_bandwidth_mbps" {
  type        = number
  description = "Maximum bandwidth for the flexible public load balancer."
  default     = 10
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

variable "autonomous_admin_password" {
  type        = string
  description = "Admin password for Autonomous Database resources."
  sensitive   = true
  default     = null
}

variable "enable_autonomous_json_database" {
  type        = bool
  description = "Whether to create Autonomous JSON Database. OCI Terraform currently does not allow AJD with is_free_tier=true, so this defaults to false to avoid accidental paid resources."
  default     = false
}

variable "enable_autonomous_data_warehouse" {
  type        = bool
  description = "Whether to create the Always Free Autonomous Data Warehouse."
  default     = true
}

variable "enable_nosql_table" {
  type        = bool
  description = "Whether to create the Always Free Oracle NoSQL table."
  default     = true
}

variable "nosql_table_name" {
  type        = string
  description = "Name for the Oracle NoSQL experiment table."
  default     = "blog_experiment"
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
