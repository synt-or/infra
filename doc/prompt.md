# Instructions pour Claude Code

Tu travailles sur le repo `/data/infra`, une infrastructure NixOS déclarative pour un MacBook Pro M1 Pro via Asahi Linux. Lis d’abord CLAUDE.md, TODO.md, et les ADR existantes dans doc/adr/ pour comprendre le contexte.

Tu dois créer les fichiers suivants et mettre à jour les références dans CLAUDE.md. Tous les détails techniques ci-dessous ont été vérifiés contre les sources primaires (documentation Asahi, man pages kernel, code source NixOS, documentation LUKS2, communauté forensique).

-----

## 1. Créer `doc/MATRICE-ATTAQUE.md`

Ce fichier documente tous les vecteurs d’attaque connus classés par contexte, avec leur description détaillée et leur mitigation. C’est la pièce maîtresse de la documentation de sécurité.

### Contenu à inclure :

**Catégorie 1 — Machine déverrouillée et en fonctionnement**

Vecteur : Exploit kernel direct. Une vulnérabilité dans le kernel Linux (buffer overflow, use-after-free dans un driver) donne à l’attaquant une exécution en ring 0, en dessous du lockdown. Il peut lire la clé LUKS directement depuis les structures dm-crypt en mémoire kernel. C’est le vecteur le plus réaliste. Mitigation : kernel à jour, surface d’attaque réduite (pas de services inutiles), AppArmor sur les services exposés.

Vecteur : Attaque DMA via Thunderbolt. Un appareil malveillant branché sur le port USB-C/Thunderbolt tente de lire la RAM via DMA. Mitigation : le DART (Device Address Resolution Table, l’IOMMU Apple Silicon) filtre les accès DMA par périphérique via le device tree. Chaque périphérique est dans sa propre “cage” mémoire et ne peut accéder qu’aux buffers que le kernel lui a assignés. Le DART est actif par défaut, géré par le driver apple-dart (CONFIG_APPLE_DART=y). Ne pas brancher d’appareils inconnus quand la machine est déverrouillée.

Vecteur : Shutdown nocturne (modification config + rebuild + shutdown). Un attaquant root modifie configuration.nix pour retirer le lockdown, fait un nixos-rebuild, déclenche un shutdown à 3h du matin. L’utilisateur saisit la passphrase LUKS au réveil, croyant à un crash. Le kernel compromis démarre avec la bénédiction de l’utilisateur. Mitigation : vérification des hashes de la partition EFI depuis macOS après tout reboot inattendu, monitoring de l’uptime, safe-rebuild.sh qui vérifie les signatures.

**Catégorie 2 — Machine en veille (s2idle)**

Vecteur : Clé LUKS en RAM pendant la veille. s2idle maintient la RAM alimentée, la clé LUKS est présente. Statut : risque formellement accepté. Justification : le risque en s2idle est un sous-ensemble strict du risque en fonctionnement normal — même clé en RAM, mais espace utilisateur gelé (surface d’attaque réduite par rapport à une machine active avec services réseau). Protections : lockdown=confidentiality bloque l’extraction userspace, DART bloque le DMA, SiP élimine le cold boot. Seul vecteur résiduel : exploit kernel 0-day, déjà accepté comme risque inhérent au fonctionnement. Le shutdown automatique après 30 min d’inactivité borne la durée d’exposition. Voir ADR 0002 pour la justification complète.

**Catégorie 3 — Machine éteinte (shutdown complet)**

Vecteur : Remplacement kernel/initrd sur partition EFI. L’attaquant avec accès physique modifie le kernel ou l’initrd sur la partition EFI non chiffrée. Au prochain boot, le kernel/initrd piégé capture la clé LUKS ou les credentials FIDO2. Mitigation : vérification des hashes depuis macOS (SSV garantit l’intégrité de l’environnement de vérification), signature du kernel avec clé personnelle dans le SEP.

