## Usage

### on Ubuntu

First, do the following to disable the default DNS service from using port 53.

```sh
echo "DNSStubListener=no" >> /etc/systemd/resolved.conf
systemctl restart systemd-resolved
```
