{pkgs ? import <nixpkgs> {}}: let
  defaultEndpoint = "http://127.0.0.1:19000";
in
  pkgs.mkShell {
    name = "rustfs-s3";

    packages = with pkgs; [
      awscli2
      minio-client
      rclone
      sops
      age
    ];

    shellHook = ''
      if [ -f .env ]; then
        set -a
        # shellcheck disable=SC1091
        . ./.env
        set +a
      fi

      # Prefer the deploy host from .env, fall back to localhost.
      endpoint="''${RUSTFS_ENDPOINT:-http://''${HOST:-127.0.0.1}:19000}"

      export AWS_ACCESS_KEY_ID="''${RUSTFS_ACCESS_KEY:-}"
      export AWS_SECRET_ACCESS_KEY="''${RUSTFS_SECRET_KEY:-}"
      export AWS_DEFAULT_REGION="''${AWS_DEFAULT_REGION:-us-east-1}"
      export AWS_ENDPOINT_URL="$endpoint"
      export AWS_ENDPOINT_URL_S3="$endpoint"

      # awscli needs path-style addressing for non-AWS endpoints.
      aws_cfg="$(mktemp -d)"
      export AWS_CONFIG_FILE="$aws_cfg/config"
      cat > "$AWS_CONFIG_FILE" <<EOF
      [default]
      region = $AWS_DEFAULT_REGION
      s3 =
          addressing_style = path
      EOF
      trap 'rm -rf "$aws_cfg"' EXIT

      # rclone configured entirely through env vars (no config file writes).
      export RCLONE_CONFIG_RUSTFS_TYPE="s3"
      export RCLONE_CONFIG_RUSTFS_PROVIDER="Minio"
      export RCLONE_CONFIG_RUSTFS_ENDPOINT="$endpoint"
      export RCLONE_CONFIG_RUSTFS_ACCESS_KEY_ID="$AWS_ACCESS_KEY_ID"
      export RCLONE_CONFIG_RUSTFS_SECRET_ACCESS_KEY="$AWS_SECRET_ACCESS_KEY"
      export RCLONE_CONFIG_RUSTFS_FORCE_PATH_STYLE="true"

      # mc alias via env var (no ~/.mc/config.json writes).
      rest="''${endpoint#http://}"
      if [ "$rest" != "$endpoint" ]; then
        export MC_HOST_rustfs="http://$AWS_ACCESS_KEY_ID:$AWS_SECRET_ACCESS_KEY@$rest"
      else
        export MC_HOST_rustfs="https://$AWS_ACCESS_KEY_ID:$AWS_SECRET_ACCESS_KEY@''${endpoint#https://}"
      fi

      echo "RustFS S3 shell — endpoint: $endpoint"
      if [ -z "$AWS_ACCESS_KEY_ID" ]; then
        echo "  (!) no credentials found; run 'just gen-secrets' and/or check .env"
      fi
      echo "  aws s3 ls"
      echo "  aws s3 cp ./file s3://bucket/"
      echo "  mc ls rustfs"
      echo "  rclone lsf rustfs:"
    '';
  }
