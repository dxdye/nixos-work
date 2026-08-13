# NixOS-Serverkonfiguration

Statische Website, Nextcloud, eine Deno-API und ein Elixir-Dienst, der eine
JSON-Datei materialisiert. Ausgelegt auf eine kleine Maschine – ein Kern,
wenig Speicher.

## Struktur

```
flake.nix                  nixpkgs 26.05, disko, agenix, Anwendungscode
hosts/versa/site.nix       Domains und Kontaktadresse – hier anfangen
hosts/versa/disko.nix      Partitionierung
hosts/versa/hardware.nix   Boot, Netzwerk
modules/base.nix           SSH, Firewall, Zugang
modules/web.nix            nginx, ACME
modules/nextcloud.nix      Nextcloud
modules/pw23-be.nix        Deno-API und Elixir-Poller
modules/secrets.nix        agenix
```

Wer das Repo als Vorlage nimmt, ändert `hosts/versa/site.nix` und die
Public Keys in `modules/base.nix`.

## Bauen und ausrollen

```fish
nix build .#nixosConfigurations.versa.config.system.build.toplevel

nix run nixpkgs#nixos-rebuild -- switch \
  --flake .#versa --target-host versa --use-substitutes
```

Gebaut wird auf dem Arbeitsrechner – die Zielmaschine hat zu wenig Speicher,
um nixpkgs zu evaluieren. `--use-substitutes` lässt sie fehlende Pfade selbst
aus dem Binärcache holen, statt sie über die heimische Leitung zu schieben.

Geht etwas schief: im GRUB-Menü die vorige Generation wählen.

## Neuinstallation

```fish
# Geheimnisse, die schon beim ersten Boot da sein müssen
set tmp (mktemp -d)
install -d -m 700 $tmp/etc/ssh
cp /pfad/zum/ssh_host_ed25519_key $tmp/etc/ssh/
chmod 600 $tmp/etc/ssh/ssh_host_ed25519_key

nix run github:nix-community/nixos-anywhere -- \
  --flake .#versa --extra-files $tmp root@ZIEL_IP
```

Der Host-Key muss vorher liegen, sonst kann agenix beim ersten Boot nichts
entschlüsseln.

Vorher prüfen, sonst bootet die Maschine nicht:

```bash
[ -d /sys/firmware/efi ] && echo UEFI || echo BIOS
```

`disko.nix` und `hardware.nix` enthalten beide Varianten, die jeweils andere
ist auskommentiert.

## Geheimnisse

`secrets/*.age` sind verschlüsselt und dürfen öffentlich sein. Entschlüsselt
wird beim Start mit dem SSH-Host-Key nach `/run/agenix/` – tmpfs, `0400`.

```fish
nix run .#agenix -- -e secrets/root-password.age
```

**Der Host-Key und der persönliche Schlüssel gehören gesichert**, an einen
Ort, der nicht der Server ist. Ohne sie sind die `.age`-Dateien unbrauchbar.

Nicht über agenix läuft `/etc/secrets/timemachine.env` – die wird beim
Neuaufsetzen von Hand angelegt.

