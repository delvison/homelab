# RustFS

Single-node [RustFS](https://rustfs.com) S3-compatible object storage.

- S3 API: `http://<host>:19000`
- Console: `http://<host>:19001`

The container runs as the host Docker user (`${UID}:${GID}`) and stores data
under `${BASE_DIR}/rustfs`. This is a single-node single-drive (SNSD)
deployment: it cannot be expanded in place or joined to a pool later.

## Setup

1. Generate the credentials (idempotent; refuses if already set):

   ```sh
   just gen-secrets
   ```

   This appends `RUSTFS_ACCESS_KEY` and `RUSTFS_SECRET_KEY` to the
   gitignored `.env`.

1. Commit the encrypted secrets:

   ```sh
   just save-secrets
   ```

1. Deploy:

   ```sh
   just deploy
   ```

The `volume-permission-helper` service creates and owns
`${BASE_DIR}/rustfs/{data,logs}` before RustFS starts, so no manual host
directory prep is required.

## Restoring secrets on a new machine

```sh
# from the repo root
just decrypt-all
```

## Clients

Point any S3 client at `http://<host>:19000` with the generated access/secret
keys. The console at port `19001` uses the same credentials.

### Shell (interactive)

Enter the configured shell to use rclone/mc/aws:

```sh
just shell
```

Inside the shell, the environment is set up automatically:

```sh
rclone lsf rustfs:       # list buckets
mc ls rustfs              # list buckets (nicer output)
aws s3 ls                 # list buckets
```

### rclone (persistent config)

Add to `~/.config/rclone/rclone.conf`:

```ini
[rustfs]
type = s3
provider = Minio
endpoint = http://host:19000
access_key_id = YOUR_ACCESS_KEY
secret_access_key = YOUR_SECRET_KEY
force_path_style = true
```

Replace `YOUR_ACCESS_KEY` and `YOUR_SECRET_KEY` with values from `.env`.
Run `just gen-secrets` if you don't have them.

Example usage:

```sh
rclone copy ./myfile.tar.gz rustfs:backups/
rclone sync ./local-dir rustfs:backup-dir/
rclone lsf rustfs:          # list buckets
rclone ls rustfs:bucket/    # list objects in bucket
```

### AWS CLI

Create `~/.aws/config`:

```ini
[profile rustfs]
region = us-east-1
s3 =
    addressing_style = path
```

And `~/.aws/credentials`:

```ini
[rustfs]
aws_access_key_id = YOUR_ACCESS_KEY
aws_secret_access_key = YOUR_SECRET_KEY
```

Or set environment variables:

```sh
export AWS_ACCESS_KEY_ID=YOUR_ACCESS_KEY
export AWS_SECRET_ACCESS_KEY=YOUR_SECRET_KEY
export AWS_ENDPOINT_URL=http://host:19000
```

Example usage:

```sh
aws s3 ls --endpoint-url http://host:19000
aws s3 cp ./myfile.tar.gz s3://backups/ --endpoint-url http://host:19000
aws s3 sync ./local-dir s3://backup-dir/ --endpoint-url http://host:19000
```

## Notes

- `RUSTFS_CONSOLE_CORS_ALLOWED_ORIGINS=*` is permissive. Tighten it to the
  console origin if you expose this beyond the LAN.
- `RUSTFS_UNSAFE_BYPASS_DISK_CHECK` defaults to `false`. Only set it to
  `true` for local testing.
- To use TLS, mount a cert directory to `/opt/tls` and set
  `RUSTFS_TLS_PATH=/opt/tls`; the healthcheck must then switch to HTTPS.
