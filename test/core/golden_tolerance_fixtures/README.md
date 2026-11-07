# Paires de calibrage du comparateur de goldens

Quatre PNG 390×844, deux paires (référence, rendu). Chaque paire est un VRAI cas
de bruit d'anti-crénelage entre deux Mac : mêmes widgets, mêmes polices, aucune
régression — et pourtant ni l'une ni l'autre n'est identique octet pour octet.
`test/core/golden_tolerance_test.dart` exige que le comparateur tolérant les
accepte, et qu'il refuse les mutations appliquées par-dessus.

| Paire | Référence | Rendu |
|---|---|---|
| `pair_2026-10-02_*` | `test/goldens/theme_gallery.png` tel que committé en `5ceed5ec` (02/10/2026) | rendu du code de `5d86628` sur macOS 27.0.1, Flutter 3.44.1 |
| `pair_2026-08-08_*` | `test/goldens/theme_gallery.png` d'avant `5ceed5ec` (08/08/2026, #193) | rendu du code de `33c5a51` sur la même machine |

Écarts mesurés : 728 px (0,22 %) et 628 px (0,19 %), écart médian 3/255, aucun
pixel dans un aplat.

Ces fichiers sont GELÉS : ils ne suivent pas `test/goldens/theme_gallery.png`.
Ne pas les régénérer quand le golden change — c'est précisément ce qu'ils
protègent. Pour en ajouter une paire, copier `masterImage` et `testImage` du
dossier `test/goldens/failures/` produit par un golden en échec.
