{ modulesPath, ... }:
{
  imports = [ (modulesPath + "/profiles/qemu-guest.nix") ];

  nixpkgs.hostPlatform = "x86_64-linux";

  # --------------------------------------------------------------------------
  # Boot
  # BIOS-Boot, kein EFI: auf dem Debian war grub-pc installiert,
  # grub-efi-amd64 nur als Konfigurationsleiche (rc).
  # --------------------------------------------------------------------------
  boot.loader.grub = {
    enable = true;
    device = "/dev/vda";
    configurationLimit = 5; # nur 5 Generationen im Bootmenue -> spart Platz
  };

  boot.initrd.availableKernelModules = [
    "ata_piix" "uhci_hcd" "virtio_pci" "virtio_scsi" "sd_mod" "sr_mod"
  ];

  # --------------------------------------------------------------------------
  # Dateisysteme
  # NACH dem Infect gegen die von nixos-infect erzeugte hardware-configuration
  # abgleichen - insbesondere, ob "/" per UUID statt per /dev/vda1 gesetzt wird.
  # --------------------------------------------------------------------------
  fileSystems."/" = {
    device = "/dev/vda1";
    fsType = "ext4";
  };

  # Block Storage (Vultr, 10 GB) - Nutzdaten getrennt vom System.
  # UUID eintragen, sobald das Volume angehaengt und formatiert ist:
  #   blkid -s UUID -o value /dev/vdb
  # "nofail" ist Pflicht: sonst haengt der Boot, wenn das Volume abgehaengt ist
  # (und genau das machen wir vor dem Infect absichtlich).
  #
  # fileSystems."/mnt/data" = {
  #   device = "/dev/disk/by-uuid/PLATZHALTER-UUID-VDB";
  #   fsType = "ext4";
  #   options = [ "nofail" "noatime" ];
  # };

  swapDevices = [ { device = "/swapfile"; size = 2048; } ];

  # --------------------------------------------------------------------------
  # Netzwerk - 1:1 uebernommen aus dem laufenden Debian
  #   ens3   104.238.190.14/23      Gateway 104.238.190.1
  #          2001:19f0:6801:36:5400:3ff:fe27:393e/64  (SLAAC)
  #          MAC 56:00:03:27:39:3e
  #   ens9   vorhanden, aber DOWN (Vultr Private Network, ungenutzt)
  #
  # Bewusst DHCP statt statischer Adressen: entspricht dem Ist-Zustand
  # (iface ens3 inet dhcp / inet6 auto) und ist fehlertoleranter - ein
  # Tippfehler in einer statischen Adresse waere nach dem Infect fatal.
  # --------------------------------------------------------------------------
  networking = {
    useDHCP = false;
    interfaces.ens3 = {
      useDHCP = true;

      # Vultr-Metadatendienst: link-local Adresse, aber ueber das Gateway
      # geroutet. Wird gerne vergessen.
      ipv4.routes = [
        { address = "169.254.169.254"; prefixLength = 32; via = "104.238.190.1"; }
      ];

      # IPv6 kommt per Router Advertisement, wie bisher unter Debian.
      # Falls das nach dem Infect nicht greift, hier statisch setzen:
      # ipv6.addresses = [
      #   { address = "2001:19f0:6801:36:5400:3ff:fe27:393e"; prefixLength = 64; }
      # ];
    };

    # Falls IPv6 statisch gesetzt werden muss, zusaetzlich:
    # defaultGateway6 = { address = "fe80::fc00:3ff:fe27:393e"; interface = "ens3"; };

    nameservers = [ "108.61.10.10" "2001:19f0:300:1704::6" ];
  };
}
