{ modulesPath, ... }:
{
  imports = [ (modulesPath + "/profiles/qemu-guest.nix") ];

  nixpkgs.hostPlatform = "x86_64-linux";

  # --------------------------------------------------------------------------
  # Boot - UEFI mit systemd-boot
  #
  # Die alte Paris-Instanz bootete noch per BIOS (grub-pc installiert,
  # grub-efi-amd64 nur als Konfigurationsleiche). Die neue Instanz wird auf
  # UEFI aufgesetzt, deshalb systemd-boot statt GRUB - weniger beweglich,
  # kein separates Installieren in den MBR.
  #
  # ⚠ Auf der Zielmaschine pruefen, BEVOR nixos-anywhere laeuft:
  #     [ -d /sys/firmware/efi ] && echo UEFI || echo BIOS
  #   Meldet sie BIOS, hier auf GRUB umstellen UND in disko.nix die
  #   EF02-Partition aktivieren:
  #     boot.loader.grub = { enable = true; device = "/dev/vda";
  #                          configurationLimit = 5; };
  # --------------------------------------------------------------------------
  boot.loader = {
    systemd-boot = {
      enable = true;
      configurationLimit = 5; # nur 5 Generationen im Bootmenue -> spart Platz
    };
    efi.canTouchEfiVariables = true;
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
  # Werte der ALTEN Instanz (Paris), zur Referenz:
  #   ens3   104.238.190.14/23          Gateway 104.238.190.1
  #          2001:19f0:6801:36:5400:3ff:fe27:393e/64   (SLAAC)
  #   ens9   vorhanden, aber DOWN (Vultr Private Network, ungenutzt)
  #
  # ⚠ Nach dem Anlegen der neuen Instanz anzupassen:
  #     - Interface-Name pruefen:  ip -br a
  #     - Gateway fuer die Metadaten-Route:  ip route | grep default
  # --------------------------------------------------------------------------
  networking = {
    useDHCP = false;
    interfaces.ens3 = {
      useDHCP = true;

      # Vultr-Metadatendienst: link-local Adresse, aber ueber das Gateway
      # geroutet. Wird gerne vergessen. Gateway der NEUEN Instanz eintragen.
      ipv4.routes = [
        { address = "169.254.169.254"; prefixLength = 32; via = "GATEWAY-DER-NEUEN-INSTANZ"; }
      ];

      # IPv6 kommt per Router Advertisement. Falls das nicht greift,
      # hier die Adresse der neuen Instanz statisch setzen:
      # ipv6.addresses = [ { address = "..."; prefixLength = 64; } ];
    };

    # Falls IPv6 statisch gesetzt werden muss, zusaetzlich:
    # defaultGateway6 = { address = "fe80::..."; interface = "ens3"; };

    nameservers = [ "108.61.10.10" "2001:19f0:300:1704::6" ];
  };
}
