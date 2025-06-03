Use this role to install a git-server.

demo:

```sh
ssh git-server  create-repo myrepo.git
ssh git-server list-repos
ssh git-server add-mirror-repo https://github.com/FiloSottile/age
ssh git-server update-mirrors
```
