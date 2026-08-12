# my-hub VM runtime scripts

## Craft to Exile 2 deployment

The current VM is repurposed as a Craft to Exile 2 1.1.3 server. The local
server-pack ZIP remains untracked under `mode/` and is uploaded to Object
Storage before the VM downloads it with instance-principal authentication.

```bash
./scripts/deploy-minecraft.sh
```

The deployment expands the existing 200 GB boot disk, creates a 140 GB XFS
logical volume mounted at `/srv/minecraft`, installs the pinned Java 17 Podman
runtime, and enables `craft-to-exile-2.service`.

Whitelist management:

```bash
sudo podman exec craft-to-exile-2 rcon-cli whitelist list
sudo podman exec craft-to-exile-2 rcon-cli whitelist add PlayerName
sudo podman exec craft-to-exile-2 rcon-cli whitelist remove PlayerName
```

Useful checks:

```bash
sudo systemctl status craft-to-exile-2.service
sudo podman logs -f craft-to-exile-2
sudo systemctl start minecraft-backup-to-oci.service
```

### Korean overrides deployment

The Korean translation is an overrides archive, not a server resource pack.
Keep the untracked ZIP under `mode/` and deploy it with:

```bash
./scripts/deploy-minecraft-overrides.sh
```

The script uploads the archive to Object Storage, creates and verifies a fresh
Simple Backups archive, gracefully stops Minecraft, overlays the files onto
`/srv/minecraft/data`, removes the old resource-pack settings, and starts the
server again. It never overwrites the world, whitelist, OP list, or
`server.properties` from the ZIP.

## Minecraft admin page

After the `minecraft-admin` Cloudflare Tunnel and Access application exist and
Terraform has stored its token in OCI Vault, deploy the loopback-only admin
runtime:

```bash
./scripts/deploy-minecraft-admin.sh
```

The deployment creates a Simple Backups archive first, publishes RCON only on
`127.0.0.1:25575`, builds the ARM64 Go application, and starts the application
and `cloudflared` as resource-limited Quadlet services. No admin HTTP or RCON
port is opened in OCI networking or `firewalld`.

Useful checks:

```bash
sudo systemctl status minecraft-admin.service minecraft-admin-cloudflared.service
sudo journalctl -u minecraft-admin.service -u minecraft-admin-cloudflared.service -f
curl http://127.0.0.1:8081/healthz
sudo tail -f /srv/minecraft-admin/audit/audit.jsonl
```

The sections below describe the retired my-hub API runtime and are retained
only as historical migration notes.

These scripts are for an already-running `my-hub-api` VM. New VMs receive the
same runtime shape through `cloud-init-my-hub-api.yaml.tftpl`.

## Initial setup on the VM

Copy `setup-my-hub-api-runtime.sh` to the VM through your OCI Bastion session,
then run it as root:

```bash
sudo IMAGE_URL='ap-chuncheon-1.ocir.io/<namespace>/my-hub-api:latest' \
  PORT=8080 \
  ./setup-my-hub-api-runtime.sh
```

The script installs Podman, writes `/etc/my-hub-api.env`, writes the Quadlet
unit at `/etc/containers/systemd/my-hub-api.container`, and enables the
generated `my-hub-api.service`.

If the VM should refresh its runtime environment from OCI Vault during setup,
pass the Vault ID and secret name. The script uses instance principal auth and
logs in to private OCIR when the refreshed env contains `OCIR_USERNAME` and
`OCIR_AUTH_TOKEN`:

```bash
sudo IMAGE_URL='ap-chuncheon-1.ocir.io/<namespace>/my-hub-api:latest' \
  OCI_VAULT_ID='<vault-ocid>' \
  OCI_ENV_SECRET='my-hub-api-env' \
  ./setup-my-hub-api-runtime.sh
```

Because OCIR is private, login once before starting the service:

```bash
sudo podman login ap-chuncheon-1.ocir.io
sudo systemctl start my-hub-api.service
sudo systemctl status my-hub-api.service
```

## New VM bootstrap

New `my-hub-api` instances run `/usr/local/sbin/my-hub-api-bootstrap` from
cloud-init. The bootstrap can do the previously manual work automatically:

- read `my-hub-api-env` from OCI Vault through instance principal auth
- log in to private OCIR when `OCIR_USERNAME` and `OCIR_AUTH_TOKEN` are present
- start `my-hub-api.service`

Add these lines to the `my-hub-api-env` Vault secret if you want OCIR login to
be automatic on new instances:

```env
OCIR_USERNAME=<namespace>/<oci-user-name>
OCIR_AUTH_TOKEN=<oci-auth-token>
```

## Deploy a refreshed image

```bash
sudo ./restart-my-hub-api.sh
```

## Useful checks

```bash
podman ps
podman logs my-hub-api
sudo journalctl -u my-hub-api.service -f
curl http://127.0.0.1:8080/health
```

## my-hub secrets

Terraform creates a dedicated OCI Vault and KMS key for my-hub secrets, but it
does not create secret values. Put secret values in OCI Vault through Console
or OCI CLI so database passwords do not end up in Terraform state.

Create a secret after `terraform apply`:

```bash
VAULT_ID="$(terraform output -raw my_hub_vault_id)"
KEY_ID="$(terraform output -raw my_hub_secrets_key_id)"
COMPARTMENT_ID="$(terraform output -raw compartment_ocid)"

oci vault secret create-base64 \
  --compartment-id "${COMPARTMENT_ID}" \
  --vault-id "${VAULT_ID}" \
  --key-id "${KEY_ID}" \
  --secret-name "my-hub-mysql-dsn" \
  --secret-content-content "$(printf %s 'secret-value-here' | base64 | tr -d '\n')"
```

Read a secret from the VM with instance principal auth:

```bash
oci secrets secret-bundle get \
  --auth instance_principal \
  --secret-id "<secret-ocid>" \
  --query 'data."secret-bundle-content".content' \
  --raw-output | base64 -d
```
