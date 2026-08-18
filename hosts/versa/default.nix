{ lib, ... }:
let
  # Content-Security-Policy. Streng moeglich, weil die Seite fast nichts von
  # aussen laedt - geprueft am gebauten dist/: kein Inline-<style>, keine
  # style=-Attribute, keine data:-URIs, und der einzige Inline-<script> ist
  # das JSON-LD, das der Browser nicht ausfuehrt.
  #
  # Die uebrigen externen Hosts (github.com, credly.com, haw-landshut.de ...)
  # sind reine Linkziele. Navigation faellt nicht unter die fetch-Direktiven,
  # sie brauchen deshalb keinen Eintrag.
  contentSecurityPolicy = lib.concatStringsSep "; " [
    "default-src 'self'"
    "script-src 'self'"

    # React setzt style={{...}} ueber das CSSOM, nicht als HTML-Attribut -
    # das faellt nicht unter style-src. Deshalb ohne 'unsafe-inline'.
    "style-src 'self'"

    "img-src 'self'"
    "font-src 'self'"

    # api.github.com wegen des Fallbacks im GithubCrawler: antwortet das
    # eigene Backend nicht, holt der Browser die Daten direkt dort.
    "connect-src 'self' https://api.github.com"

    # Schliesst Plugin-Einbettungen aus.
    "object-src 'none'"

    # Verhindert, dass injiziertes <base> relative Pfade umlenkt.
    "base-uri 'self'"

    "form-action 'self'"
    "frame-ancestors 'self'"
  ];
in
{
  imports = [
    ./disko.nix
    ./hardware.nix
    ../../modules/secrets.nix
    ../../modules/base.nix
    ../../modules/web.nix
    ../../modules/nextcloud.nix
    ../../modules/pw23-be.nix
  ];

  # Standortspezifische Werte an alle Module durchreichen. Die Module
  # verwenden `site.domain` statt fester Namen - damit steht die eigene
  # Infrastruktur an genau einer Stelle statt ueber das Repo verteilt.
  # Siehe site.nix, insbesondere den skip-worktree-Hinweis.
  _module.args.site = import ./site.nix;

  # Sicherheitskopfzeilen fuer alles, was diese Maschine selbst ausliefert.
  #
  # Warum geteiltes Argument und nicht einmal im vhost: nginx vererbt
  # add_header NICHT in einen location-Block, der ein eigenes add_header
  # setzt - dort fallen dann ALLE geerbten weg, nicht nur das gleichnamige.
  # Betroffen ist die timeline.json-Location in modules/pw23-be.nix, die
  # Cache-Control setzt. Sie muss den Block deshalb wiederholen.
  #
  # Nextcloud bekommt ihn bewusst NICHT: die Anwendung setzt eigene Kopfzeilen
  # inklusive CSP, und doppelte X-Frame-Options ignorieren manche Browser ganz.
  _module.args.securityHeaders = ''
    add_header Strict-Transport-Security "max-age=31536000; includeSubDomains" always;
    add_header X-Content-Type-Options "nosniff" always;
    add_header X-Frame-Options "SAMEORIGIN" always;
    add_header Referrer-Policy "no-referrer" always;

    # VORERST NUR BEOBACHTEND. Report-Only blockiert nichts, meldet Verstoesse
    # aber in der Browser-Konsole. So laesst sich pruefen, ob die Policy im
    # Alltag haelt, ohne die Seite zu riskieren.
    #
    # Umstellen auf Durchsetzung, sobald die Konsole ueber mehrere Besuche
    # hinweg still bleibt: den Kopfzeilennamen zu
    #   Content-Security-Policy
    # aendern (ohne -Report-Only), Wert unveraendert.
    #
    # Erwartete Kandidaten fuer Meldungen: Inline-Styles, falls doch welche
    # ins HTML gelangen - ProfileInfo.tsx setzt style={{ filter: ... }}.
    add_header Content-Security-Policy-Report-Only "${contentSecurityPolicy}" always;
  '';

  networking.hostName = "versa";

  # Nicht aendern nach der Erstinstallation - legt fest, gegen welche
  # Zustandsformate (Datenbanken etc.) NixOS migriert.
  system.stateVersion = "26.05";
}
