# Journal de projet - satom-leman-portail

> Une entree par sprint. Remplir APRES le deploiement et la mesure.
> Preuves brutes : `docs/preuves/` (sorties des scripts `tests/`) + captures.

| Sprint | PR | Date | Template(s) | Controle securite | Mesure | Resultat | Seuil | Conforme |
|---|---|---|---|---|---|---|---|---|
| 1 - VPC / sous-reseaux | #4, #5, #6, #7 | 2026-11-24 | 01-base, 02-network | aucun sous-reseau prive vers l'IGW | s01 | 5 sous-reseaux sur 2 AZ, plages conformes, 0 route IGW, aucune IP publique auto | plages et AZ conformes | Oui |
| 2 - Routage | #8 a #15 | 2026-11-24 | 02-network, 03-security, 04-compute | defaut prive via NAT, aucune route IGW pour le prive | s02, s01 | DEPOT_OK ; IP de sortie app-01 = IP de la NAT (16.192.102.197) ; app-01 sans IP publique | sortie OK, entree refusee | Oui |
| 3 - SG et NACL | # | | 03-security, 02-network | cfn-guard : 0 port admin a 0.0.0.0/0 | s03 | | 8080 OK, 22 bloque | |
| 4 - Network Firewall | # | | 02-network | liste blanche de domaines | s04 | | domaine bloque + journalise | |
| 5 - VPC Peering | # | | 05-interconnect (peering) | routes limitees au CIDR homologue | s05-s06 | | 8080 OK, 22 bloque | |
| 6 - Transit Gateway | # | | 05-interconnect (tgw) | tables TGW par environnement | s05-s06 | | chemin via tgw- | |
| 7 - VPN site a site | # | | 06-hybrid | IKEv2, PSK dans Secrets Manager | s07 | | 2/2 tunnels (voir ecart) | |
| 8 - Direct Connect | # | | 06-hybrid | prefixes filtres, pas de defaut | docs/direct-connect.md | | local-pref, bascule simulee | |
| 9 - ELB | # | | 08-edge | TLS 1.2+, logs d'acces | s09 --panne | | delai de bascule, taux d'erreur | |
| 10 - Route 53 | # | | 07-edge-global, 08-edge | DNSSEC, pas d'IP privee publique | s10 --bascule | | < 100 ms | |
| 11 - CloudFront | # | | 08-edge, 07-edge-global | ALB = prefixe CloudFront, WAF | s11 | | CacheHitRate > 80 % | |
| 12 - Supervision | # | | 09-monitoring, 00-account | GuardDuty, Security Hub, Config | s12, flowlogs | | notification < 5 min | |
| 13 - Automatisation | # | | pipeline, bootstrap | moindre privilege, approbation prod | demo | | recreation a l'identique | |

## Detail par sprint

### Sprint 1 - VPC et sous-reseaux
- **Objectif** : deployer par la pipeline la cle KMS (`01-base`) et le VPC avec 5 sous-reseaux sur 2 zones (`02-network`, section sprint 1), en dev puis en prod, sans aucun sous-reseau prive expose a Internet.
- **Realise** :
  - PR #4 : `01-base.yaml` + `02-network.yaml` reduit au sprint 1 (VPC + 5 sous-reseaux, `MapPublicIpOnLaunch: false` partout) ; scripts `deploy.sh`, `destroy.sh`, `tgw-hybrid-routing.sh` et `tests/lib.sh` passes de `eu-central-2` a `eu-north-1`.
  - Stacks creees par la pipeline : `stack-leman-dev-base`, `stack-leman-dev-network`, puis `stack-leman-prod-base`, `stack-leman-prod-network` apres approbation manuelle de l'environnement `prod`.
- **Mesure** (commande + extrait de sortie) :
  ```
  aws ec2 describe-subnets --region eu-north-1 \
    --filters Name=tag:Projet,Values=SatomCloudNetwork Name=tag:Environnement,Values=prod Name=tag:Equipe,Values=Assaga \
    --query "sort_by(Subnets,&CidrBlock)[].[Tags[?Key=='Name']|[0].Value,CidrBlock,AvailabilityZone,MapPublicIpOnLaunch]" --output table

  | sub-public-1a-prod-AA  | 10.0.0.0/24 | eu-north-1a | False |
  | sub-private-1a-prod-AA | 10.0.1.0/24 | eu-north-1a | False |
  | sub-private-1b-prod-AA | 10.0.2.0/24 | eu-north-1b | False |
  | sub-fw-1a-prod-AA      | 10.0.4.0/28 | eu-north-1a | False |
  | sub-public-1b-prod-AA  | 10.0.5.0/24 | eu-north-1b | False |
  ```
  Attendu atteint : `sub-public-1b-prod-AA` = 10.0.5.0/24 en zone b, `sub-fw-1a-prod-AA` = 10.0.4.0/28 en zone a. Test `s01` vert en dev et en prod dans la pipeline (aucune route IGW pour les sous-reseaux prives).
  Preuve : `docs/preuves/s01-20261124-231957.txt` (remplace `s01-subnets-prod.txt`, enregistre en UTF-16 par PowerShell et illisible sur GitHub) + capture console VPC > Subnets.
