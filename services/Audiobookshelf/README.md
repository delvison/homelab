# Audiobookshelf

Self-hosted audiobook and ebook server with a web UI and mobile apps.

- [audiobookshelf.org](https://www.audiobookshelf.org)
- [advplyr/audiobookshelf](https://github.com/advplyr/audiobookshelf)

The `abs-opds` sidecar exposes an OPDS catalog for Audiobookshelf so e-readers
(KOReader, Thorium, Moon+ Reader, ...) can browse and download books.

- [Vito0912/abs-opds](https://github.com/Vito0912/abs-opds)

## Usage

### Deploy

```sh
just deploy
```

This sets the Docker context to the remote host (`$HOST-docker`), copies the
service directory to `$BASE_DIR`, and recreates the container.

### Logs

```sh
just logs
```

## Configuration

| Variable                | Description                                    |
| ----------------------- | ---------------------------------------------- |
| `HOST`                  | Remote host for the `$HOST-docker` context     |
| `BASE_DIR`              | Host directory for config and metadata         |
| `AUDIOBOOKSHELF_DOMAIN` | Public hostname Caddy serves Audiobookshelf on |

## Volumes

| Container path | Source                                | Purpose           |
| -------------- | ------------------------------------- | ----------------- |
| `/config`      | `${BASE_DIR}/audiobookshelf/config`   | Application state |
| `/metadata`    | `${BASE_DIR}/audiobookshelf/metadata` | Covers and cache  |
| `/audiobooks`  | `/mnt/rustfs-media/Books/Audiobooks`  | Audiobook library |
| `/books`       | `/mnt/rustfs-media/Books/Ebooks`      | Ebook library     |

The UI is exposed on port `2008`.

`abs-opds` is exposed on port `2007` (container port `3010`) and is reached at
`/opds` — e.g. `https://$AUDIOBOOKSHELF_DOMAIN/opds`. Add that URL in your OPDS
reader and log in with your Audiobookshelf credentials.

## Clients

- For KOReader: must input URL as `http://<user>:<password>@example.com/opds`
  and leave authentication forms blank.

## Resources

- [audiobookshelf.org/docs](https://www.audiobookshelf.org/docs)
