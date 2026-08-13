{ config, pkgs, ... }:
{
  # ==========================================================================
  # Schlank halten
  # Der Nix-Store ist groesser als ein Debian-Paketverzeichnis - aber er
  # waechst nicht unkontrolliert, solange GC und Store-Optimierung laufen.
  # ==========================================================================
  documentation.nixos.enable = false;

  # Info-Seiten abschalten. Zwei Gruende:
  #   1. Auf einem Server braucht sie niemand - spart Platz im Store.
  #   2. documentation.info verlinkt /share/info und laesst install-info einen
  #      Index bauen. Das scheitert in dieser nixpkgs-Revision, weil gzip in
  #      der Build-Umgebung fehlt ("No such file or directory for gzip -d",
  #      ausgeloest von gawknotes.info aus gawk).
  # man-Seiten bleiben aktiv.
  documentation.info.enable = false;
  documentation.doc.enable = false;

  programs.command-not-found.enable = false;

  nix.settings = {
    experimental-features = [ "nix-command" "flakes" ];
    auto-optimise-store = true; # dedupliziert identische Store-Pfade per Hardlink
  };

  nix.gc = {
    automatic = true;
    dates = "weekly";
    options = "--delete-older-than 14d";
  };

  # 1 GB RAM, 1 Kern: Swap als Sicherheitsnetz, nicht als RAM-Ersatz.
  boot.kernel.sysctl."vm.swappiness" = 10;

  # Ablage fuer Zustandswerte, die nicht ins Repo gehoeren: Passwort-Hashes,
  # spaeter .env-Dateien fuer Dienste. Nur die PFADE stehen in der
  # Konfiguration, die Inhalte liegen ausschliesslich hier.
  systemd.tmpfiles.rules = [
    "d /etc/secrets 0700 root root - -"
  ];

  # ==========================================================================
  # Zugang
  # Stand vorher: PermitRootLogin yes + PasswordAuthentication yes,
  # dazu 488.713 Fehlversuche in sechs Wochen. Das ist hier strukturell zu.
  # ==========================================================================
  # Benutzer werden ausschliesslich hier deklariert, nicht auf dem Server.
  #
  # Muss false sein, damit hashedPasswordFile ueberhaupt wirkt: Mit dem
  # Standardwert true setzt NixOS das Passwort nur beim ERSTMALIGEN Anlegen
  # des Benutzers und laesst es danach in Ruhe, damit `passwd` Bestand hat.
  # Bei einem bereits existierenden root wird die Datei dann schlicht
  # ignoriert - `passwd -S root` meldet weiterhin "L".
  #
  # Konsequenz: `passwd` auf dem Server wirkt nur bis zum naechsten
  # nixos-rebuild. Passwort aendern heisst ab jetzt: neuen Hash in
  # /etc/secrets/root-password schreiben und deployen.
  users.mutableUsers = false;

  users.users.root = {
    # ------------------------------------------------------------------
    # Konsolen-Passwort - gilt NUR fuer die Vultr-Webkonsole, nicht fuer SSH.
    #
    # In der Konfiguration steht der PFAD, nie der Hash. Ein inline gesetztes
    # hashedPassword landete im /nix/store, und der ist auf dem Zielsystem
    # weltlesbar (0555) - anders als /etc/shadow mit 0600. Ein Hash laesst
    # sich offline mit einer Grafikkarte durchprobieren, ohne dass der Server
    # etwas davon merkt.
    #
    # Der Inhalt kommt aus secrets/root-password.age. agenix entschluesselt
    # ihn beim Start mit dem SSH-Host-Key nach /run/agenix/root-password:
    # tmpfs, 0400, nie auf der Platte.
    #
    # Aendern:
    #   openssl passwd -6 | tr -d '\n' > /tmp/h
    #   nix run .#agenix -- -e secrets/root-password.age   # Inhalt einfuegen
    #   nixos-rebuild switch ...
    #
    # `passwd` auf dem Server wirkt wegen mutableUsers = false nur bis zum
    # naechsten Deploy.
    # ------------------------------------------------------------------
    hashedPasswordFile = config.age.secrets.root-password.path;

    # Public Keys sind keine Geheimnisse - die duerfen ins Repo.
    #
    # Ein Schluessel pro Host: geht einer verloren, sperrt man gezielt einen
    # Zugang statt aller. Der erste Eintrag stammt noch aus der Zeit, als
    # dieser Host fillya hiess - er bleibt drin, bis der versa-Schluessel
    # nachweislich funktioniert, danach kann er raus.
    openssh.authorizedKeys.keys = [
      "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAICocR5ZZJa9BHdswECjWCA7B6khE7i+/J13jBsxMIhuC tw@fedora -> fillya"
      "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIIiNZ5YB4eSShUPYmrxZZhSdRSC0ZvkludjxZiMgivD4 tw@fedora -> versa"
    ];
  };

  services.openssh = {
    enable = true;
    settings = {
      PermitRootLogin = "prohibit-password";
      PasswordAuthentication = false;
      KbdInteractiveAuthentication = false;
    };
  };

  # Daempft das Log-Rauschen der Botnetze. Nach der Key-Only-Umstellung
  # nur noch Kosmetik, aber billig.
  services.fail2ban.enable = true;

  networking.firewall = {
    enable = true;
    allowedTCPPorts = [ 22 80 443 ];
    # Bewusst NICHT offen: 21 (FTP), 25 (SMTP), 143/993 (IMAP), 873 (rsync).
    # Alle vier liefen auf dem Debian offen im Netz.
  };

  # ==========================================================================
  # Grundausstattung
  # ==========================================================================
  time.timeZone = "Europe/Berlin";
  i18n.defaultLocale = "en_US.UTF-8";

  environment.systemPackages = with pkgs; [
    vim
    git
    curl
    rsync
    htop
    tmux
    fastfetch
  ];

  # Systemuebersicht bei jeder interaktiven Anmeldung.
  #
  # fastfetch statt neofetch: letzteres ist seit 2024 archiviert und nicht
  # mehr gepflegt. fastfetch ist in C geschrieben statt als Bash-Skript und
  # startet in Millisekunden - auf einem einzelnen Kern merkt man das.
  #
  # interactiveShellInit greift nur bei interaktiven Shells. `ssh versa
  # 'befehl'` bleibt also unberuehrt, sonst wuerde die Ausgabe jedes
  # Skript stoeren, das den Server per SSH abfragt.
  programs.bash.interactiveShellInit = ''
    ${pkgs.fastfetch}/bin/fastfetch
  '';

  # ==========================================================================
  # Bewusst NICHT uebernommen
  # Lag auf dem Debian in /usr/local (1,4 GB, per pip an der Paketverwaltung
  # vorbei) bzw. als Altlast in den Systempaketen. Bei Bedarf einkommentieren -
  # deklarativ statt per pip install.
  # ==========================================================================
  # environment.systemPackages = with pkgs; [
  #   python3
  #   python3Packages.jupyter
  #   python3Packages.tensorflow
  #   nodejs_22
  #   gcc
  # ];
}
