{
  description = "fillya - Vultr VC2, NixOS 26.05";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-26.05";

    # Deklarative Partitionierung. nixos-anywhere teilt die Platte danach auf,
    # formatiert und installiert in einem Durchgang - siehe hosts/fillya/disko.nix
    disko = {
      url = "github:nix-community/disko";
      inputs.nixpkgs.follows = "nixpkgs";
    };
  };

  outputs = { self, nixpkgs, disko, ... }@inputs: {
    nixosConfigurations.fillya = nixpkgs.lib.nixosSystem {
      system = "x86_64-linux";
      specialArgs = { inherit inputs; };
      modules = [
        disko.nixosModules.disko
        ./hosts/fillya
      ];
    };
  };
}
