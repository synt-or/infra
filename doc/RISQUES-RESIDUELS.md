# Risques résiduels acceptés

Ce document liste tous les risques connus et formellement acceptés pour l'infrastructure NixOS sur MacBook Pro M1 Pro. Chaque risque a été évalué et sa présence ici signifie : « on sait que c'est un risque et on l'accepte pour cette raison ».

Pour le détail des vecteurs d'attaque et leurs mitigations, voir [MATRICE-ATTAQUE.md](MATRICE-ATTAQUE.md).

-----

1. **Partition EFI non chiffrée**

   Contient kernel, initrd, bootloader. Modifiable avec accès physique. Triple incompatibilité GRUB/LUKS2/FIDO2 empêche le chiffrement de /boot (voir [ADR 0011](adr/0011-boot-non-chiffrable-fido2.md)).

   *Justification :* contrainte technique incontournable sur Asahi avec systemd-boot.

   *Mitigations :* vérification des hashes depuis macOS (SSV garantit l'intégrité de l'environnement de vérification), signature kernel avec clé SEP, future signature m1n1 stage 2 par Asahi (code Rust en cours). Résolution potentielle : Lanzaboote avec UKI signées.

2. **Clé LUKS en RAM pendant le fonctionnement et en s2idle**

   Inhérent à dm-crypt. La clé maître LUKS est en mémoire kernel tant que le volume est ouvert. En s2idle, le risque est un sous-ensemble strict du risque en fonctionnement normal — même clé en RAM, mais espace utilisateur gelé.

   *Justification :* risque inhérent à tout chiffrement de disque logiciel. Seul vecteur résiduel : exploit kernel 0-day, déjà accepté comme risque inhérent au fonctionnement.

   *Mitigations :* `lockdown=confidentiality`, DART, SiP élimine le cold boot. Shutdown automatique après 30 min borne l'exposition. Voir [ADR 0002](adr/0002-hibernation-ecartee-s2idle-shutdown.md).

3. **Pas d'hibernation**

   `CONFIG_HIBERNATION` désactivé sur Asahi ET `lockdown=confidentiality` le bloque indépendamment. L'hibernation aurait permis d'effacer la clé LUKS de la RAM à chaque suspension.

   *Justification :* double blocage indépendant (kernel Asahi + lockdown). Évaluée et écartée — modèle s2idle + shutdown formellement justifié. Voir [ADR 0002](adr/0002-hibernation-ecartee-s2idle-shutdown.md).

4. **Blobs firmware Apple opaques**

   Non auditables mais compartimentés — chaque blob cantonné à son sous-système (GPU, ISP, codec audio, etc.). Aucun blob avec accès système total, contrairement à Intel ME (blob monolithique avec accès DMA total à la RAM + réseau).

   *Justification :* compromis inhérent à la plateforme Apple Silicon. L'isolation par sous-système limite le blast radius d'un blob compromis. Voir [ADR 0010](adr/0010-modele-menace-et-securite-apple-silicon.md).

5. **2FA et non 3FA pour le déverrouillage LUKS (Phase 0)**

   Les keyslots LUKS sont des alternatives (OR), pas des facteurs cumulables (AND). Le vrai multi-facteur nécessite du LUKS imbriqué (Phase 2).

   *Justification :* limitation architecturale de LUKS. La Phase 2 apportera le vrai AND via LUKS imbriqué (passphrase externe + YubiKey interne). Voir [ADR 0004](adr/0004-luks-imbrique-passphrase-externe-yubikey-interne.md).

6. **Bug pcsclite NixOS #329135**

   L'initrd systemd ne charge pas correctement la bibliothèque pcsclite nécessaire au déverrouillage FIDO2, provoquant un double prompt de PIN. Fonctionnel mais dégradé.

   *Justification :* bug upstream NixOS. Le déverrouillage fonctionne malgré l'UX dégradée. À surveiller.

7. **SEP non disponible sous Linux**

   Pas de Touch ID, pas de chiffrement disque via SEP, pas de stockage de clés hardware côté Linux. Le SEP est exclusif à macOS/iBoot.

   *Justification :* limitation de la plateforme. Compensé par YubiKey FIDO2 comme facteur hardware externe et par la vérification d'intégrité depuis macOS (qui a accès au SEP). Voir [ADR 0010](adr/0010-modele-menace-et-securite-apple-silicon.md).

8. **nixos-rebuild ne vérifie pas les signatures de commits**

   Comportement natif : fetch + build aveugle. Un commit non signé (injecté via compromission GitHub ou rebuild local malveillant) serait buildé sans alerte.

   *Justification :* comportement upstream non modifiable. Mitigé par `safe-rebuild.sh` (convention, pas contrainte technique). Protection ultime : vérification post-reboot macOS + signature kernel SEP. Voir [ADR 0007](adr/0007-nixos-rebuild-ne-verifie-pas-signatures.md).

9. **Compromission de GitHub**

   Repo hébergé chez un tiers. Un employé malveillant, une faille infra ou une injonction judiciaire pourrait modifier silencieusement le repo.

   *Justification :* risque inhérent à l'hébergement chez un tiers. Mitigé par vérification de signature (commit injecté ne serait pas signé par la clé sk), `--ff-only`, log d'audit. Limite connue : replay d'un ancien commit signé non détecté par la signature seule.
