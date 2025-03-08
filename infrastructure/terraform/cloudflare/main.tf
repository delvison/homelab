terraform {
  required_providers {
    cloudflare = {
      source  = "cloudflare/cloudflare"
      version = "~> 5"
    }
  }
}

# ref: https://registry.terraform.io/providers/cloudflare/cloudflare/latest/docs
# export CLOUDFLARE_API_TOKEN=
provider "cloudflare" {}

data "cloudflare_zone" "zone" {
  zone_id = var.cloudflare_zone_id
}

# ref: https://registry.terraform.io/providers/cloudflare/cloudflare/latest/docs/resources/dns_record
resource "cloudflare_dns_record" "dns_record" {
  for_each = toset(local.proxied)
  zone_id  = local.zone_id
  comment  = each.value
  content  = "proxy.${local.domain}."
  name     = "${each.value}.${local.domain}"
  proxied  = false
  ttl      = 1
  type     = "CNAME"
}

locals {
  zone_id = data.cloudflare_zone.zone.zone_id
  domain  = data.cloudflare_zone.zone.name
  proxied = [
    "n"
  ]
}