Vecteur : Cold boot. L’attaquant tente de refroidir la RAM et d’en extraire le contenu. Statut : éliminé par la physique sur Apple Silicon. La RAM LPDDR5 est intégrée au SiP (system-in-package). Les dies de RAM sont empilés directement sur ou à côté du die processeur. Le dessoudage nécessiterait de la chaleur qui accélère la décharge des condensateurs DRAM et détruit les données. Le froid nécessaire à la préservation et la chaleur nécessaire à l’extraction sont mutuellement exclusifs. Aucune recherche publiée n’a démontré ni même tenté un cold boot sur Apple Silicon. La communauté forensique (Cellebrite, Magnet, SUMURI, ADF) s’est intégralement tournée vers l’acquisition logique.

Vecteur : Dessoudage des puces NAND. L’attaquant extrait physiquement les puces de stockage. Sans la clé LUKS (disparue de la RAM par shutdown), il obtient du bruit chiffré AES-256 (chiffrement hardware permanent Apple, toujours actif, lié au SoC) + LUKS2 par-dessus. Double chiffrement, bruteforce impossible.

Vecteur : DFU + réinstallation (evil maid avancée). L’attaquant utilise le mode DFU pour effacer et réinstaller un OS piégé. Contremesures : Find My Mac / Activation Lock bloque le Setup Assistant, toutes les données précédentes sont détruites cryptographiquement (pas de récupération pour l’attaquant), l’utilisateur retrouve un Mac vierge (signal d’alerte évident).

**Catégorie 4 — Chaîne de déploiement**

Vecteur : Push malveillant sur GitHub. Un attaquant obtient un accès push au repo de config, modifie configuration.nix. Le prochain nixos-rebuild déploie la config malveillante. Mitigation : clé SSH sk résidente pour auth GitHub (push impossible sans YubiKey + touch). Wrapper safe-rebuild.sh vérifie la signature du commit avant de builder.

Vecteur : Compromission de GitHub. Employé malveillant, faille infra, injonction judiciaire — modification silencieuse du repo. Mitigation : safe-rebuild.sh vérifie la signature du commit (un commit injecté par GitHub ne serait pas signé par la clé sk). Limitation : un replay d’un ancien commit signé ne serait pas détecté par la signature seule. Le –ff-only et le log d’audit atténuent.

Vecteur : Rebuild local malveillant. Attaquant root pointe nixos-rebuild vers un flake arbitraire. Mitigation : safe-rebuild.sh comme convention + log d’audit. Root peut contourner le wrapper — mitigation ultime : vérification des hashes depuis macOS post-reboot + signature kernel via SEP/Touch ID.

Vecteur : Empoisonnement du flake.lock. Attaquant modifie flake.lock pour pointer vers un nixpkgs malveillant, signe le commit avec une clé compromise. Mitigation : revue humaine du diff de flake.lock avant chaque commit de mise à jour nixpkgs. Le wrapper ne détecte pas ce vecteur automatiquement — limite documentée.

Vecteur : nixos-rebuild ne vérifie pas les signatures. Comportement natif : git fetch + build aveugle, aucune vérification de signature. Mitigation : safe-rebuild.sh comble ce trou (voir ADR 0007).

**Catégorie 5 — Supply chain et hors machine**

Vecteur : Compromission kernel/initrd via la build chain. Un paquet NixOS ou une dépendance contient un rootkit kernel. Mitigation : flake.lock épinglé, commits signés, reproductibilité des builds NixOS.

Vecteur : Compromission du serveur de sauvegarde. Si les sauvegardes ne sont pas chiffrées côté client, l’attaquant contourne toute la sécurité du Mac. Mitigation : chiffrement restic/borg côté client avec clé sur YubiKey.

Vecteur : Ingénierie sociale / coercition. Convaincre ou contraindre le propriétaire de déverrouiller. Aucune mitigation technique — problème humain. Le multi-facteur (objet + biométrie/PIN + passphrase) rend la coercition plus complexe.

### Format attendu :

Tableau par catégorie avec colonnes : Vecteur, Description, Mitigation, Statut (actif/éliminé/accepté). Ajouter une note d’introduction expliquant comment lire la matrice. Référencer les ADR pertinentes.

-----

## 2. Créer `doc/RISQUES-RESIDUELS.md`

