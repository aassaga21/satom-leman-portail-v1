## Sprint / module
<!-- ex. Sprint 3 - Security Groups et NACL -->

## Ce qui change
- [ ] Template(s) :
- [ ] Parametres (`parameters/*.json`, sans secret) :
- [ ] Politique(s) de securite (`policies/`) :
- [ ] Test(s) (`tests/`) :

## Controle de securite du sprint
<!-- regle verifiee et outil (cfn-guard, checkov, Reachability Analyzer...) -->

## Mesure et preuve
- Commande : `tests/sXX-....sh`
- Resultat obtenu / seuil :
- Preuve deposee : `docs/preuves/...` + entree dans `docs/journal.md`

## Grille de relecture (cochee par le relecteur)
- [ ] Pipeline verte (lint + securite)
- [ ] Aucun secret, aucune IP privee dans un enregistrement public
- [ ] Tags Projet / Equipe / Environnement presents
- [ ] Aucun 0.0.0.0/0 sur un port d'administration
- [ ] Ressources chiffrees (KMS / SSE)
- [ ] Change set relu : aucun remplacement inattendu (colonne Replacement)
- [ ] Cout : ressources couteuses desactivees apres mesure si besoin
