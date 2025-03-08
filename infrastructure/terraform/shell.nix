{ pkgs ? import <nixpkgs> {} }:

let
 tf = pkgs.terraform;
 tfer = pkgs.terraformer;
 sops = pkgs.sops;
 cfTerraforming = builtins.fetchTarball {
    url = "https://github.com/cloudflare/cf-terraforming/releases/download/v0.23.2/cf-terraforming_0.23.2_linux_amd64.tar.gz";
    sha256 = "sha256:1l98nihvgkx03x3imkc9bsx4bh6zv8bfagqsi2vj8f007g0igfiy"; 
 };

 terraformingBinary = pkgs.runCommand "cf-terraforming" { inherit cfTerraforming; } ''
    mkdir -p $out/bin
    cp ${cfTerraforming}/cf-terraforming $out/bin/cf-terraforming
    chmod +x $out/bin/cf-terraforming
 '';
in
pkgs.mkShell {
 buildInputs = [ terraformingBinary tf sops tfer ];
}
