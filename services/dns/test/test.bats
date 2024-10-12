setup() {
  source .env
}

@test "resolve test record" {
  dig @${HOST_IP} test.local.${DOMAIN}
}
