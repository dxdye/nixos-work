{ modulesPath, ... }:
{
  imports = [ (modulesPath + "/profiles/qemu-guest.nix") ];

  nixpkgs.hostPlatform = "x86_64-linux";

  # --------------------------------------------------------------------------
  # Boot - Legacy BIOS mit GRUB
  #
  # Vultr bootet diese Instanz im BIOS-Modus, nicht per UEFI. Auf der Maschine
  # verifiziert mit:  [ -d /sys/firmware/efi ] && echo UEFI || echo BIOS
  #
  # Der erste Installationsversuch lief auf systemd-boot: Die Installation ging
  # sauber durch, aber die Firmware konnte die EFI-Dateien nicht lesen und die
  # Maschine fiel auf die Installer-ISO zurueck. GRUB schreibt stattdessen in
  # den MBR von /dev/vda und nutzt die EF02-Partition aus disko.nix.
  #
  # ⚠ Bei einer kuenftigen Instanz vorher pruefen. Meldet sie UEFI, hier auf
  #   systemd-boot zurueckstellen UND in disko.nix die ESP aktivieren.
  # --------------------------------------------------------------------------
  boot.loader.grub = {
    enable = true;
    configurationLimit = 5; # nur 5 Generationen im Bootmenue -> spart Platz

    # KEIN `device = "/dev/vda"` hier!
    # disko traegt das Geraet selbst in boot.loader.grub.devices ein, sobald es
    # die EF02-Partition sieht. Beides zusammen ergibt denselben Eintrag zweimal
    # und die Auswertung bricht ab mit:
    #   "You cannot have duplicated devices in mirroredBoots"
  };

  boot.initrd.availableKernelModules = [
    "ata_piix" "uhci_hcd" "virtio_pci" "virtio_scsi" "sd_mod" "sr_mod"
  ];

  # --------------------------------------------------------------------------
  # Dateisysteme und Swap kommen aus disko.nix - hier bewusst NICHTS.
  # Doppelte Definitionen wuerden kollidieren.
  #
  # Block Storage: derzeit nicht im Einsatz. Verfuegbarkeit haengt an der
  # Region und steht in der API, nicht auf einer statischen Seite:
  #   curl -s https://api.vultr.com/v2/regions | grep -B2 -A8 '"ams"'
  # Relevante Flags: block_storage_high_perf (NVMe), block_storage_storage_opt (HDD)
  #
  # Falls ein Volume dazukommt - "nofail" ist Pflicht, sonst haengt der Boot,
  # wenn das Volume nicht angehaengt ist:
  #
  # fileSystems."/mnt/data" = {
  #   device = "/dev/disk/by-uuid/UUID-VON-blkid";
  #   fsType = "ext4";
  #   options = [ "nofail" "noatime" ];
  # };
  # --------------------------------------------------------------------------

  # --------------------------------------------------------------------------
  # Netzwerk
  #
  # Bewusst DHCP statt statischer Adressen: Vultr vergibt IPv4 per DHCP und
  # IPv6 per Router Advertisement. Das ist fehlertoleranter - ein Tippfehler in
  # einer statischen Adresse waere nach der Installation nicht mehr korrigierbar,
  # ohne ueber die Webkonsole zu gehen.
  #
  # Adressen bewusst nicht dokumentiert - sie kommen ohnehin per DHCP und
  # gehoeren nicht in ein oeffentliches Repo. Ablesen auf der Maschine mit:
  #   ip -br a ; ip route | grep default
  # --------------------------------------------------------------------------
  networking = {
    useDHCP = false;
    interfaces.ens3 = {
      useDHCP = true;

      # KEINE statische Route zum Vultr-Metadatendienst (169.254.169.254).
      #
      # Die hatte ich aus dem Debian uebernommen. Zwei Gruende, warum sie weg ist:
      #   1. Vultrs DHCP liefert sie selbst mit - sichtbar an "proto dhcp" in
      #      `ip route`. Die statische Definition war schlicht doppelt.
      #   2. Sie lief, bevor das Interface seine DHCP-Adresse hatte, und
      #      scheiterte mit "Nexthop has invalid gateway" - was
      #      network-addresses-ens3.service bei jedem Boot fehlschlagen liess.
      #
      # Gebraucht wird der Metadatendienst hier ohnehin nicht: den nutzen
      # cloud-init und der Vultr-Agent, beides laeuft auf diesem System nicht.

      # IPv6 kommt per Router Advertisement. Falls das nicht greift,
      # hier die Adresse der neuen Instanz statisch setzen:
      # ipv6.addresses = [ { address = "..."; prefixLength = 64; } ];
    };

    # Falls IPv6 statisch gesetzt werden muss, zusaetzlich:
    # defaultGateway6 = { address = "fe80::..."; interface = "ens3"; };

    nameservers = [ "108.61.10.10" "2001:19f0:300:1704::6" ];
  };
}
