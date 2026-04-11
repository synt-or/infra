# 0015 — Tailscale : firewall par port et restriction SSH

Date : 2026-04-11
Statut : acceptée

## Contexte

SSH est ouvert sur toutes les interfaces (port 22 global). Le profil de menace (HDS, militant) exige de réduire la surface d'attaque réseau. Tailscale fournit un tunnel WireGuard authentifié sans exposer SSH à l'internet. La question est comment intégrer Tailscale avec le firewall existant.

Contraintes techniques : `lockKernelModules = true` (pas de chargement de modules après le boot), `CONFIG_TUN=y` (TUN compilé dans le kernel Asahi, pas en module), `user.max_user_namespaces = 0` (pas de conflit — `tailscaled` tourne en root).

## Options évaluées

### Option A — `trustedInterfaces = [ "tailscale0" ]`

Ouvre tous les ports sur l'interface Tailscale. Simple, mais viole le principe du moindre privilège : si un nœud du tailnet est compromis (ou si un appareil est ajouté par erreur), il a un accès réseau complet à la machine.

### Option B — `interfaces.tailscale0.allowedTCPPorts = [ 22 ]`

N'ouvre que SSH sur l'interface Tailscale. Chaque futur service devra être ajouté explicitement. Granulaire et cohérent avec le profil de sécurité.

### Option C — `ListenAddress` sur l'IP Tailscale

SSH n'écoute que sur l'IP 100.x.y.z. Problème : l'IP est assignée dynamiquement au premier `tailscale up`, non connue au moment de la déclaration NixOS. Crée un problème de poule et d'œuf (rebuild avant auth, auth avant rebuild). La différence de sécurité avec l'option B est négligeable — un paquet bloqué par le firewall avant d'atteindre le socket SSH est équivalent à un socket qui n'écoute pas.

## Décision

Option B retenue. Le firewall global ferme tous les ports TCP. SSH (port 22) est ouvert uniquement sur `tailscale0`. UDP 41641 est ouvert globalement (`openFirewall = true`) pour permettre les connexions WireGuard directes entre pairs (sans passer par les relais DERP).

`useRoutingFeatures = "none"` : la machine est un endpoint, pas un routeur. Pas d'exit node, pas de subnet router. Le `rp_filter` strict et l'absence d'`ip_forward` sont préservés.

`disableUpstreamLogging = true` : pas de logs envoyés à Tailscale (conformité HDS).

Auth impérative (`sudo tailscale up`) : le token d'authentification est éphémère et nécessite une interaction navigateur. L'état persiste dans `/var/lib/tailscale/` (sur rootfs chiffré LUKS). Impératif toléré — analogue à `systemd-cryptenroll`.

## Conséquences

SSH n'est plus accessible depuis le réseau local ni depuis l'internet. L'accès distant nécessite d'être sur le tailnet. En cas de perte d'accès Tailscale, la console physique reste disponible. Taildrop reste actif pour le partage de fichiers entre appareils du tailnet (iPhone ↔ Mac).
