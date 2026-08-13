{ config, pkgs, ... }:
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

    # Weg hierher, zur Nachvollziehbarkeit:
    #
    # Der alte Server lief auf Nextcloud 30. Nextcloud verbietet das
    # Ueberspringen von Hauptversionen, und nixpkgs 26.05 hat kein
    # nextcloud31 - die Kette 30->31->32->33 liess sich hier also nicht
    # nachbauen. Deshalb wurde auf dem alten Server per offiziellem Updater
    # auf 32 hochgezogen (30.0.5 -> 30.0.17 -> 31.0.14 -> 32.0.13; PHP 8.2
    # deckt alle drei ab). Diese Instanz lief dann ebenfalls auf 32, damit
    # die uebernommene Datenbank passte - Nextcloud verweigert den Start,
    # wenn der Code aelter ist als die Datenbank, auch auf Patch-Ebene.
    #
    # Erst nach der erfolgreichen Uebernahme dieser letzte Schritt auf 33:
    # eine Hauptversion, also unterstuetzt, und nextcloud-setup fuehrt
    # occ upgrade beim Deploy selbst aus.
    #
    # Version gezielt pruefen, NICHT per `nix search nixpkgs nextcloud`:
    # das evaluiert den kompletten Baum und braucht mehrere GB RAM.
    #   nix eval --raw nixpkgs#nextcloud33.version
    package = pkgs.nextcloud33;

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

    # ------------------------------------------------------------------
    # Apps aus dem App-Store, die auf dem alten Server aktiv waren.
    # Alles andere in `occ app:list` ist im Nextcloud-Server enthalten und
    # kommt automatisch mit.
    #
    # Die INHALTE dieser Apps (Termine, Kontakte, Mailkonten) liegen in der
    # Datenbank und werden ohnehin uebernommen. Fehlt nur der Programmcode,
    # deaktiviert Nextcloud die App - die Daten bleiben, sind aber unsichtbar.
    #
    # Deklarativ statt per Klick: so sind sie nach einem Neuaufsetzen sofort
    # wieder da und die Versionen sind an nixpkgs gebunden.
    # ------------------------------------------------------------------
    extraApps = with config.services.nextcloud.package.packages.apps; {
      inherit calendar contacts mail notes;
    };
    extraAppsEnable = true;

    # App-Store AUS. Beides zusammen geht nicht:
    #
    # Mit appstoreEnable = true sieht Nextcloud im Store eine neuere Version
    # einer per extraApps installierten App, will sie aktualisieren, kann den
    # nixpkgs-Pfad aber nicht ueberschreiben (/nix/store ist read-only) und
    # legt eine zweite Kopie unter /var/lib/nextcloud/store-apps ab. Ergebnis:
    #   PHP Fatal error: Cannot redeclare class ComposerAutoloaderInitCalendar
    #
    # Damit ist der App-Bestand jetzt vollstaendig deklariert: Was hier nicht
    # steht, existiert auf dem Server nicht. Das ist der Zustand, den wir
    # wollten - nur eben mit der Konsequenz, dass Nachinstallieren per
    # Weboberflaeche nicht mehr geht, sondern hier eingetragen werden muss.
    #
    # Verzicht dadurch: richdocuments (Collabora-Anbindung - braucht ohnehin
    # einen Collabora-Server, den es hier nicht gibt) und quota_warning.
    # Beide wurden beim Upgrade automatisch als inkompatibel deaktiviert.
    appstoreEnable = false;

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