Ce fichier liste tous les risques connus et acceptés avec leur justification. C’est la documentation “on sait que c’est un risque et on l’accepte pour cette raison”.

### Contenu à inclure (9 risques) :

1. Partition EFI non chiffrée. Contient kernel, initrd, bootloader. Modifiable avec accès physique. Mitigé par vérification depuis macOS + signature kernel + future signature m1n1 stage 2 par Asahi (code Rust en cours).
1. Clé LUKS en RAM pendant le fonctionnement et en s2idle. Inhérent à dm-crypt. Sous-ensemble strict du risque en fonctionnement normal. Protections : lockdown, DART, SiP. Seul résiduel : exploit kernel 0-day. Shutdown 30 min borne l’exposition. Voir ADR 0002.
1. Pas d’hibernation. CONFIG_HIBERNATION désactivé sur Asahi ET lockdown le bloque. Évaluée et écartée — modèle s2idle + shutdown formellement justifié. Voir ADR 0002.
1. Blobs firmware Apple opaques. Non auditables mais compartimentés — chaque blob cantonné à son sous-système. Aucun blob avec accès système total (contrairement à Intel ME qui est un blob monolithique avec accès DMA total à la RAM + réseau). Accepté comme compromis inhérent à la plateforme.
1. 2FA et non 3FA pour le déverrouillage LUKS (Phase 0). Les keyslots LUKS sont des alternatives (OR), pas des facteurs cumulables (AND). Le vrai multi-facteur nécessite du LUKS imbriqué (Phase 2). Voir ADR 0004.
1. Bug pcsclite NixOS #329135. L’initrd systemd ne charge pas correctement la bibliothèque pcsclite nécessaire au déverrouillage FIDO2, provoquant un double prompt de PIN. Fonctionnel mais dégradé. À surveiller.
1. SEP non disponible sous Linux. Pas de Touch ID, pas de chiffrement disque via SEP, pas de stockage de clés hardware côté Linux. Compensé par YubiKey FIDO2 comme facteur hardware externe et par la vérification d’intégrité depuis macOS (qui a accès au SEP).
1. nixos-rebuild ne vérifie pas les signatures de commits. Fetch + build aveugle. Mitigé par safe-rebuild.sh (convention, pas contrainte technique). Protection ultime : vérification post-reboot macOS + signature kernel SEP. Voir ADR 0007.
1. Compromission de GitHub. Repo hébergé chez un tiers. Mitigé par vérification de signature (commit injecté ne serait pas signé), –ff-only, log d’audit. Limite : replay d’ancien commit signé non détecté.

### Format attendu :

Liste numérotée avec pour chaque risque : titre, description, justification de l’acceptation, mitigations en place, références aux ADR.

-----

## 3. Créer `doc/adr/0010-modele-menace-et-securite-apple-silicon.md`

ADR documentant le modèle de menace et le contexte de sécurité hardware. Utilise le template dans .claude/skills/new-adr/SKILL.md.

### Contexte :

Machine utilisée pour des données HDS (santé) avec obligation légale de protection, clés d’infrastructure (VPS, Tailscale, GPU), vault Vaultwarden + Paperless-ngx, profil militant.

### Menaces classées par priorité :

1. Compromission du Synology DS918+ (SPOF — toutes les sauvegardes, tous les secrets)
1. Compromission distante du Mac (exploit réseau, supply chain, malware)
1. Vol physique du Mac (cambriolage — appartement vide plusieurs fois par jour)
1. Evil maid (accès physique temporaire — prestataire, visiteur)
1. Attaque ciblée (profil militant → acteur étatique)
1. Compromission de la chaîne de build

### Contexte hardware Apple Silicon à documenter :

Chiffrement double couche : Couche 1 = chiffrement matériel permanent (contrôleur de stockage du SoC, clé liée au SoC, toujours actif, protège contre extraction NAND). Couche 2 = FileVault (mot de passe + UID SEP, protège contre vol du Mac complet, DOIT être activé).

Cold boot éliminé par la physique : RAM LPDDR5 intégrée au SiP, dessoudage = chaleur = destruction des données.

