{
  description = "NixOS-Serverkonfiguration - Website, Nextcloud, Deno-API, Elixir-Dienst";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-26.05";

    # Deklarative Partitionierung. nixos-anywhere teilt die Platte danach auf,
    # formatiert und installiert in einem Durchgang - siehe hosts/versa/disko.nix
    disko = {
      url = "github:nix-community/disko";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    # Geheimnisse verschluesselt im Repo. Entschluesselt wird zur
    # Aktivierungszeit mit dem SSH-Host-Key der Zielmaschine, direkt nach
    # /run/agenix - auf tmpfs, nie auf der Platte, nie im /nix/store.
    agenix = {
      url = "github:ryantm/agenix";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    # Anwendungscode: Deno-API und Elixir-Poller.
    #
    # flake = false, weil das Repo kein eigenes flake.nix hat - Nix behandelt
    # es dann als reine Quellenablage.
    #
    # Der Clou: flake.lock haelt fest, WELCHER Commit gerade laeuft. Damit ist
    # `git log flake.lock` der Deployment-Verlauf, und ein Rollback ist ein
    # Zurueckgehen auf eine alte Lock-Datei.
    #
    # Aktualisieren:  nix flake update pw23-be
    # Zum Entwickeln: url = "path:/home/tw/Programme/pw23-BE";  (nicht
    #                 reproduzierbar, deshalb nicht als Dauerzustand)
    pw23-be = {
      url = "github:dxdye/pw23-BE/main";
      flake = false;
    };

    # Frontend: Vite/React-Build, gleiches Muster.
    #
    # Baubar aus dem Repository allein ist es erst, seit Texte und Bilder
    # ausserhalb des Builds liegen (siehe web.nix) - vorher haette ein Build
    # aus dem GitHub-Stand eine Seite ohne Inhalte und ohne Bilder ergeben.
    #
    # Aktualisieren: nix flake update pw23
    #
    # Zum Testen eines Branches vor dem Merge:
    #   url = "github:d2tsb/PW23?ref=feat/mein-branch";
    # ?ref= und nicht github:owner/repo/feat/... - ein Branchname mit
    # Schraegstrich waere im Pfad mehrdeutig.
    pw23 = {
      url = "github:d2tsb/PW23/main";
      flake = false;
    };
  };

  outputs = { self, nixpkgs, disko, agenix, ... }@inputs: {
    nixosConfigurations.versa = nixpkgs.lib.nixosSystem {
      system = "x86_64-linux";
      specialArgs = { inherit inputs; };
      modules = [
        disko.nixosModules.disko
        agenix.nixosModules.default
        ./hosts/versa
      ];
    };

    # Damit `nix run .#agenix -- -e secrets/xyz.age` ohne separate
    # Installation funktioniert.
    packages.x86_64-linux.agenix = agenix.packages.x86_64-linux.default;
  };
}
