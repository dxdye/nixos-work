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

        # --- UEFI-Variante (aktiv) ---
        ESP = {
          priority = 1;
          name = "ESP";
          size = "512M";
          type = "EF00";
          content = {
            type = "filesystem";
            format = "vfat";
            mountpoint = "/boot";
            mountOptions = [ "umask=0077" ];
          };
        };

        # --- BIOS-Variante: falls /sys/firmware/efi FEHLT, ESP oben
        #     auskommentieren und stattdessen das hier aktivieren.
        #     Zusaetzlich in hardware.nix auf GRUB umstellen.
        # boot = {
        #   priority = 1;
        #   size = "1M";
        #   type = "EF02";   # BIOS boot partition, damit GRUB auf GPT passt
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
