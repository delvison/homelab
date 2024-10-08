setup() {
  source .env
}

@test "hello world" {
  curl test.local.${DOMAIN}
}
