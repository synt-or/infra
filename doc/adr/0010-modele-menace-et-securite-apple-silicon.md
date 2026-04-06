# 0010 — Modèle de menace et sécurité Apple Silicon

Date : 2026-04-06
Statut : acceptée

## Contexte

Machine utilisée pour des données HDS (santé) avec obligation légale de protection, clés d'infrastructure (VPS, Tailscale, GPU via VS Network SAS), vault Vaultwarden + Paperless-ngx, profil militant. Ce contexte exige un modèle de menace explicite et une compréhension fine des propriétés de sécurité hardware conservées et perdues sous NixOS.

### Menaces classées par priorité

1. **Compromission du Synology DS918+** — SPOF : toutes les sauvegardes, tous les secrets. DSM propriétaire avec historique de CVE, ports ouverts.
2. **Compromission distante du Mac** — exploit réseau, supply chain, malware.
3. **Vol physique du Mac** — cambriolage (appartement vide plusieurs fois par jour).
4. **Evil maid** — accès physique temporaire (prestataire, visiteur).
5. **Attaque ciblée** — profil militant → acteur étatique.
6. **Compromission de la chaîne de build** — empoisonnement nixpkgs, dépendances malveillantes.

La matrice d'attaque détaillée est dans [MATRICE-ATTAQUE.md](../MATRICE-ATTAQUE.md).

## Options évaluées

### Option A — Modèle de menace implicite

Ne pas documenter, considérer que les protections en place sont « suffisantes ».

### Option B — Modèle de menace explicite avec documentation des propriétés hardware

Documenter les menaces, les prioriser, et cartographier les propriétés de sécurité Apple Silicon conservées et perdues sous NixOS.

## Décision

Option B. Le profil de risque (HDS + militant) exige un modèle explicite.

### Chiffrement double couche

- **Couche 1 — Chiffrement matériel permanent.** Le contrôleur de stockage du SoC chiffre tout en AES-256 avec une clé liée au SoC. Toujours actif, transparent, protège contre l'extraction NAND (dessoudage des puces = bruit chiffré).
- **Couche 2 — LUKS2 (sous NixOS) / FileVault (sous macOS).** Protège contre le vol du Mac complet. FileVault DOIT être activé côté macOS.

### Cold boot éliminé par la physique

La RAM LPDDR5 est intégrée au SiP (system-in-package). Les dies de RAM sont empilés directement sur ou à côté du die processeur. Le dessoudage nécessite de la chaleur qui accélère la décharge des condensateurs DRAM et détruit les données. Le froid nécessaire à la préservation et la chaleur nécessaire à l'extraction sont mutuellement exclusifs. Aucune recherche publiée n'a démontré ni même tenté un cold boot sur Apple Silicon. La communauté forensique (Cellebrite, Magnet, SUMURI, ADF) s'est intégralement tournée vers l'acquisition logique.

### Propriétés conservées sous NixOS

- Boot chain hardware : BootROM (silicium immuable) → iBoot (signé Apple)
- Boot Policy SEP pour m1n1 stage 1 (hash vérifié à chaque boot, modifiable uniquement en 1TR + credentials Machine Owner)
- Isolation firmware — chaque blob cantonné à son sous-système (pas de blob type Intel ME avec accès DMA total)
- Cold boot éliminé (architecture SiP)
- DART (IOMMU Apple Silicon) actif par défaut

### Propriétés perdues sous NixOS

- SSV (Signed System Volume) — pas de vérification d'intégrité continue du rootfs
- SEP pour chiffrement disque — LUKS utilise une clé en RAM, pas le SEP
- Signature ECID — pas de liaison cryptographique entre le binaire et la machine spécifique
- Anti-rollback serveur — pas de vérification Apple que le firmware n'a pas été downgraded
- TCC / App Sandbox / notarisation — pas d'isolation applicative macOS
- Touch ID — le capteur biométrique est exclusif au SEP macOS

### Chaîne de boot

```
BootROM (silicium immuable)
  → iBoot (signé Apple)
    → m1n1 stage 1 (hash dans Boot Policy SEP, vérifié à chaque boot,
                     modifiable uniquement en 1TR + credentials Machine Owner,
                     code de chainloading en Rust)
      → m1n1 stage 2 (sur partition EFI FAT32, NON vérifié cryptographiquement,
                       mis à jour par les distributions,
                       signature prévue par Asahi avec clé publique dans stage 1)
        → U-Boot
          → systemd-boot
            → kernel + initrd
              → LUKS
```

**Le trou de sécurité principal** est entre stage 1 et stage 2 — le stage 2 est sur une partition non chiffrée et non vérifié cryptographiquement. Issue GitHub `AsahiLinux/m1n1#195` documente ce vecteur evil maid.

## Conséquences

Les risques résiduels acceptés sont documentés dans [RISQUES-RESIDUELS.md](../RISQUES-RESIDUELS.md). Les mitigations principales sont :

- Vérification des hashes de la partition EFI depuis macOS (SSV garantit l'environnement de vérification)
- Signature kernel avec clé SEP (Phase 2)
- `safe-rebuild.sh` pour la chaîne de déploiement (voir [ADR 0007](0007-nixos-rebuild-ne-verifie-pas-signatures.md))
- LUKS imbriqué pour le vrai multi-facteur (Phase 2, voir [ADR 0004](0004-luks-imbrique-passphrase-externe-yubikey-interne.md))
- Shutdown automatique après 30 min d'inactivité (voir [ADR 0002](0002-hibernation-ecartee-s2idle-shutdown.md))
