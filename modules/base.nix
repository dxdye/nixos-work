{ pkgs, ... }:
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
  users.users.root = {
    # ------------------------------------------------------------------
    # Konsolen-Passwort - gilt NUR fuer die Vultr-Webkonsole, nicht fuer SSH.
    #
    # Hier steht bewusst KEIN Hash. Zwei Gruende:
    #   1. Dieses Repo soll oeffentlich werden. Was einmal committet ist,
    #      bleibt in der Git-Historie - auch wenn man es spaeter loescht.
    #   2. Alles, was in einem Nix-Ausdruck steht, landet im /nix/store,
    #      und der ist auf dem Zielsystem weltlesbar (0555). Ein inline
    #      gesetztes hashedPassword waere dort im Aktivierungsskript
    #      nachlesbar - anders als /etc/shadow mit 0600.
    #
    # Ist-Zustand: Das Passwort wurde nach der Installation per `passwd`
    # direkt auf dem Server gesetzt. Es liegt damit nur in /etc/shadow (0600),
    # nicht im Store und nicht im Repo. Weil users.mutableUsers auf true steht
    # (Standard), ueberlebt es jeden nixos-rebuild.
    #
    # Nachteil: nicht reproduzierbar - beim Neuaufsetzen muss es von Hand
    # gesetzt werden. Falls doch einmal ein Hash mitgegeben werden muss,
    # etwa weil die Maschine ohne funktionierendes SSH hochkommt:
    #   1. mkpasswd -m sha-512
    #   2. Zeile unten einkommentieren, Hash eintragen
    #   3. NICHT committen. `nix build` beruecksichtigt Aenderungen an
    #      bereits verfolgten Dateien auch ohne Commit ("Git tree is dirty").
    #   4. Nach dem Deploy:  git checkout modules/base.nix
    #
    # Langfristig agenix oder sops-nix - dann liegt das Geheimnis
    # verschluesselt im Repo und nur der Zielhost kann es entschluesseln.
    # ------------------------------------------------------------------
    # Im Repo steht der PFAD, nicht der Inhalt. Die Datei enthaelt genau eine
    # Zeile - den sha-512-crypt-Hash - und liegt mit 0600 auf dem Server.
    #
    # Anlegen (einmalig, aus dem bestehenden /etc/shadow uebernommen):
    #   awk -F: '$1=="root"{print $2}' /etc/shadow > /etc/secrets/root-password
    #   chmod 600 /etc/secrets/root-password
    # Oder neu erzeugen:  mkpasswd -m sha-512 > /etc/secrets/root-password
    #
    # Achtung: Ab jetzt verwaltet NixOS das Passwort. Ein spaeteres `passwd`
    # wird beim naechsten nixos-rebuild wieder ueberschrieben - Aenderungen
    # gehoeren in diese Datei.
    hashedPasswordFile = "/etc/secrets/root-password";

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
  ];

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
