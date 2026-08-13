{ ... }:
{
  # ==========================================================================
  # TLS
  # Auf dem Debian gab es KEINE Automatisierung: kein certbot-Timer, kein
  # Cronjob. Drei von fuenf Zertifikaten waren deshalb abgelaufen.
  # security.acme macht Erneuerung zum Systemzustand - nichts zu vergessen.
  # ==========================================================================
  security.acme = {
    acceptTerms = true;
    defaults.email = "tilmansoerenw@protonmail.com"; # ggf. anpassen
  };

  # ==========================================================================
  # Website - rein statisch.
  # Bestaetigt: `find /var/www/tilmanbertram.com/html -name '*.php'` war leer.
  # Auf dem Debian lief trotzdem ein php8.1-fpm mit fastcgi_pass fuer diesen
  # vhost - das war schlicht ueberfluessig. Hier kein PHP.
  # ==========================================================================
  # Verzeichnisstruktur fuer die statische Website. Deklariert statt von Hand
  # angelegt - sonst fehlt sie beim naechsten Neuaufsetzen wieder und nginx
  # liefert 404. Der INHALT ist Zustand (Vite-Build, per rsync eingespielt),
  # nur die Struktur gehoert in die Konfiguration.
  systemd.tmpfiles.rules = [
    "d /var/www 0755 root root - -"
    "d /var/www/tilmanbertram.com 0755 root root - -"
    "d /var/www/tilmanbertram.com/html 0755 nginx nginx - -"
  ];

  services.nginx = {
    enable = true;
    recommendedTlsSettings = true;
    recommendedOptimisation = true;
    recommendedGzipSettings = true;
    recommendedProxySettings = true;

    virtualHosts."tilmanbertram.com" = {
      forceSSL = true;
      enableACME = true;
      serverAliases = [ "www.tilmanbertram.com" ];
      root = "/var/www/tilmanbertram.com/html";
    };
  };

  # Phase 6: Deno-Service hinter dem Reverse Proxy.
  # Erst einkommentieren, wenn der Container laeuft - sonst scheitert der
  # nginx-Start an einem nicht erreichbaren Upstream.
  #
  # services.nginx.virtualHosts."tilmanbertram.com".locations."/api/" = {
  #   proxyPass = "http://127.0.0.1:8000/";
  #   proxyWebsockets = true;
  # };
}
