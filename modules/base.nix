{ pkgs, ... }:
{
  # ==========================================================================
  # Schlank halten
  # Der Nix-Store ist groesser als ein Debian-Paketverzeichnis - aber er
  # waechst nicht unkontrolliert, solange GC und Store-Optimierung laufen.
  # ==========================================================================
  documentation.nixos.enable = false;
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

  # ==========================================================================
  # Zugang
  # Stand vorher: PermitRootLogin yes + PasswordAuthentication yes,
  # dazu 488.713 Fehlversuche in sechs Wochen. Das ist hier strukturell zu.
  # ==========================================================================
  users.users.root = {
    # Erzeugen mit:  mkpasswd -m sha-512
    # Gilt NUR fuer die Vultr-Webkonsole, nicht fuer SSH.
    # Ohne diesen Hash laesst nixos-infect root ohne Passwort zurueck -
    # dann waere die Konsole als Rueckfalllinie wertlos.
    hashedPassword = "$6$PLATZHALTER_PASSWORT_HASH";

    # Inhalt von ~/.ssh/id_ed25519_fillya.pub
    openssh.authorizedKeys.keys = [
      "ssh-ed25519 AAAA_PLATZHALTER_PUBLIC_KEY tw@fedora -> fillya"
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
