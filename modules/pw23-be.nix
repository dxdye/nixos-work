{ config, pkgs, lib, inputs, site, ... }:

let
  src = inputs.pw23-be;

  # Datenverzeichnisse. StateDirectory legt sie an und setzt die Rechte -
  # deshalb hier nur die Pfade, keine tmpfiles-Regeln.
  denoState = "/var/lib/pw23-be";
  elixirState = "/var/lib/timemachine";

  # Die materialisierte Timeline landet direkt im Webroot, damit nginx sie
  # ohne Umweg ueber einen Dienst ausliefert. Genau dafuer hat der Elixir-Teil
  # keinen HTTP-Port - siehe den Kommentar in timemachine/mix.exs.
  timelinePath = "/var/www/${site.domain}/html/timeline.json";

  # Elixir-Release. mixRelease erzeugt ein eigenstaendiges Paket mit
  # mitgeliefertem BEAM - auf dem Zielsystem wird kein Elixir gebraucht.
  timemachine = pkgs.beamPackages.mixRelease {
    pname = "timemachine";
    version = "0.1.0";
    src = "${src}/timemachine";

    # Hash ueber die geholten Hex-Abhaengigkeiten. Aendert sich mix.lock,
    # aendert sich dieser Wert - Nix meldet dann den neuen ("got: sha256-...")
    # und er wird hier ersetzt.
    mixFodDeps = pkgs.beamPackages.fetchMixDeps {
      pname = "timemachine-deps";
      version = "0.1.0";
      src = "${src}/timemachine";
      hash = "sha256-6J6V01x5DxK/gBCrytbMEfH8zmqDEzhlhZ+zGr/1+9c=";
    };

    # exqlite baut einen nativen SQLite-NIF ueber elixir_make. Zwei Dinge
    # stehen dem im Nix-Sandkasten entgegen:
    #
    #   1. elixir_make legt einen Cache unter $HOME an. Im Sandkasten zeigt
    #      HOME auf /homeless-shelter - einen Pfad, den es absichtlich nicht
    #      gibt, damit Builds nicht heimlich ins Benutzerverzeichnis schreiben.
    #      Ein beschreibbares Verzeichnis genuegt.
    #
    #   2. Standardmaessig laedt elixir_make ein VORKOMPILIERTES NIF aus dem
    #      Netz. Der Sandkasten hat keinen Netzzugang - und das waere auch
    #      unerwuenscht, weil ein heruntergeladenes Binaerpaket die
    #      Reproduzierbarkeit unterlaufen wuerde. FORCE_BUILD laesst exqlite
    #      stattdessen aus der mitgelieferten C-Quelle bauen.
    #
    # preConfigure, nicht preBuild: mixRelease ruft `mix deps.compile` in der
    # configurePhase auf, der Fehler passiert also eine Phase vor dem Bauen.
    preConfigure = ''
      export HOME=$(mktemp -d)
    '';

    env.EXQLITE_FORCE_BUILD = "true";
  };
