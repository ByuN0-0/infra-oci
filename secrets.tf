resource "oci_kms_vault" "my_hub" {
  compartment_id = var.compartment_ocid
  display_name   = "my-hub-vault"
  vault_type     = "DEFAULT"
}

resource "oci_kms_key" "my_hub_secrets" {
  compartment_id      = var.compartment_ocid
  display_name        = "my-hub-secrets-key"
  management_endpoint = oci_kms_vault.my_hub.management_endpoint
  protection_mode     = "SOFTWARE"

  key_shape {
    algorithm = "AES"
    length    = 32
  }
}

resource "oci_identity_dynamic_group" "my_hub_api_secret_readers" {
  compartment_id = var.tenancy_ocid
  name           = "my-hub-api-secret-readers"
  description    = "my-hub API compute instances allowed to read bootstrap secrets."
  matching_rule  = "ALL {instance.compartment.id = '${var.compartment_ocid}'}"
}

resource "oci_identity_policy" "my_hub_api_secret_read" {
  compartment_id = var.tenancy_ocid
  name           = "my-hub-api-secret-read"
  description    = "Allow the my-hub API compute instance to read OCI Vault secret bundles."

  statements = [
    "Allow dynamic-group ${oci_identity_dynamic_group.my_hub_api_secret_readers.name} to read secret-bundles in compartment id ${var.compartment_ocid}",
    "Allow dynamic-group ${oci_identity_dynamic_group.my_hub_api_secret_readers.name} to inspect vaults in compartment id ${var.compartment_ocid}"
  ]
}

resource "oci_vault_secret" "minecraft_admin_cloudflare_tunnel_token" {
  compartment_id = var.compartment_ocid
  key_id         = oci_kms_key.my_hub_secrets.id
  secret_name    = "minecraft-admin-cloudflare-tunnel-token"
  vault_id       = oci_kms_vault.my_hub.id
  description    = "Remotely managed Cloudflare Tunnel token for the Minecraft admin page."

  secret_content {
    content_type = "BASE64"
    content      = base64encode(var.cloudflare_tunnel_token)
    name         = "current"
    stage        = "CURRENT"
  }
}
