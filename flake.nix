{
  description = "NixOS on MacBook Pro M1 Pro";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
    apple-silicon-support.url = "github:nix-community/nixos-apple-silicon";
  };

  outputs = { self, nixpkgs, apple-silicon-support }: {
    nixosConfigurations.nixos = nixpkgs.lib.nixosSystem {
      system = "aarch64-linux";
      modules = [
        apple-silicon-support.nixosModules.apple-silicon-support
        ./configuration.nix
      ];
    };
  };
}
