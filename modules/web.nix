{ site, ... }:
let
  webroot = "/var/www/${site.domain}/html";
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
  ];

  services.nginx = {
    enable = true;
    recommendedTlsSettings = true;
    recommendedOptimisation = true;
    recommendedGzipSettings = true;
    recommendedProxySettings = true;

    virtualHosts.${site.domain} = {
      forceSSL = true;
      enableACME = true;
      serverAliases = [ "www.${site.domain}" ];
      root = webroot;
    };
  };

  # Deno-Service hinter dem Reverse Proxy - erst einkommentieren, wenn der
  # Container laeuft, sonst scheitert der nginx-Start am nicht erreichbaren
  # Upstream.
  #
  # services.nginx.virtualHosts.${site.domain}.locations."/api/" = {
  #   proxyPass = "http://127.0.0.1:8000/";
  #   proxyWebsockets = true;
  # };
}
