# Standortspezifische Werte - Domains, Hostnamen, Kontakt.
#
# Bewusst an EINER Stelle statt ueber die Module verteilt: Wer das Repo als
# Vorlage nimmt, muss genau diese Datei anfassen und sonst nichts.
#
# Diese Werte sind KEINE Geheimnisse. Sie stehen im DNS, im Zertifikat und in
# jeder HTTP-Antwort - und sie muessen ohnehin im /nix/store auf dem Server
# landen, damit nginx weiss, welche Namen es bedient. Sie duerfen also ins Repo.
#
# Echte Geheimnisse gehen einen anderen Weg: Im Repo steht nur der PFAD, der
# Inhalt liegt mit 0600 auf dem Server.
#
#   /etc/secrets/root-password    Hash fuer die Konsolenanmeldung
#   /etc/nextcloud-admin-pass     Nextcloud-Admin
#   /etc/secrets/*.env            Laufzeitwerte fuer Dienste, von systemd
#                                 per EnvironmentFile eingelesen - die
#                                 landen nie im Store
#
# Zielzustand ist agenix: dann liegen auch diese Inhalte verschluesselt im
# Repo und nur der Zielhost kann sie entschluesseln. Erst damit ist die
# Konfiguration vollstaendig reproduzierbar.
{
  # Hauptdomain der Website. Der www-Alias wird daraus abgeleitet.
  domain = "tilmanbertram.com";

  # Hostname der Nextcloud-Instanz. Historisch "owncloud" - die Software war
  # aber schon immer Nextcloud. Der Name bleibt, damit kein DNS-Umzug noetig ist.
  nextcloudHost = "owncloud.tilmanbertram.com";

  # Kontaktadresse fuer Let's Encrypt. Rollenadresse statt privater Adresse:
  # bleibt gueltig, wenn sich die private aendert. Muss Mail empfangen koennen -
  # dorthin gehen die Warnungen, wenn eine Erneuerung ausbleibt. Solange kein
  # Mailserver laeuft: als Weiterleitung beim DNS-Anbieter einrichten.
  acmeEmail = "acme@tilmanbertram.com";
}
