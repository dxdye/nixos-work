{ ... }:
{
  imports = [
    ./disko.nix
    ./hardware.nix
    ../../modules/base.nix
    ../../modules/web.nix
    ../../modules/nextcloud.nix
    # ../../modules/containers.nix   # Phase 6: Deno + Elixir
  ];

  # Standortspezifische Werte an alle Module durchreichen. Die Module
  # verwenden `site.domain` statt fester Namen - damit steht die eigene
  # Infrastruktur an genau einer Stelle statt ueber das Repo verteilt.
  # Siehe site.nix, insbesondere den skip-worktree-Hinweis.
  _module.args.site = import ./site.nix;

  networking.hostName = "versa";

  # Nicht aendern nach der Erstinstallation - legt fest, gegen welche
  # Zustandsformate (Datenbanken etc.) NixOS migriert.
  system.stateVersion = "26.05";
}
