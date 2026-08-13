{ ... }:
{
  # ==========================================================================
  # Partitionierung, deklarativ
  #
  # Ersetzt das geerbte Layout des alten Debian. Damit steht auch die
  # Plattenaufteilung im Repo und ist reproduzierbar - `nixos-anywhere`
  # partitioniert danach, formatiert und installiert in einem Durchgang.
  #
  # ⚠ VOR dem Ausrollen auf der Zielmaschine pruefen:
  #     [ -d /sys/firmware/efi ] && echo UEFI || echo BIOS
  #   Das alte Paris-System war BIOS (grub-pc). Passt die Variante hier nicht
  #   zur Firmware, laeuft die Installation durch und die Maschine bootet
  #   trotzdem nicht. Auf einer frischen Instanz ist das billig zu korrigieren,
  #   aber pruefen ist billiger.
  # ==========================================================================
  disko.devices.disk.main = {
    device = "/dev/vda";
    type = "disk";
    content = {
      type = "gpt";
      partitions = {

        # --- BIOS-Variante (aktiv) ---
        # Vultr bootet diese Instanz im Legacy-BIOS-Modus. Verifiziert auf der
        # Maschine mit:  [ -d /sys/firmware/efi ] && echo UEFI || echo BIOS
        #
        # Der erste Versuch lief auf UEFI mit systemd-boot: Die Installation
        # ging durch, aber die Firmware konnte die EFI-Dateien nicht lesen und
        # fiel auf die ISO zurueck. Daher hier eine BIOS-Boot-Partition.
        #
        # Die 1 MB sind kein Dateisystem, sondern reiner Ablageplatz fuer GRUBs
        # core.img - auf GPT fehlt sonst der Bereich hinter dem MBR, den GRUB
        # bei MBR-Platten benutzt. /boot liegt spaeter einfach auf "/".
        boot = {
          priority = 1;
          size = "1M";
          type = "EF02";
        };

        # --- UEFI-Variante: falls eine kuenftige Instanz UEFI meldet, die
        #     boot-Partition oben auskommentieren und stattdessen das hier
        #     aktivieren. Zusaetzlich in hardware.nix auf systemd-boot zurueck.
        # ESP = {
        #   priority = 1;
        #   name = "ESP";
        #   size = "512M";
        #   type = "EF00";
        #   content = {
        #     type = "filesystem";
        #     format = "vfat";
        #     mountpoint = "/boot";
        #     mountOptions = [ "umask=0077" ];
        #   };
        # };

        # Echte Swap-Partition statt Swapfile: sauberer, und der Installer
        # kann sie schon waehrend der Installation nutzen - auf 1 GB RAM
        # kann das den Unterschied machen.
        swap = {
          priority = 2;
          size = "2G";
          content = {
            type = "swap";
            discardPolicy = "both";
          };
        };

        root = {
          priority = 3;
          size = "100%";
          content = {
            type = "filesystem";
            format = "ext4";
            mountpoint = "/";
          };
        };
      };
    };
  };
}