Propriétés conservées sous NixOS : boot chain hardware (BootROM → iBoot), Boot Policy SEP pour m1n1 stage 1, isolation firmware (pas de blob type Intel ME), cold boot éliminé.

Propriétés perdues sous NixOS : SSV (pas de vérification d’intégrité continue), SEP pour chiffrement disque (LUKS = clé en RAM), signature ECID, anti-rollback serveur, TCC/App Sandbox/notarisation, Touch ID.

Chaîne de boot : BootROM (silicium immuable) → iBoot (signé Apple) → m1n1 stage 1 (hash dans Boot Policy SEP, vérifié à chaque boot, modifiable uniquement en 1TR + credentials Machine Owner, code de chainloading en Rust) → m1n1 stage 2 (sur partition EFI FAT32, NON vérifié cryptographiquement actuellement, mis à jour par les distributions, signature prévue par Asahi avec clé publique dans stage 1) → U-Boot → systemd-boot → kernel + initrd → LUKS.

Le trou de sécurité principal est entre stage 1 et stage 2 — le stage 2 est sur une partition non chiffrée et non vérifié. Issue GitHub AsahiLinux/m1n1#195 documente ce vecteur evil maid.

-----

## 4. Créer `doc/adr/0011-boot-non-chiffrable-fido2.md`

ADR documentant pourquoi /boot ne peut pas être chiffré avec FIDO2.

Triple incompatibilité :

- GRUB et LUKS2 : GRUB ne supporte pas LUKS2 de manière fiable. Or systemd-cryptenroll exige LUKS2.
- GRUB et FIDO2 : GRUB ne parle pas FIDO2. Le déverrouillage FIDO2 se fait dans l’initrd, après que le kernel est chargé par le bootloader.
- Asahi et systemd-boot : le setup Asahi utilise systemd-boot via U-Boot, pas GRUB. systemd-boot ne supporte pas le déchiffrement de /boot.

Conséquence acceptée : kernel et initrd exposés sur partition EFI. Surface d’attaque résiduelle couverte par vérification des hashes depuis macOS et signature kernel avec clé SEP.

Résolution potentielle à terme : Lanzaboote avec Unified Kernel Images (UKI) signées — kernel, initrd, bootloader dans un seul binaire signé. Compatibilité Asahi à valider.

-----

## 5. Créer `doc/adr/0012-yubikey-bio-fido-edition.md`

ADR documentant le choix de la YubiKey Bio FIDO Edition.

La YubiKey Bio existe en deux variantes :

- FIDO Edition : FIDO2 + U2F uniquement. En vente libre (~90-100€). Suffit pour LUKS FIDO2, SSH sk résident, passkeys, signature de commits Git.
- Multi-protocol Edition : FIDO2 + U2F + PIV/smart card. Disponible exclusivement via YubiKey as a Service (abonnement entreprise). Ajoute certificats X.509, authentification Windows smart card, VPN client-certificate.

Décision : FIDO Edition. Le PIV/smart card n’a pas de use case identifié (pas de PKI entreprise, pas d’Active Directory, pas de S/MIME). SSH sk résidentes permettent de signer des commits Git sans GPG (Git 2.34+, gpg.format = ssh). Le seul scénario où PIV manquerait : stocker la clé de signature kernel directement sur la YubiKey au lieu du SEP macOS — nice-to-have, pas bloquant.

-----

## 6. Mettre à jour `CLAUDE.md`

Ajouter dans la section pièges de sécurité ou en bas du fichier :

```
Matrice d'attaque complète dans @doc/MATRICE-ATTAQUE.md
Risques résiduels acceptés dans @doc/RISQUES-RESIDUELS.md
```

-----

## Règles pour la création

- Écrire en français
- Utiliser le template ADR de .claude/skills/new-adr/SKILL.md pour les ADR
- Les tableaux doivent avoir des colonnes alignées
- Référencer les ADR pertinentes quand c’est approprié (liens entre documents)
- Pas de contenu dupliqué entre les fichiers — chaque information vit à un seul endroit avec des références croisées
- Commit signé avec message descriptif