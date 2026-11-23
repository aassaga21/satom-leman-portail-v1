# Journal de projet - satom-leman-portail

> Une entree par sprint. Remplir APRES le deploiement et la mesure.
> Preuves brutes : `docs/preuves/` (sorties des scripts `tests/`) + captures.

| Sprint | PR | Date | Template(s) | Controle securite | Mesure | Resultat | Seuil | Conforme |
|---|---|---|---|---|---|---|---|---|
| 1 - VPC / sous-reseaux | #  |  | 02-network | aucun sous-reseau prive vers l'IGW | s01 | | plages et AZ conformes | |
| 2 - Routage | # | | 02-network, 03-security, 04-compute | defaut prive via NAT | s02 | | sortie OK, entree refusee | |
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
- **Objectif** :
- **Realise** :
- **Mesure** (commande + extrait de sortie) :
- **Ecarts / actions correctives** :
