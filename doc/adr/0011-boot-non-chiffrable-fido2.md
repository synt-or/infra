# 0011 — /boot ne peut pas être chiffré avec FIDO2

Date : 2026-04-06
Statut : acceptée

## Contexte

La partition EFI contient le kernel, l'initrd et le bootloader en clair. Un attaquant avec accès physique peut les modifier pour capturer la passphrase LUKS ou les credentials FIDO2 au prochain boot (evil maid). Chiffrer /boot éliminerait ce vecteur.

## Options évaluées

### Option A — Chiffrer /boot avec GRUB + LUKS2 + FIDO2

Triple incompatibilité :

1. **GRUB et LUKS2** : GRUB ne supporte pas LUKS2 de manière fiable. Or `systemd-cryptenroll` exige LUKS2.
2. **GRUB et FIDO2** : GRUB ne parle pas FIDO2. Le déverrouillage FIDO2 se fait dans l'initrd, après que le kernel est chargé par le bootloader.
3. **Asahi et systemd-boot** : le setup Asahi utilise systemd-boot via U-Boot, pas GRUB. systemd-boot ne supporte pas le déchiffrement de /boot.

Chaque incompatibilité est bloquante indépendamment. Les trois combinées rendent cette option impossible.

### Option B — Accepter le kernel/initrd en clair, mitiger autrement

Kernel et initrd exposés sur la partition EFI FAT32 non chiffrée. La surface d'attaque résiduelle est couverte par des vérifications hors-bande.

### Option C — Lanzaboote avec Unified Kernel Images (UKI) signées

Kernel, initrd et bootloader dans un seul binaire EFI signé. Élimine le vecteur evil maid sans chiffrer /boot (l'intégrité est garantie par la signature, pas par le chiffrement). Compatibilité Asahi à valider — dépend du support UEFI Secure Boot via U-Boot.

## Décision

Option B pour le présent (Phase 0-1). Option C à évaluer en Phase 4 quand Lanzaboote et le support Asahi auront mûri.

## Conséquences

Le kernel et l'initrd restent modifiables par un attaquant avec accès physique. Mitigations en place :

- Vérification des hashes de la partition EFI depuis macOS (SSV garantit l'intégrité de l'environnement de vérification)
- Signature kernel avec clé dans le SEP macOS (Phase 2)
- Procédure post-absence : booter macOS → vérifier → si OK → booter NixOS
- Le trou entre m1n1 stage 1 et stage 2 (voir [ADR 0010](0010-modele-menace-et-securite-apple-silicon.md)) est le même vecteur — une seule mitigation couvre les deux

Risque résiduel documenté dans [RISQUES-RESIDUELS.md](../RISQUES-RESIDUELS.md) §1.