- **Ecarts / actions correctives** :
  - Region : `eu-central-2` (Zurich) refusee par la SCP de l'ecole -> projet deploye en `eu-north-1` (Stockholm) ; scripts corriges dans la PR #4.
  - PR #5 : `tests/s01-subnets.sh: Permission denied` -> droit d'execution perdu sous Windows ; `git update-index --chmod=+x` sur tous les `.sh` (100644 -> 100755).
  - PR #6 : `InvalidRouteTableID.NotFound` -> le test lisait la sortie `PrivateRouteTableId`, livree au sprint 2 ; le test controle desormais la table reellement utilisee par chaque sous-reseau prive (table privee, sinon table principale du VPC).
  - Commande de mesure : filtre `Equipe=Assaga` ajoute (compte AWS partage entre plusieurs eleves).

### Sprint 2 - Routage
- **Objectif** : donner aux sous-reseaux prives une sortie Internet controlee (NAT) sans aucune exposition entrante, et deployer les groupes de securite et les instances necessaires a la mesure (`app-01`).
- **Realise** :
  - `02-network.yaml` : IGW, tables `rt-public`, `rt-private` (defaut `0.0.0.0/0` via la NAT, jamais via l'IGW) et `rt-fw`, NAT Gateway + EIP.
  - `03-security.yaml` : `sg-alb`, `sg-web`, `sg-app` ; `04-compute.yaml` : `web-01`, `web-02`, `app-01` (+ `dev-01` en dev), sans IP publique, sans cle SSH, acces par SSM, EBS chiffre KMS, IMDSv2.
  - Pipeline : `s01` et `s03` verts en prod (8080 joignable, 22 bloque par le groupe de securite).
- **Mesure** (commande + extrait de sortie) :
  ```
  # AWS CloudShell (eu-north-1)
  git clone https://github.com/aassaga21/satom-leman-portail.git && cd satom-leman-portail
  bash tests/s02-egress.sh prod

  DEPOT_OK
  -- IP de sortie d'app-01 : 16.192.102.197
  -- IP publique de la NAT : 16.192.102.197
  [OK] depot de paquets joignable depuis app-01
  [OK] sortie via la NAT (16.192.102.197)
  -- app-01 : adresse IP publique : None
  [OK] app-01 sans IP publique
  ```
  Table privee prod : `10.0.0.0/16 local` + `0.0.0.0/0 -> nat-038415f97ea61158c`, aucune route IGW.
  Preuves : `docs/preuves/s02-20261124-231948.txt`, `docs/preuves/s01-20261124-231957.txt` + capture `rt-private-prod-AA` (onglet Routes).
- **Ecarts / actions correctives** :
  - PR #9 : `GroupName` refuse (`Group names may not be in the format sg-*`) -> groupes nommes `leman-alb/web/app/test-<env>-AA`, le tag `Name` conserve `sg-...`. La liste CloudFront (~55 entrees) comptait 2 fois dans le quota de 60 regles de `sg-alb` -> une seule regle 80-443.
  - PR #10 : `limit of 5 NAT gateways` atteinte en eu-north-1a (compte partage) -> NAT placee dans `sub-public-1b` ; pas de NAT en dev (`EnableNatGateway=false`), la mesure se fait en prod.
  - PR #11 : `iam:GetRole` / `iam:DetachRolePolicy` refuses au role d'execution -> avant creation, IAM controle l'ARN sans chemin (`role/<nom>`) ; ajout de `role/role-*-leman-*-AA` et `instance-profile/stack-leman-*` (bootstrap redeploye). Stack `compute` en `ROLLBACK_FAILED` supprimee a la main.
  - PR #12 : `tiros:CreateQuery` refuse (Reachability Analyzer) -> droits ajoutes au role de deploiement ; `s03` limite a la prod (~0,10 USD par analyse).
  - PR #13 : `s03` s'arretait apres l'analyse 8080 (`[[ ... ]] &&` en derniere ligne + `set -e`) -> `if` explicite.
  - PR #14 : `s02` affichait l'IP du serveur contacte (`%{remote_ip}`) au lieu de l'IP de sortie -> comparaison explicite IP de sortie / IP de la NAT.
  - PR #15 : NAT prod desactivee apres la mesure (`EnableNatGateway=false`) pour limiter le cout ; a reactiver pour les sprints qui en ont besoin.

