{ pkgs, ... }:
{
  # ==========================================================================
  # Nextcloud statt ownCloud
  #
  # Entscheidung: nur die DATEIEN uebernehmen, nicht die Datenbank.
  # Grund: Der offizielle Weg ownCloud -> Nextcloud verlangt einen
  # Zwischenschritt ueber Nextcloud 25 - eine Version, die in nixpkgs 26.05
  # nicht mehr existiert. Diese Kette waere hier nicht sauber nachbaubar.
  #
  # Verloren gehen: Freigaben, oeffentliche Links, Dateiversionen, Papierkorb.
  # Erhalten bleiben: alle Dateien (3,9 GB).
  #
  # Ablauf nach dem ersten Deploy:
  #   1. Dateien nach /mnt/data/nextcloud/<user>/files/ legen
  #   2. chown -R nextcloud:nextcloud /mnt/data/nextcloud
  #   3. nextcloud-occ files:scan --all
  # ==========================================================================
  services.nextcloud = {
    enable = true;

    # Verfuegbare Version pruefen:  nix search nixpkgs nextcloud
    # In nixpkgs liegen meist mehrere parallel (nextcloud30/31/...).
    package = pkgs.nextcloud31;

    hostName = "owncloud.tilmanbertram.com"; # DNS-Name bleibt, kein DNS-Umzug
    https = true;

    # Nutzdaten auf dem Block Storage - getrennt vom System.
    # Setzt voraus, dass /mnt/data in hardware.nix eingehaengt ist.
    datadir = "/mnt/data/nextcloud";

    config = {
      dbtype = "mysql";
      adminuser = "admin";
      # Datei vorher anlegen:
      #   echo -n 'PASSWORT' > /etc/nextcloud-admin-pass && chmod 600 ...
      adminpassFile = "/etc/nextcloud-admin-pass";
    };

    # Legt MariaDB-Datenbank und -Benutzer an, Verbindung ueber Socket.
    # MariaDB bleibt bewusst auf der lokalen Platte: klein (12,4 MB Nutzdaten)
    # und latenzempfindlich - Block Storage ist netzwerkangebunden.
    database.createLocally = true;

    settings = {
      trusted_domains = [ "owncloud.tilmanbertram.com" ];
      default_phone_region = "DE";
    };
  };

  services.nginx.virtualHosts."owncloud.tilmanbertram.com" = {
    forceSSL = true;
    enableACME = true;
  };
}
