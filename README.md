# versa — NixOS-Konfiguration

Deklarative Konfiguration eines kleinen Webservers. Ersetzt ein über Jahre
gewachsenes Debian 11, auf dem sechs PHP-Versionen, ein nginx aus Debian 10
und ein von Hand gestarteter Webserver-Prozess koexistierten.

```
versa    Vultr VC2, Amsterdam
         1 vCPU · 1 GB RAM · 25 GB
         NixOS 26.05, BIOS-Boot mit GRUB
```

Die Begruendungen fuer die einzelnen Entscheidungen stehen als Kommentare in
den Modulen — insbesondere dort, wo eine naheliegende Loesung nicht
funktioniert hat.

## Struktur

```
flake.nix                  nixpkgs 26.05 und disko gepinnt
hosts/versa/default.nix    Zusammenbau
hosts/versa/disko.nix      Partitionierung: GPT, EF02, Swap, ext4
hosts/versa/hardware.nix   Boot, Netzwerk
modules/base.nix           schlank halten, SSH, Firewall, Zugang
modules/web.nix            nginx + ACME, statische Website
modules/nextcloud.nix      Nextcloud inkl. App-Store-Apps
modules/containers.nix     Deno + Elixir (noch inaktiv)
```

## Installation auf frischer Hardware

Kein `nixos-infect`, sondern eine echte Neuinstallation mit deklarierter
Partitionierung:

1. Instanz anlegen, **NixOS-Minimal-ISO** als Boot-Medium waehlen
2. In der Konsole drei Befehle:
   ```
   sudo -i
   passwd                    # temporaer, nur fuer die Installation
   systemctl start sshd
   ```
3. Vom Arbeitsrechner:
   ```fish
   # Geheimnisse vorbereiten, die schon beim ersten Boot da sein muessen
   set tmp (mktemp -d)
   install -d -m 700 $tmp/etc/secrets
   mkpasswd -m sha-512 > $tmp/etc/secrets/root-password
   chmod 600 $tmp/etc/secrets/root-password

   nix run github:nix-community/nixos-anywhere -- \
     --flake .#versa \
     --extra-files $tmp \
     root@ZIEL_IP

   rm -rf $tmp
   ```

`--extra-files` uebernimmt die Verzeichnisstruktur 1:1 ins Zielsystem, mit
Rechten. Ohne das zeigt `hashedPasswordFile` beim ersten Boot ins Leere: root
haette kein Passwort, die Webkonsole waere unbrauchbar - und wenn dann auch
noch das Netzwerk klemmt, kommt man gar nicht mehr rein.

Dieselbe Option dient spaeter dazu, agenix zu bootstrappen: Der SSH-Host-Key
muss vorhanden sein, bevor agenix beim ersten Boot entschluesseln kann.
Verwandt: `--copy-host-keys` uebernimmt bestehende `/etc/ssh/ssh_host_*`.

`nixos-anywhere` erkennt an `VARIANT=installer` in `/etc/os-release`, dass die
Maschine bereits im NixOS-Installer laeuft, und ueberspringt die kexec-Phase.
Das ist hier entscheidend: kexec braucht ~1,5 GB RAM, die Maschine hat 1 GB.

**Vorher pruefen**, sonst installiert man einen Bootloader, den die Firmware
nicht lesen kann:

```bash
[ -d /sys/firmware/efi ] && echo UEFI || echo BIOS
```

Diese Instanz meldet BIOS. `disko.nix` und `hardware.nix` enthalten beide
Varianten, die jeweils andere ist auskommentiert.

## Bauen

```fish
cd ~/Programme/nixos-work
nix flake check
nix build .#nixosConfigurations.versa.config.system.build.toplevel
```

Gebaut wird immer auf dem Arbeitsrechner. Der Server hat mit 1 GB RAM zu wenig
Speicher, um nixpkgs zu evaluieren — der Nix-Evaluator braucht dafuer
erfahrungsgemaess 1,5 bis 2,5 GB, und Swap hilft dabei kaum, weil der Zugriff
ueber den gesamten Heap streut.

Nebeneffekt: Konfigurationsfehler fallen lokal auf, bevor der Server sie sieht.

## Ausrollen

```fish
eval (ssh-agent -c); ssh-add ~/.ssh/id_ed25519_fillya

nix run nixpkgs#nixos-rebuild -- switch \
  --flake .#versa \
  --target-host versa \
  --use-substitutes
```

**`--use-substitutes` ist wichtig.** Ohne die Option schiebt nixos-rebuild die
komplette Closure vom Arbeitsrechner zum Server — bei einem Nextcloud-Update
mehrere hundert Megabyte durch den heimischen Upload. Mit der Option holt sich
der Server fehlende Pfade direkt aus `cache.nixos.org` und bekommt nur noch
das, was es dort nicht gibt: generierte `/etc`-Dateien, systemd-Units,
Aktivierungsskript.

Geht etwas schief: im GRUB-Menue die vorige Generation waehlen.
`configurationLimit = 5` haelt fuenf davon vor.

## Geheimnisse

