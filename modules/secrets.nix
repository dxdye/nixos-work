{ config, ... }:
{
  # ==========================================================================
  # Verschluesselte Geheimnisse
  #
  # Die .age-Dateien im Repo sind Ciphertext und duerfen oeffentlich sein.
  # Entschluesselt werden sie zur Aktivierungszeit mit dem SSH-Host-Key dieser
  # Maschine, direkt nach /run/agenix/<name>:
  #
  #   - liegt auf tmpfs, also im RAM - kein Schreiben auf die Platte
  #   - Standardrechte 0400 root:root
  #   - landet NICHT im /nix/store, in der Konfiguration steht nur der Pfad
  #
  # Damit ist die Konfiguration vollstaendig reproduzierbar: Ein Klon des
  # Repos plus der Host-Key genuegen, um die Maschine neu aufzusetzen.
  #
  # ⚠ Beim Neuaufsetzen muss der Host-Key VORHER auf der Zielmaschine liegen,
  #   sonst kann agenix beim ersten Boot nichts entschluesseln. Dafuer gibt es
  #   nixos-anywhere --extra-files (siehe README).
  # ==========================================================================
  age.secrets = {
    root-password = {
      file = ../secrets/root-password.age;
      # Standard ist 0400 root:root - passt, da nur die Aktivierung liest.
    };

    timemachine-env = {
      file = ../secrets/timemachine.env.age;
      # Von systemd als root gelesen, bevor der Dienst seine Rechte abgibt.
    };

    nextcloud-admin = {
      file = ../secrets/nextcloud-admin.age;
      # nextcloud-setup laeuft als root und reicht die Datei per
      # systemd-Credential weiter - Standardrechte genuegen also auch hier.
    };
  };
}
