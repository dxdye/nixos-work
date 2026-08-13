{ ... }:
{
  imports = [
    ./hardware.nix
    ../../modules/base.nix
    ../../modules/web.nix
    ../../modules/nextcloud.nix
    # ../../modules/containers.nix   # Phase 6: Deno + Elixir
  ];

  networking.hostName = "fillya";

  # Nicht aendern nach der Erstinstallation - legt fest, gegen welche
  # Zustandsformate (Datenbanken etc.) NixOS migriert.
  system.stateVersion = "26.05";
}