Dieses Repo ist fuer Veroeffentlichung vorgesehen. **Nichts Geheimes wird
committet** — aus zwei Gruenden:

1. Git-Historie ist dauerhaft. Was einmal drin ist, bleibt drin, auch nach
   einem spaeteren `rm`.
2. Alles, was in einem Nix-Ausdruck steht, landet im `/nix/store`, und der ist
   auf dem Zielsystem **weltlesbar** (`0555`). Ein inline gesetztes
   `hashedPassword` waere dort im Aktivierungsskript nachlesbar — anders als
   `/etc/shadow` mit `0600`.

Public Keys sind keine Geheimnisse und duerfen ins Repo.

### agenix

Geheimnisse liegen **verschluesselt im Repo** als `secrets/*.age`. Das ist
Ciphertext und darf oeffentlich sein.

```
secrets.nix                    wer darf was entschluesseln (nur fuer das CLI)
secrets/root-password.age      sha-512-Hash fuer die Webkonsole
secrets/nextcloud-admin.age    Nextcloud-Adminpasswort
modules/secrets.nix            bindet sie in die NixOS-Konfiguration ein
```

Zwei Empfaenger duerfen entschluesseln: der **persoenliche Schluessel** (damit
man die Werte bearbeiten kann) und der **SSH-Host-Key der Maschine** (damit sie
beim Start selbst entschluesselt, ohne Eingabe).

Entschluesselt wird zur Aktivierungszeit nach `/run/agenix/<name>` — tmpfs,
`0400`, nie auf der Platte, nie im `/nix/store`. In der Konfiguration steht nur
`config.age.secrets.<name>.path`.

Bearbeiten:

```fish
nix run .#agenix -- -e secrets/root-password.age
```

Neuen Empfaenger aufnehmen: in `secrets.nix` eintragen, dann `nix run .#agenix -- -r`
(verschluesselt alle betroffenen Dateien neu).

⚠️ **Der Host-Key ist der Generalschluessel.** Er gehoert gesichert, an einem
Ort, der nicht diese Maschine ist — sonst sind die `.age`-Dateien im Ernstfall
unbrauchbar. Dasselbe gilt fuer den persoenlichen Schluessel.

Nicht ueber agenix laeuft `/var/lib/nextcloud/config/config.php` mit
`instanceid`, `secret` und `passwordsalt`: Die erzeugt Nextcloud selbst beim
Installieren, sie sind Zustand und gehoeren nicht ins Repo.

### Standortspezifische Werte: `hosts/versa/site.nix`

Domains, Hostnamen und die ACME-Kontaktadresse stehen gesammelt in
`hosts/versa/site.nix`. Wer das Repo als Vorlage nimmt, aendert genau diese
Datei und sonst nichts.

Diese Werte sind **keine Geheimnisse** — sie stehen im DNS, im Zertifikat und
in jeder HTTP-Antwort, und sie muessen ohnehin im Store landen, damit nginx
weiss, welche Namen es bedient. Sie duerfen ins Repo.

### Laufzeitwerte von Diensten: `.env`

Fuer alles, was ein Dienst beim Start liest — API-Schluessel, Zugangsdaten —
ist eine klassische `.env` genau richtig. systemd liest sie zur Laufzeit, sie
gelangt nie in den Store und nie ins Repo:

```nix
systemd.services.meindienst.serviceConfig.EnvironmentFile =
  "/etc/secrets/meindienst.env";
```

Nicht moeglich ist das fuer Werte, die Nix zur **Auswertungszeit** braucht:
Flakes sehen ausschliesslich git-verfolgte Dateien, eine gitignorierte `.env`
existiert fuer `nix build` schlicht nicht. Und `builtins.getEnv` braeuchte
`--impure` und wuerde die Reproduzierbarkeit aufgeben.

## Was bewusst nicht mitkommt

Aus dem alten Debian: Asterisk, Apache2, vsftpd (Klartext-FTP auf Port 21),
rsync-Daemon, dovecot, postfix, PHP 7.3/7.4/8.2/8.4/8.5, Reste aus Debian 10
(gcc-8, python2, python3.7, perl-5.28) sowie `/usr/local` mit 1,4 GB
pip-Installationen an der Paketverwaltung vorbei.

Die Website selbst ist ein statischer Vite-Build von 14 MB — kein PHP noetig.
Auf dem alten Server lief trotzdem ein `php8.1-fpm` dafuer.

## Offene Punkte

- [ ] `agenix` einrichten, Geheimnisse verschluesselt ins Repo
- [ ] `PermitRootLogin = "no"` plus normaler Benutzer mit sudo
- [ ] `modules/containers.nix` aktivieren: Deno auf :8000, Elixir schreibt
      eine JSON-Datei, die nginx statisch ausliefert
- [ ] Mailserver via `simple-nixos-mailserver` — setzt voraus, dass Vultr
      Port 25 freigibt und rDNS gesetzt ist
- [ ] `richdocuments` und `quota_warning` gibt es nicht als nixpkgs-Ableitung,
      die kommen per App-Store nach `/var/lib/nextcloud/store-apps`
