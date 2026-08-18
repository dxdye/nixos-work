{ site, securityHeaders, ... }:
let
  webroot = "/var/www/${site.domain}/html";

  # Die Seitentexte liegen bewusst nicht im Frontend-Repository und damit auch
  # nicht im Build - das Frontend holt sie zur Laufzeit von /texts.json.
  textsDir = "/var/lib/pw23-texts";
  textsPath = "${textsDir}/texts.json";
in
{
  # ==========================================================================
  # TLS
  # Auf dem alten Debian gab es KEINE Automatisierung: kein certbot-Timer,
  # kein Cronjob. Drei von fuenf Zertifikaten waren deshalb abgelaufen.
  # security.acme macht Erneuerung zum Systemzustand - nichts zu vergessen.
  # ==========================================================================
  security.acme = {
    acceptTerms = true;

    # Rollenadresse statt privater Mailadresse - siehe site.nix.
    # Muss tatsaechlich Mail empfangen: dorthin gehen die Warnungen von
    # Let's Encrypt, wenn eine Erneuerung ausbleibt.
    defaults.email = site.acmeEmail;
  };

  # ==========================================================================
  # Website - rein statisch.
  # Bestaetigt: die Suche nach *.php im Webroot war leer. Auf dem alten
  # Server lief trotzdem ein php8.1-fpm mit fastcgi_pass fuer diesen vhost -
  # das war schlicht ueberfluessig. Hier kein PHP.
  # ==========================================================================

  # Verzeichnisstruktur deklarieren, nicht von Hand anlegen - sonst fehlt sie
  # beim naechsten Neuaufsetzen und nginx liefert 404. Der INHALT ist Zustand
  # (Vite-Build, per rsync eingespielt), nur die Struktur gehoert hierher.
  systemd.tmpfiles.rules = [
    "d /var/www 0755 root root - -"
    "d /var/www/${site.domain} 0755 root root - -"
    "d ${webroot} 0755 nginx nginx - -"

    # Eigenes Verzeichnis statt Ablage im Webroot: Dorthin schreibt der
    # rsync-Lauf aus dem Vite-Build, und ein Aufruf mit --delete wuerde eine
    # texts.json neben den Build-Artefakten mitentfernen. Dieselbe Ueberlegung
    # wie bei der timeline.json in pw23-be.nix.
    #
    # Der Inhalt ist Zustand und wird per scp eingespielt, nur das Verzeichnis
    # gehoert hierher.
    "d ${textsDir} 0755 root nginx - -"
  ];

  services.nginx = {
    enable = true;
    recommendedTlsSettings = true;
    recommendedOptimisation = true;
    recommendedGzipSettings = true;
    recommendedProxySettings = true;

    virtualHosts = {
      ${site.domain} = {
        forceSSL = true;
        enableACME = true;
        serverAliases = [ "www.${site.domain}" ];
        root = webroot;

        # Gilt auch fuer /api/, weil diese Location kein eigenes add_header
        # setzt und den Block deshalb erbt. Fuer JSON-Antworten ist vor allem
        # nosniff relevant: ein Browser, der JSON als HTML interpretiert, ist
        # der klassische Weg zu XSS.
        extraConfig = securityHeaders;

        locations = {
          # Das Frontend nutzt BrowserRouter: /impressum existiert nur
          # clientseitig, es gibt keine gleichnamige Datei im Webroot. Ohne
          # tryFiles antwortet nginx darauf mit 404 - allerdings nur beim
          # direkten Aufruf und beim Neuladen. Navigiert man aus der Anwendung
          # heraus dorthin, laeuft alles ueber die History-API und der Fehler
          # bleibt unbemerkt.
          #
          # Diese Location setzt kein eigenes add_header und erbt deshalb die
          # securityHeaders von oben.
          "/".tryFiles = "$uri $uri/ /index.html";

          # Genau eine Datei aus dem Textverzeichnis. "=" ist ein exakter
          # Treffer, nichts anderes unterhalb von /var/lib wird dadurch
          # erreichbar.
          "= /texts.json" = {
            alias = textsPath;
            extraConfig = ''
              ${securityHeaders}
              add_header Cache-Control "public, max-age=3600";
              default_type application/json;
            '';
          };
        };
      };

      # Auffang fuer alles, was auf keinen der deklarierten Namen passt.
      #
      # Ohne diesen Block faellt nginx auf den ersten konfigurierten vhost
      # zurueck und praesentiert dessen Zertifikat - fuer einen fremden Namen
      # also ein falsches, mit Warnung im Browser.
      #
      # Konkret betrifft das die CNAMEs mail/phone/playchess/xyz, die auf den
      # Hauptnamen zeigen und damit auf dieser Maschine landen, ohne dass es
      # hier einen Dienst dafuer gibt. Unabhaengig davon probieren Bots
      # staendig fremde Hostnamen gegen jede erreichbare IP durch.
      #
      #   rejectSSL   nginx bricht den TLS-Handshake ab, statt irgendein
      #               Zertifikat auszuliefern (ssl_reject_handshake)
      #   return 444  nginx-eigener Code: Verbindung schliessen, ohne zu antworten
      "_" = {
        default = true;
        rejectSSL = true;
        locations."/".return = "444";
      };
    };
  };

  # Die Locations /api/ und /timeline.json gehoeren zu den Diensten und stehen
  # deshalb in pw23-be.nix, nicht hier. NixOS fuehrt beide Attributsaetze fuer
  # denselben vhost zusammen.
}
