# satom-leman-portail

Portail du Groupe Léman Finance SA (client fictif) reconstruit en **infrastructure as code (AWS CloudFormation)** pour le projet SatomCloudNetwork.
Aucun déploiement manuel : template versionné → pull request relue → pipeline DevSecOps → change set.

| Élément | Valeur |
|---|---|
| Région | `eu-central-2` (Zurich) ; budget, DNS public, WAF CloudFront en `us-east-1` |
| Environnements | `dev` (10.1.0.0/16) et `prod` (10.0.0.0/16), mêmes templates, paramètres séparés |
| Tags | `Projet=SatomCloudNetwork`, `Equipe=Assaga`, `Environnement=<dev\|prod>` |
| Convention de nommage | suffixe `-AA` (compte partagé) |

## Arborescence
```
templates/      un YAML par domaine (00 à 09)
parameters/     dev.json, prod.json, shared.json (aucun secret)
policies/guard/ règles cfn-guard (port 22, chiffrement, tags)
tests/          tests de connectivité, performance et supervision (preuves -> docs/preuves/)
scripts/        deploy.sh (change sets), destroy.sh, tgw-hybrid-routing.sh
bootstrap/      rôle OIDC GitHub + rôle d'exécution CloudFormation (seul déploiement manuel)
site/static/    contenu statique servi par CloudFront (/static/*)
docs/           journal, Direct Connect, rapport, procédure de démo
.github/        pipeline et modèle de pull request
```

## Commandes
```bash
./scripts/deploy.sh shared-pre      # budget, DNS public + WAF (us-east-1), services de compte
./scripts/deploy.sh dev             # base network security compute edge monitoring
./scripts/deploy.sh prod
./scripts/deploy.sh shared-post     # peering ou TGW (+ VPN, DX)
./tests/run-pipeline-tests.sh dev
./scripts/destroy.sh shared-post && ./scripts/destroy.sh dev   # démonstration
```

Guide complet sprint par sprint : [`GUIDE.md`](GUIDE.md).
