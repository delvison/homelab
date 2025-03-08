let
  pkgs = import <nixpkgs> {};
in
 
pkgs.mkShell {
  packages = [
    pkgs.ansible
    pkgs.just
    pkgs.sops
    pkgs.sshpass
  ];
}
