# Sprint 8 - Direct Connect : concepts et simulation

Aucun circuit physique n'est commande (cout et delai). La DXGW `dxgw-leman-AA`
(ASN 64513) est reelle et associee a `tgw-leman-AA` ; le lien et le BGP sont simules.

## Architecture cible
Site client --(DX 1 Gbit/s, VIF de transit)--> DXGW (64513) --> TGW (64512) --> VPC prod
Site client --(VPN IPsec x2, secours)---------------------------> TGW

## Filtrage des prefixes
- AWS -> site : uniquement `10.0.0.0/16` (`AllowedPrefixesToDirectConnectGateway`), dev n'est jamais annonce.
- Site -> AWS : le routeur client n'annonce que ses reseaux internes ; une route par defaut
  recue serait refusee (filtre en entree cote client + aucune route 0.0.0.0/0 propagee dans
  les tables TGW).

## Choix de la voie principale (local-pref)
| Sens | Mecanisme | Valeur |
|---|---|---|
| Site -> AWS | local-preference sur le routeur client | DX = 200, VPN = 100 |
| AWS -> site | AWS prefere DX a VPN pour un meme prefixe ; communautes `7224:7300` (haute) sur le DX | DX prioritaire |

Extrait de configuration (routeur client, syntaxe type Cisco) :
```
route-map DX-IN permit 10
 set local-preference 200
route-map VPN-IN permit 10
 set local-preference 100
router bgp 65010
 neighbor 169.254.10.1 remote-as 64513
 neighbor 169.254.10.1 route-map DX-IN in
 neighbor 169.254.20.1 remote-as 64512
 neighbor 169.254.20.1 route-map VPN-IN in
```

## Bascule simulee
| Etape | Evenement | Chemin actif | Duree estimee |
|---|---|---|---|
| 0 | Nominal | DX (local-pref 200) | - |
| 1 | Coupure DX (BFD 300 ms x3) | detection | ~1 s |
| 2 | Retrait des routes DX, VPN (100) devient meilleur | VPN | 1 a 3 s (BGP + BFD) |
| 3 | Retour DX | DX | apres stabilisation |

## Debit (simulation)
| Voie | Debit nominal | Mesure simulee | Remarque |
|---|---|---|---|
| DX 1 Gbit/s | 1 000 Mbit/s | ~940 Mbit/s (TCP, MTU 1500) | jumbo 8500 possible vers TGW |
| VPN (1 tunnel) | jusqu'a 1,25 Gbit/s | ~300-500 Mbit/s (internet) | ECMP sur 2 tunnels possible |

Methode si un lien reel existait : `iperf3 -c <app-01> -P 4 -t 30` depuis le site.
