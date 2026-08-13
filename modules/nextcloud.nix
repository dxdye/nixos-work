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

    # VORUEBERGEHEND 32, nicht 33.
    #
    # Der alte Server lief auf Nextcloud 30. Nextcloud verbietet das
    # Ueberspringen von Hauptversionen, und nixpkgs 26.05 hat kein
    # nextcloud31 - die Kette 30->31->32->33 liesse sich hier also nicht
    # nachbauen. Deshalb wurde auf dem alten Server per offiziellem Updater
    # auf 32 hochgezogen (30.0.5 -> 30.0.17 -> 31.0.14 -> 32.x, PHP 8.2
    # deckt alle drei ab).
    #
    # Damit die Datenbank uebernommen werden kann, muss diese Instanz
    # dieselbe Version fahren. NACH erfolgreicher Uebernahme auf
    # pkgs.nextcloud33 stellen - das ist dann ein einzelner, unterstuetzter
    # Schritt, den occ upgrade beim naechsten Deploy selbst erledigt.
    #
    # Version gezielt pruefen, NICHT per `nix search nixpkgs nextcloud`:
    # das evaluiert den kompletten Baum und braucht mehrere GB RAM.
    #   nix eval --raw nixpkgs#nextcloud32.version
    package = pkgs.nextcloud32;

    hostName = "owncloud.tilmanbertram.com"; # DNS-Name bleibt, kein DNS-Umzug
    https = true;

    # KEIN explizites datadir - der Standard ist services.nextcloud.home,
    # also /var/lib/nextcloud.
    #
    # Urspruenglich stand hier /mnt/data auf einem Block-Storage-Volume, fuer
    # eine saubere Trennung Daten/System. Das Volume entfiel (die Region bietet
    # keins), und der zurueckgebliebene Pfad /var/lib/nextcloud/data war dann
    # ein Datenverzeichnis INNERHALB des Home-Verzeichnisses. In dieser
    # Verschachtelung verweigert systemd-tmpfiles den Besitzerwechsel
    # ("unsafe path transition"), und nextcloud-setup bricht ab mit:
    #   /var/lib/nextcloud/data/config is not owned by user 'nextcloud'!
    #
    # Bei 23 GB Platte und 3,9 GB Daten ist Platz kein Thema.
    # Falls spaeter doch ein Volume dazukommt: datadir auf einen Pfad AUSSERHALB
    # von home setzen, z.B. /mnt/data/nextcloud.

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
