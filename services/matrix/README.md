This docker-compose project deploys [Synapse](https://github.com/element-hq/synapse).

## Usage

### Generate configuration file

Before first run, a configuration file must be created via the following:

```
docker run -it --rm -v $(pwd)/synapse/data:/data -e SYNAPSE_SERVER_NAME=my.matrix.host -e SYNAPSE_REPORT_STATS=no matrixdotorg/synapse:latest generate"
sudo chown -R 1000:100 synapse/
```

### Create first admin user

```sh
$ docker compose exec -it matrix-synapse register_new_matrix_user -c /data/homeserver.yaml
New user localpart [root]: admin
Password:
Confirm password:
Make admin [no]: yes
Sending registration request...
Success!
```

Once created, login with your admin user to <https://app.element.io>.

### Find access_token

1. Log in to the account you want to get the access token for. Click on the name in the top left corner, then "Settings".
1. Click the "Help & About" tab (left side of the dialog).
1. Scroll to the bottom and click on <click to reveal> part of Access Token.
1. Copy your access token to a safe place.

### Create new registration token

The registration process can be locked down so new users need a `registration_token` to join the server. To create a `registration_token`:

```sh
docker exec -it matrix-synapse curl  -X POST --header "Authorization: Bearer <access_token>" --data '{"length": 64}' localhost:8008/_synapse/admin/v1/registration_tokens/new
```

### Using postgres

In `homeserver.yaml`:

```yaml
database:
 name: psycopg2
 args:
   user: synapse
   password: matrixisawesome # changeme
   database: synapse
   host: matrix-synapse-db
   cp_min: 5
   cp_max: 10
```

### other useful options to add to homeserver.yaml

```yaml
registration_requires_token: true
enable_registration: true
url_preview_enabled: true
url_preview_ip_range_blacklist:
  - '127.0.0.0/8'
  - '10.0.0.0/8'
  - '172.16.0.0/12'
  - '192.168.0.0/16'
  - '100.64.0.0/10'
  - '192.0.0.0/24'
  - '169.254.0.0/16'
  - '192.88.99.0/24'
  - '198.18.0.0/15'
  - '192.0.2.0/24'
  - '198.51.100.0/24'
  - '203.0.113.0/24'
  - '224.0.0.0/4'
  - '::1/128'
  - 'fe80::/10'
  - 'fc00::/7'
  - '2001:db8::/32'
  - 'ff00::/8'
  - 'fec0::/10'
user_directory.search_all_users: true
serve_server_wellknown: true

email:
  smtp_host: matrix-postfix
  smtp_port: 587
  enable_notifs: true
  notif_from: "Your Friendly %(app)s homeserver <noreply@matrix.org>"  # changeme
  app_name: matrix.org  # changeme
  enable_notifs: true
  enable_tls: false
```

## Resources

- https://federationtester.matrix.org
