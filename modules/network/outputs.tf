output "vcn_id" {
  description = "VCN OCID."
  value       = oci_core_vcn.this.id
}

output "public_subnet_id" {
  description = "Public subnet OCID."
  value       = oci_core_subnet.public.id
}

output "private_subnet_id" {
  description = "Private subnet OCID."
  value       = oci_core_subnet.private.id
}

output "nat_gateway_ip" {
  description = "Public IP address used by the NAT gateway."
  value       = oci_core_nat_gateway.this.nat_ip
}
