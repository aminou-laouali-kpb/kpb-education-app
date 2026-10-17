// Budget des débordements d'écran, par cas — même patron que color_budget.dart.
//
// MESURÉ le 14/08/2026 sur Flutter 3.44.1, par
// test/core/ui/screen_matrix_test.dart : 20 surfaces × 2 téléphones × 3 échelles
// de texte = 120 cas. Les 108 cas absents de cette table valent zéro.
// (16/10/2026, build 57 : plafond de police relevé de 1,3 à 1,5, quatrième
// échelle ajoutée, OnboardingScreen et AhaMomentScreen ajoutés → 22 surfaces,
// 176 cas, tous à zéro après correction du bouton de l'écran « aha ».)
// (17/10/2026, communauté C1 + C2 : CommunityHubScreen, CommunityComposerScreen
// et CommunityPostScreen ajoutés → 25 surfaces, 200 cas, tous à zéro.)
// (Revérifié le 15/08/2026 après les masquages M1/M2 : mêmes 20 surfaces, mêmes
// 14 cas budgétés.)
//
// La clé est `<écran>@<téléphone>@<échelle>`, la valeur est le NOMBRE d'objets de
// rendu qui débordent — pas le nombre de pixels.
//
// POURQUOI DES COMPTES ET PAS DES PIXELS. Le nombre de pixels dépend des métriques
// de police, et le dépôt sait déjà que « le rendu de police Linux diffère »
// (c'est la raison pour laquelle les goldens sont exclues de la CI,
// flutter-ci.yml:89 et architecture §11.5). Un budget en pixels rougirait en CI
// sans qu'une ligne ait bougé. Un compte, lui, est structurel : trois cartes qui
// débordent débordent sur les deux systèmes. Les pixels sont conservés en
// commentaire, pour l'humain qui corrige.
//
// Règle du cliquet, dans les deux sens :
//   · un cas qui dépasse son budget fait ÉCHOUER la CI ;
//   · un cas tombé à ZÉRO fait aussi échouer, avec le message « abaissez le
//     budget » — sinon un correctif de lot 6-8 se perdrait et le budget
//     deviendrait une excuse permanente. Seul le passage à zéro déclenche ce
//     second test : une oscillation de 3 à 2 due aux métriques de police ne doit
//     pas rougir la CI.
//
// CE QUE CE BUDGET DIT, EN FRANÇAIS. Aucune surface ne déborde : les 25
// surfaces × 2 téléphones × 4 échelles = 200 cas sont à zéro.
//
// AuthWelcomeScreen (trouvailles du harnais, 44 px / 38 px à l'échelle 1,3)
// a été corrigé au lot 9 : colonne défilable, plus de Spacer dans une hauteur
// non bornée. Les trois autres (France, Universités, Logement) l'avaient été
// au lot 8.
//
// Les 19 autres surfaces — les 5 onglets, les 4 outils que le tiroir propose
// aujourd'hui, les 4 écrans IA masqués par M1 (retirés de la navigation, gardés
// sous mesure), le tiroir lui-même, les deux écrans de lien magique, le chat —
// et les trois écrans corrigés par le lot 8 ne débordent à aucune taille ni
// aucune échelle. Et aucune des 176 combinaisons n'affiche de clé de
// traduction brute.
//
// LE COMPTE EST RESTÉ À 20 SURFACES À TRAVERS LE MASQUAGE, et ce n'est pas une
// coïncidence : le lot 7 a retiré quatre outils du tiroir et la matrice les a
// repris nommément (`ai:…` dans screen_matrix_test.dart). Sans ce rattrapage,
// la couverture serait tombée à 16 surfaces le jour du masquage — et serait
// remontée à 20 le jour où le drapeau rebascule, sur quatre écrans que plus
// rien n'aurait mesuré entre-temps.

/// Nombre d'objets de rendu qui débordent, par cas. Absent = 0.
/// Lot 9 : AuthWelcomeScreen ne déborde plus (colonne défilable, plus de Spacer
/// non borné). Le cliquet exige que ce tableau soit vide — un retour du
/// débordement à l'échelle 1,3 ou 1,5 ferait échouer la matrice, et un budget
/// laissé à 1 après un zéro mesuré ferait échouer avec « abaissez le budget ».
const screenOverflowBudget = <String, int>{};

/// Les cas dont on sait pourquoi ils débordent, avec le constat d'audit
/// correspondant. Sert au message d'échec : un développeur qui voit rougir un cas
/// déjà connu doit le comprendre en une ligne, et un cas SANS entrée ici est une
/// régression toute neuve.
const screenOverflowKnownCauses = <String, String>{};

/// Le total, pour que le message de synthèse ne puisse pas être approximatif.
const screenOverflowCaseCount = 0;
const screenMatrixCaseCount = 200;
