{ pkgs, lib, inputs, site, securityHeaders, ... }:
let

  # Die Seitentexte liegen bewusst nicht im Frontend-Repository und damit auch
  # nicht im Build - das Frontend holt sie zur Laufzeit von /texts.json.
  textsDir = "/var/lib/pw23-texts";
  textsPath = "${textsDir}/texts.json";

  # Dasselbe fuer die Bilder. Sie sind im Frontend-Repo gitignoriert - teils
  # eigene Fotos, teils fremde Marken (HAW, Campudus, GitHub, LinkedIn), die
  # nicht mit weiterverbreitet werden sollen.
  #
  # Entscheidend fuer die Automatisierbarkeit: imageMap.ts baut reine
  # Laufzeitpfade (`/images/<name>`), importiert also nichts. Die Bilder
  # muessen den Build damit ueberhaupt nicht beruehren - er erzeugt nur noch
  # HTML, JS und CSS und ist ohne sie reproduzierbar.
  assetsDir = "/var/lib/pw23-assets";

  # Der Vite-Build als Nix-Paket. Damit ist der Webroot deklarativ statt
  # rsync-Zustand: Ein Deployment ist `nix flake update pw23` plus
  # nixos-rebuild, ein Rollback eine alte Generation. Und flake.lock haelt
  # fest, welcher Commit ausgeliefert wird - dieselbe Eigenschaft, die du bei
  # pw23-be schon nutzt.
  frontend = pkgs.buildNpmPackage {
    pname = "pw23-frontend";
    version = "0.1.0";
    src = inputs.pw23;

    # Node 26, wie in .nvmrc und shell.nix des Frontends.
    nodejs = pkgs.nodejs_26;

    # Hash ueber die geholten npm-Abhaengigkeiten - dasselbe Prinzip wie
    # mixFodDeps in pw23-be.nix. Beim ersten Bauen schlaegt es fehl und Nix
    # nennt den richtigen Wert ("got: sha256-..."); der gehoert dann hierher.
    # Aendert sich package-lock.json, aendert sich auch dieser Wert.
    npmDepsHash = lib.fakeHash;

    # buildNpmPackage ruft in der buildPhase `npm run build` auf, das Ergebnis
    # liegt danach in dist/. Ein `npm install` gibt es fuer eine statische
    # Seite nicht, deshalb eine eigene installPhase.
    installPhase = ''
      runHook preInstall
      cp -r dist $out
      runHook postInstall
    '';
  };
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

  # Der Webroot ist keine tmpfiles-Regel mehr: Er zeigt jetzt auf das
  # Frontend-Paket im /nix/store, wird also mit dem System gebaut statt per
  # rsync befuellt. /var/www wird damit nicht mehr gebraucht.
  #
  # Was bleibt, sind die Verzeichnisse fuer den INHALT - Texte und Bilder, die
  # bewusst nicht im Build stecken.
  systemd.tmpfiles.rules = [
    # Texte. Eigenes Verzeichnis aus demselben Grund wie die timeline.json in
    # pw23-be.nix: nicht im Webroot, damit sie kein Deployment mitentfernt.
    "d ${textsDir} 0755 root nginx - -"

    # Bilder, ebenfalls Zustand. Einmalig zu befuellen mit:
    #   rsync -av public/images/ root@versa:/var/lib/pw23-assets/images/
    #   rsync -av public/res/    root@versa:/var/lib/pw23-assets/res/
    "d ${assetsDir} 0755 root nginx - -"
    "d ${assetsDir}/images 0755 root nginx - -"
    "d ${assetsDir}/res 0755 root nginx - -"
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

        # Store-Pfad statt /var/www. Store-Pfade sind 0555, nginx kann daraus
        # lesen - und der Inhalt ist unveraenderlich, was ihn als Webroot
        # zusaetzlich absichert.
        root = frontend;

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

          # Bilder aus dem Asset-Verzeichnis statt aus dem Webroot.
          #
          # Die Schraegstriche am Ende gehoeren auf BEIDE Seiten: Bei
          # `location /images/` mit `alias .../images/` ersetzt nginx das
          # Praefix. Fehlt einer, entstehen Pfade wie /var/lib/pw23-assetsimages
          # oder doppelte Trenner.
          #
          # Ein Jahr Cache waere hier falsch: Die Dateinamen tragen keinen
          # Inhalts-Hash, ein ausgetauschtes Profilbild behielte also seinen
          # Namen. Eine Woche ist der Kompromiss.
          "/images/" = {
            alias = "${assetsDir}/images/";
            extraConfig = ''
              ${securityHeaders}
              add_header Cache-Control "public, max-age=604800";
            '';
          };

          "/res/" = {
            alias = "${assetsDir}/res/";
            extraConfig = ''
              ${securityHeaders}
              add_header Cache-Control "public, max-age=604800";
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
