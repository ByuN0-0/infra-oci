# my-hub VM runtime scripts

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
