{
  description = "NixOS on MacBook Pro M1 Pro";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
    apple-silicon-support.url = "github:nix-community/nixos-apple-silicon";
  };

  outputs = { self, nixpkgs, apple-silicon-support }:
  let
    system = "aarch64-linux";
    pkgs = import nixpkgs { inherit system; config.allowUnfree = true; };
    claude-code = pkgs.callPackage ./packages/claude-code { };
  in {
    nixosConfigurations.nixos = nixpkgs.lib.nixosSystem {
      inherit system;
      specialArgs = { inherit claude-code; };
      modules = [
        apple-silicon-support.nixosModules.apple-silicon-support
        ./configuration.nix
      ];
    };
  };
}