in
{
  # ==========================================================================
  # Zwei Dienste, zwei Rollen:
  #
  #   pw23-be      Deno, lauscht auf 127.0.0.1:8000, liefert gecachte
  #                GitHub-Daten. nginx reicht /api/ dorthin weiter.
  #
  #   timemachine  Elixir, KEIN HTTP-Port. Pollt GitHub und schreibt eine
  #                timeline.json in den Webroot, die nginx statisch ausliefert.
  #
  # Beide lesen ihre Konfiguration zur Laufzeit aus der Umgebung.
  #
  # BEWUSST OHNE GITHUB_TOKEN. Damit gilt das Rate-Limit fuer nicht
  # authentifizierte Zugriffe: 60 Anfragen pro Stunde und IP statt 5000.
  # Die Rechnung geht auf, weil
  #   - Denos Auffrischintervall auf 15 Minuten steht: 2 Konten * 4 = 8/Stunde
  #   - timemachine ETags nutzt und GitHub mit 304 antwortet, sobald sich
  #     nichts geaendert hat - 304er zaehlen nicht gegen das Limit
  #
  # Der ERSTE Lauf von timemachine ist der Engpass: eine Anfrage pro Konto
  # plus eine pro Repository. Bei vielen Repos laeuft er ins Limit, bricht ab
  # und holt beim naechsten stuendlichen Lauf nach - die ETags sorgen dafuer,
  # dass bereits Geholtes nicht erneut zaehlt.
  #
  # Ohne Token gibt es hier auch kein Geheimnis: Kontonamen und Commit-Mails
  # stehen ohnehin oeffentlich in jeder Commit-Historie. Die Konfiguration
  # steht deshalb vollstaendig in site.nix, kein EnvironmentFile noetig.
  # ==========================================================================

  # --------------------------------------------------------------------------
  # Deno-API
  # --------------------------------------------------------------------------
  systemd.services.pw23-be = {
    description = "pw23-BE: GitHub-Cache-API (Deno)";
    after = [ "network-online.target" ];
    wants = [ "network-online.target" ];
    wantedBy = [ "multi-user.target" ];

    environment = {
      PORT = "8000";
      CACHE_DB_PATH = "${denoState}/cache.db";
      GITHUB_ACCOUNTS = lib.concatStringsSep "," site.githubAccounts;

      # 15 Minuten statt der vorgegebenen 5. Bei zwei Konten sind das
      # 8 Anfragen/Stunde - siehe die Rate-Limit-Rechnung oben.
      CACHE_REFRESH_INTERVAL_MS = toString (15 * 60 * 1000);

      # Nur die eigene Website darf die API im Browser aufrufen.
      CORS_ORIGINS = "https://${site.domain},https://www.${site.domain}";

      # Deno laedt seine Module beim ersten Start hierher. Bewusst NICHT als
      # Nix-Ableitung vorgebaut: Das waere eine fixed-output derivation ueber
      # das DENO_DIR, und dessen Inhalt ist zwischen Deno-Versionen nicht
      # stabil. Die Integritaet sichert stattdessen deno.lock ab - die
      # Modulversionen und ihre Hashes stehen dort fest.
      DENO_DIR = "${denoState}/deno-cache";
    };

    serviceConfig = {
      Type = "simple";
      Restart = "always";
      RestartSec = "10s";

      DynamicUser = true;
      StateDirectory = "pw23-be";
      WorkingDirectory = src;

      # Rechte wie im Dockerfile: nur Netz, Umgebung, Lesen des Quellcodes
      # und Schreiben ausschliesslich im Zustandsverzeichnis.
      ExecStart = lib.concatStringsSep " " [
        "${pkgs.deno}/bin/deno run"
        "--allow-net"
        "--allow-env"
        "--allow-read=${src},${denoState}"
        "--allow-write=${denoState}"
        "${src}/src/main.ts"
      ];

      # Absicherung. Der Dienst braucht nichts davon.
      NoNewPrivileges = true;
      PrivateTmp = true;
      PrivateDevices = true;
      ProtectSystem = "strict";
      ProtectHome = true;
      ProtectKernelTunables = true;
      ProtectKernelModules = true;
      ProtectControlGroups = true;
      RestrictAddressFamilies = [ "AF_INET" "AF_INET6" ];
      RestrictNamespaces = true;
      LockPersonality = true;
      MemoryMax = "256M";
    };
  };

  # --------------------------------------------------------------------------
  # Elixir-Poller
  # --------------------------------------------------------------------------
  systemd.services.timemachine = {
    description = "timemachine: GitHub-Poller, schreibt timeline.json (Elixir)";
    after = [ "network-online.target" ];
    wants = [ "network-online.target" ];
    wantedBy = [ "multi-user.target" ];

    environment = {
      DATABASE_PATH = "${elixirState}/timemachine.db";
      TIMELINE_PATH = timelinePath;
      POLL_INTERVAL_MS = toString (60 * 60 * 1000); # stuendlich
      GITHUB_ACCOUNTS = lib.concatStringsSep "," site.githubAccounts;
      GITHUB_EMAILS = lib.concatStringsSep "," site.githubEmails;
      START_POLLER = "true";

      # Elixir-Releases lesen beim Start einen "Cookie" aus
      # releases/COOKIE - das gemeinsame Geheimnis fuer die Erlang-Verteilung
      # zwischen Knoten. nixpkgs' mixRelease legt diese Datei NICHT an, weil
      # ihr Inhalt zufaellig waere und den Build nicht-reproduzierbar machte.
      # Ohne sie bricht der Start ab mit:
      #   cat: .../releases/COOKIE: No such file or directory
      #
      # Hier gibt es keine Verteilung. RELEASE_DISTRIBUTION=none oeffnet gar
      # keinen Verteilungs-Port, der Cookie ist damit bedeutungslos - ein
      # fester Wert genuegt und ist kein Geheimnis.
      RELEASE_DISTRIBUTION = "none";
      RELEASE_COOKIE = "timemachine-standalone";

      # Das Release schreibt Laufzeitdateien nach $RELEASE_ROOT/tmp - und
      # RELEASE_ROOT liegt im schreibgeschuetzten /nix/store.
      RELEASE_TMP = elixirState;
    };

    serviceConfig = {
      Type = "simple";
      Restart = "always";
      RestartSec = "30s";

      # Kein DynamicUser: der Dienst schreibt in den Webroot, und der gehoert
      # nginx. Ein fester Benutzer in der nginx-Gruppe ist hier ehrlicher als
      # ein wechselnder mit Sonderrechten.
      User = "timemachine";
      Group = "nginx";
      StateDirectory = "timemachine";
      UMask = "0022"; # nginx muss die timeline.json lesen koennen

      ExecStart = "${timemachine}/bin/timemachine start";
      ExecStop = "${timemachine}/bin/timemachine stop";

      NoNewPrivileges = true;
      PrivateTmp = true;
      PrivateDevices = true;
      ProtectHome = true;
      RestrictAddressFamilies = [ "AF_INET" "AF_INET6" "AF_UNIX" ];
      MemoryMax = "256M";

      # Schreibt ausschliesslich in sein Zustandsverzeichnis und die eine
      # JSON-Datei im Webroot.
      ProtectSystem = "strict";
      ReadWritePaths = [ "/var/www/${site.domain}/html" ];
    };
  };

  users.users.timemachine = {
    isSystemUser = true;
    group = "nginx";
    description = "timemachine GitHub-Poller";
  };

  # --------------------------------------------------------------------------
  # nginx: /api/ weiterreichen
  #
  # Der abschliessende Schraegstrich im proxyPass entfernt das /api-Praefix:
  # aus /api/github/dxdye/repos wird beim Dienst /github/dxdye/repos - passend
  # zu den Routen in src/app.ts.
  #
  # Port 8000 ist NICHT in der Firewall freigegeben. Der Dienst ist
  # ausschliesslich ueber nginx erreichbar.
  # --------------------------------------------------------------------------
  services.nginx.virtualHosts.${site.domain}.locations."/api/" = {
    proxyPass = "http://127.0.0.1:8000/";
    proxyWebsockets = true;
  };
}
