# Wer darf welches Geheimnis entschluesseln.
#
# Diese Datei wird NICHT von NixOS ausgewertet - sie ist ausschliesslich fuer
# das agenix-Kommandozeilenwerkzeug. Beim Bearbeiten eines Geheimnisses liest
# agenix hier nach, fuer welche oeffentlichen Schluessel neu verschluesselt
# werden muss.
#
# Bearbeiten:
#   nix run .#agenix -- -e secrets/root-password.age   (aus dem Wurzelverzeichnis)
#
# Nach dem Hinzufuegen eines Empfaengers muessen alle betroffenen Dateien neu
# verschluesselt werden:
#   nix run .#agenix -- -r
#
# ---------------------------------------------------------------------------
# ZWEI EMPFAENGER, ZWEI ROLLEN:
#
#   tw     dein persoenlicher Schluessel. Ohne ihn kannst DU die Geheimnisse
#          nicht mehr bearbeiten - er gehoert gesichert.
#
#   versa  der SSH-Host-Key der Maschine. Damit entschluesselt sie beim Start
#          selbst, ohne dass ein Passwort eingegeben werden muss.
#
# Geht die Maschine verloren, kommst du ueber `tw` weiterhin an alles heran.
# Geht `tw` verloren und die Maschine ebenfalls, sind die Werte unbrauchbar -
# dann bleiben nur die Klartext-Kopien in deinem Backup.
# ---------------------------------------------------------------------------
let
  # cat ~/.ssh/id_ed25519_versa.pub
  tw = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIIiNZ5YB4eSShUPYmrxZZhSdRSC0ZvkludjxZiMgivD4 tw@fedora -> versa";

  # ssh versa 'cat /etc/ssh/ssh_host_ed25519_key.pub'
  # Der Kommentar sagt "root@fillya" - der Schluessel entstand bei der
  # Installation, als die Maschine noch so hiess. Rein kosmetisch.
  versa = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIGvAbg2gvRRLE0HrS8cwR8V9+jfHBsNJT03UAt//AQjy root@fillya";

  alle = [ tw versa ];
in
{
  # Hash fuer die Konsolenanmeldung als root.
  # Inhalt: eine Zeile, sha-512-crypt, ohne Zeilenumbruch am Ende.
  "secrets/root-password.age".publicKeys = alle;

  # Adminpasswort der Nextcloud-Instanz, im Klartext.
  # Wird von services.nextcloud.config.adminpassFile gelesen.
  "secrets/nextcloud-admin.age".publicKeys = alle;

  # Laufzeitwerte fuer timemachine, KEY=VALUE je Zeile. Wird per systemd
  # EnvironmentFile gelesen - der Inhalt landet nie im /nix/store.
  #
  # Aktuell nur GITHUB_EMAILS: Commit-Mailadressen, die nicht im GitHub-Konto
  # hinterlegt sind. Ohne sie ordnet der Poller eigene Commits als fremde ein -
  # gemessen 31 von 41 in zwei Repositories.
  "secrets/timemachine.env.age".publicKeys = alle;
}
