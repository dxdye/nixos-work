{ site, ... }:
{
  # ==========================================================================
  # Phase 6 - noch nicht aktiv (in hosts/versa/default.nix auskommentiert)
  #
  # Zwei Dienste:
  #   - Deno-Service auf Port 8000, von nginx per Reverse Proxy erreichbar
  #   - Elixir-Dienst ohne HTTP-Port, schreibt eine JSON-Datei,
  #     die nginx statisch ausliefert
  #
  # Auf NixOS gibt es zwei Wege. Dieser hier bildet dein docker-compose ab.
  # Der native Weg (systemd.services + Nix-Build des Deno/Elixir-Projekts)
  # waere reproduzierbarer, verlangt aber, dass die Projekte als Flakes
  # vorliegen. Fuer den Anfang: Container.
  # ==========================================================================
  virtualisation.oci-containers = {
    backend = "podman"; # rootless-faehig, kein Daemon - besser als Docker auf 1 GB

    containers = {
      # deno-service = {
      #   image = "denoland/deno:alpine";
      #   ports = [ "127.0.0.1:8000:8000" ];  # nur lokal, nginx proxied davor
      #   volumes = [ "/mnt/data/deno:/app" ];
      #   cmd = [ "run" "--allow-net" "--allow-read" "/app/main.ts" ];
      # };

      # elixir-worker = {
      #   image = "elixir:alpine";
      #   # kein Port - schreibt nur die JSON-Datei
      #   volumes = [ "/mnt/data/public:/out" ];
      # };
    };
  };

  # Die JSON-Datei, die der Elixir-Dienst schreibt, liefert nginx statisch aus:
  #
  # services.nginx.virtualHosts.${site.domain}.locations."/data.json" = {
  #   alias = "/mnt/data/public/data.json";
  #   extraConfig = ''
  #     add_header Cache-Control "no-cache";
  #   '';
  # };
}
