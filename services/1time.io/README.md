# 1time.io

Self-hosted one-time secret and file sharing stack.

## Components

- `web` – Nginx-served frontend, published on `${APP_PORT}` (default `8080`)
- `backend` – API and file storage, backed by Redis
- `redis` – Persistence for links and metadata

Data is stored in the `1time-data` Docker volume and all services
communicate over the `1time-net` bridge network.

## Configuration

Copy `.env.example` to `.env` and adjust the values:

- `APP_HOSTNAME` – public hostname the app is served under
- `APP_PORT` – host port mapped to the web container
- `BACKEND_UPSTREAM` – backend address used by the web container
- `TZ` – timezone

## Usage

```sh
docker compose up -d
```
