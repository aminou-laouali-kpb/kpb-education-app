import 'package:flutter/material.dart';

import 'app_tokens.dart';
import 'kpb_theme_ext.dart';

/// L1 de l'architecture de thème (docs/fable-global-theme-architecture.md §7) :
/// dérive intégralement des tokens de app_tokens.dart — aucun hexadécimal ici
/// (vérifié par le test ratchet). Les écrans consomment ce ThemeData
/// implicitement (widgets Material) ou via `context.kpb` (rôles sémantiques).
class AppTheme {
  /// Mode sombre : compilable, NON conçu ni exposé pour cette livraison
  /// (light-only) — `main.dart` ne le branche pas.
  static ThemeData buildDarkTheme() {
    return ThemeData(
      useMaterial3: true,
      // App-engagement handoff: Inter for body/UI text (headings use
      // PlusJakartaSans via KpbTextStyles).
      fontFamily: KpbTextStyles.bodyFamily,
      splashFactory: InkRipple.splashFactory,
      extensions: const [KpbThemeColors.dark],
      colorScheme: ColorScheme.fromSeed(
        seedColor: KpbColors.actionPrimary,
        primary: KpbColors.decorSky,
        secondary: KpbColors.decorSky,
        tertiary: KpbColors.gold,
        surface: KpbColorsDark.cardBg,
        onPrimary: Colors.white,
        onSecondary: Colors.white,
        onSurface: Colors.white,
        error: KpbColors.error,
        brightness: Brightness.dark,
      ),
      scaffoldBackgroundColor: KpbColorsDark.pageBg,
      appBarTheme: const AppBarTheme(
        backgroundColor: Colors.transparent,
        foregroundColor: Colors.white,
        elevation: 0,
        surfaceTintColor: Colors.transparent,
        centerTitle: false,
        titleTextStyle: TextStyle(
          fontFamily: KpbTextStyles.headingFamily,
          fontSize: KpbFontSize.xl,
          fontWeight: FontWeight.w700,
          color: Colors.white,
        ),
      ),
      cardTheme: const CardThemeData(
        elevation: 0,
        margin: EdgeInsets.zero,
        color: KpbColorsDark.cardBg,
        shadowColor: Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: KpbRadius.lgBr,
        ),
      ),
      chipTheme: ChipThemeData(
        shape: const RoundedRectangleBorder(
          borderRadius: KpbRadius.pillBr,
        ),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        checkmarkColor: Colors.white,
        color: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return KpbColors.actionPrimary;
          }
          return KpbColorsDark.divider;
        }),
        // Même piège que le thème clair (cf. commentaire détaillé dans
        // buildTheme) : la couleur d'état se porte sur `labelStyle.color`,
        // jamais via un WidgetStateTextStyle que RawChip ignorerait.
        labelStyle: TextStyle(
          fontFamily: KpbTextStyles.bodyFamily,
          fontWeight: FontWeight.w600,
          fontSize: KpbFontSize.sm,
          color: WidgetStateColor.resolveWith((states) {
            if (states.contains(WidgetState.selected)) return Colors.white;
            if (states.contains(WidgetState.disabled)) {
              return KpbColorsDark.textSecondary;
            }
            // 11,99:1 sur KpbColorsDark.divider.
            return KpbColorsDark.textPrimary;
          }),
        ),
        side: BorderSide.none,
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: KpbColorsDark.inputBg,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(KpbRadius.md),
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(KpbRadius.md),
          borderSide: const BorderSide(color: KpbColorsDark.border),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(KpbRadius.md),
          borderSide: const BorderSide(color: KpbColors.decorSky, width: 1.5),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(KpbRadius.md),
          borderSide: const BorderSide(color: KpbColors.error),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(KpbRadius.md),
          borderSide: const BorderSide(color: KpbColors.error, width: 1.5),
        ),
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        labelStyle: const TextStyle(color: KpbColorsDark.textSecondary),
        hintStyle: const TextStyle(color: KpbColorsDark.textMuted),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: KpbColors.actionPrimary,
          foregroundColor: Colors.white,
          minimumSize: const Size.fromHeight(52),
          shape: const RoundedRectangleBorder(
            borderRadius: KpbRadius.mdBr,
          ),
          textStyle: const TextStyle(
            fontFamily: KpbTextStyles.bodyFamily,
            fontSize: KpbFontSize.md,
            fontWeight: FontWeight.w600,
          ),
          elevation: 0,
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: KpbColors.decorSky,
          minimumSize: const Size.fromHeight(52),
          shape: const RoundedRectangleBorder(
            borderRadius: KpbRadius.mdBr,
          ),
          side: const BorderSide(color: KpbColors.decorSky),
          textStyle: const TextStyle(
            fontFamily: KpbTextStyles.bodyFamily,
            fontSize: KpbFontSize.md,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: KpbColors.decorSky,
          textStyle: const TextStyle(
            fontFamily: KpbTextStyles.bodyFamily,
            fontSize: KpbFontSize.sm,
            fontWeight: FontWeight.w600,
          ),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
          minimumSize:
              const Size(kMinInteractiveDimension, kMinInteractiveDimension),
          tapTargetSize: MaterialTapTargetSize.padded,
        ),
      ),
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: KpbColorsDark.cardBg,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        shadowColor: KpbColorsDark.scrim,
        indicatorColor: KpbColors.actionPrimary.withAlpha(60),
        iconTheme: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return const IconThemeData(color: KpbColors.decorSky, size: 22);
          }
          return const IconThemeData(color: KpbColorsDark.textMuted, size: 22);
        }),
        labelTextStyle: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return const TextStyle(
                color: KpbColors.decorSky,
                fontSize: KpbFontSize.xs,
                fontWeight: FontWeight.w600);
          }
          return const TextStyle(
              color: KpbColorsDark.textMuted,
              fontSize: KpbFontSize.xs,
              fontWeight: FontWeight.w500);
        }),
      ),
      dividerTheme: const DividerThemeData(
        color: KpbColorsDark.divider,
        thickness: 1,
        space: 1,
      ),
      listTileTheme: const ListTileThemeData(
        contentPadding: EdgeInsets.symmetric(horizontal: KpbSpacing.md),
      ),
      bottomSheetTheme: const BottomSheetThemeData(
        backgroundColor: KpbColorsDark.cardBg,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius:
              BorderRadius.vertical(top: Radius.circular(KpbRadius.xl)),
        ),
        showDragHandle: true,
      ),
      switchTheme: SwitchThemeData(
        thumbColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) return Colors.white;
          return KpbColorsDark.textMuted;
        }),
        trackColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return KpbColors.actionPrimary;
          }
          return KpbColorsDark.border;
        }),
      ),
      checkboxTheme: CheckboxThemeData(
        fillColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return KpbColors.actionPrimary;
          }
          return Colors.transparent;
        }),
        side: const BorderSide(color: KpbColorsDark.gray300, width: 1.5),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
      ),
      progressIndicatorTheme: const ProgressIndicatorThemeData(
        color: KpbColors.decorSky,
        linearTrackColor: KpbColorsDark.divider,
        linearMinHeight: 8,
      ),
      textTheme: const TextTheme(
        displayLarge: KpbTextStyles.display,
        headlineMedium: KpbTextStyles.headline,
        titleLarge: KpbTextStyles.title,
        titleMedium: KpbTextStyles.titleMd,
        bodyLarge: KpbTextStyles.body,
        bodyMedium: KpbTextStyles.body,
        bodySmall: KpbTextStyles.bodySm,
        labelLarge: KpbTextStyles.label,
        labelSmall: KpbTextStyles.caption,
      ),
    );
  }

  static ThemeData buildTheme() {
    return ThemeData(
      useMaterial3: true,
      // Inter pour le corps/UI ; les titres passent en Plus Jakarta Sans via
      // les styles KpbTextStyles (leur fontFamily explicite gagne au merge).
      fontFamily: KpbTextStyles.bodyFamily,
      // InkSparkle (défaut M3 Android) coûte un shader — InkRipple reste
      // fluide sur les appareils d'entrée de gamme.
      splashFactory: InkRipple.splashFactory,
      extensions: const [KpbThemeColors.light],

      // ── ColorScheme (explicite — pas de fromSeed : rôles maîtrisés) ──────
      colorScheme: const ColorScheme(
        brightness: Brightness.light,
        primary: KpbColors.actionPrimary,
        onPrimary: Colors.white,
        primaryContainer: KpbColors.actionPrimarySoft,
        onPrimaryContainer: KpbColors.actionPrimaryPressed,
        secondary: KpbColors.brandNavy,
        onSecondary: Colors.white,
        tertiary: KpbColors.gold,
        onTertiary: KpbColors.brandNavy,
        error: KpbColors.error,
        onError: Colors.white,
        errorContainer: KpbColors.errorLight,
        onErrorContainer: KpbColors.error,
        surface: KpbColors.surface,
        onSurface: KpbColors.textPrimary,
        onSurfaceVariant: KpbColors.textSecondary,
        outline: KpbColors.border,
        outlineVariant: KpbColors.surfaceMuted,
        // Tue la teinte M3 sur les surfaces élevées : les cartes restent
        // blanches quel que soit leur elevation.
        surfaceTint: Colors.transparent,
        inverseSurface: KpbColors.brandNavy,
        onInverseSurface: Colors.white,
        inversePrimary: KpbColors.actionOnDark,
        shadow: Colors.black,
        scrim: Colors.black,
      ),
      scaffoldBackgroundColor: KpbColors.canvas,

      // ── AppBar ──────────────────────────────────────────────────────────
      appBarTheme: const AppBarTheme(
        backgroundColor: Colors.transparent,
        foregroundColor: KpbColors.textPrimary,
        elevation: 0,
        surfaceTintColor: Colors.transparent,
        centerTitle: false,
        titleTextStyle: TextStyle(
          fontFamily: KpbTextStyles.headingFamily,
          fontSize: KpbFontSize.xl,
          fontWeight: FontWeight.w700,
          color: KpbColors.textPrimary,
        ),
      ),

      // ── Cards ───────────────────────────────────────────────────────────
      // Elevation 0 + bordure : l'ombre douce vient de KpbCard (KpbShadow),
      // pas du Material.elevation.
      cardTheme: const CardThemeData(
        elevation: 0,
        margin: EdgeInsets.zero,
        color: KpbColors.surface,
        shadowColor: Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: KpbRadius.lgBr,
          side: BorderSide(color: KpbColors.border),
        ),
      ),

      // ── Chips ───────────────────────────────────────────────────────────
      // Sélectionnée : action pleine, label blanc (5,17:1). Repos : surface
      // muted + bordure appuyée, label textPrimary (16,30:1) — jamais de
      // gris-sur-gris illisible.
      //
      // ⚠️ PIÈGE FLUTTER — ne pas remettre un `WidgetStateTextStyle` ici.
      // `RawChip` ne résout PAS le labelStyle par état : il ne résout que le
      // *champ* `labelStyle.color` (chip.dart : `resolveAs(effectiveLabelStyle
      // .color, states)`). Un `WidgetStateTextStyle` « se comporte comme un
      // TextStyle() vide s'il est utilisé comme TextStyle ordinaire » (doc
      // Flutter) : couleur, taille et graisse partaient donc à null, et le
      // moteur retombait sur sa couleur par défaut — du BLANC. Résultat en
      // prod : label blanc sur fond clair (1,10:1, invisible) au repos, alors
      // que l'état sélectionné semblait parfait (blanc sur bleu). D'où la
      // couleur d'état portée par le champ `color`, seul point que RawChip lit.
      chipTheme: ChipThemeData(
        shape: const RoundedRectangleBorder(
          borderRadius: KpbRadius.pillBr,
        ),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        checkmarkColor: Colors.white,
        color: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return KpbColors.actionPrimary;
          }
          return KpbColors.surfaceMuted;
        }),
        labelStyle: TextStyle(
          fontFamily: KpbTextStyles.bodyFamily,
          fontWeight: FontWeight.w600,
          fontSize: KpbFontSize.sm,
          color: WidgetStateColor.resolveWith((states) {
            if (states.contains(WidgetState.selected)) return Colors.white;
            // Désactivée : atténuée mais encore lisible (6,92:1) — textMuted
            // tomberait à 4,34:1 sur surfaceMuted.
            if (states.contains(WidgetState.disabled)) {
              return KpbColors.textSecondary;
            }
            return KpbColors.textPrimary;
          }),
        ),
        side: WidgetStateBorderSide.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return const BorderSide(color: Colors.transparent);
          }
          // borderStrong (pas border) : la pastille au repos doit se détacher
          // du canvas, y compris en plein soleil sur écran d'entrée de gamme.
          return const BorderSide(color: KpbColors.borderStrong, width: 1);
        }),
      ),

      // ── Inputs ──────────────────────────────────────────────────────────
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: KpbColors.surface,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(KpbRadius.md),
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(KpbRadius.md),
          borderSide: const BorderSide(color: KpbColors.border),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(KpbRadius.md),
          borderSide:
              const BorderSide(color: KpbColors.actionPrimary, width: 1.5),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(KpbRadius.md),
          borderSide: const BorderSide(color: KpbColors.error),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(KpbRadius.md),
          borderSide: const BorderSide(color: KpbColors.error, width: 1.5),
        ),
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        labelStyle: const TextStyle(color: KpbColors.textSecondary),
        hintStyle: const TextStyle(color: KpbColors.textMuted),
      ),

      // ── Buttons ─────────────────────────────────────────────────────────
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: KpbColors.actionPrimary,
          foregroundColor: Colors.white,
          disabledBackgroundColor: KpbColors.surfaceMuted,
          disabledForegroundColor: KpbColors.textFaint,
          overlayColor: KpbColors.actionPrimaryPressed,
          minimumSize: const Size.fromHeight(52),
          shape: const RoundedRectangleBorder(
            borderRadius: KpbRadius.mdBr,
          ),
          textStyle: const TextStyle(
            fontFamily: KpbTextStyles.bodyFamily,
            fontSize: KpbFontSize.md,
            fontWeight: FontWeight.w600,
          ),
          elevation: 0,
        ),
      ),

      // Miroir de FilledButton : rattrape les call-sites ElevatedButton
      // hérités sans les migrer un par un.
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: KpbColors.actionPrimary,
          foregroundColor: Colors.white,
          disabledBackgroundColor: KpbColors.surfaceMuted,
          disabledForegroundColor: KpbColors.textFaint,
          overlayColor: KpbColors.actionPrimaryPressed,
          minimumSize: const Size.fromHeight(52),
          shape: const RoundedRectangleBorder(
            borderRadius: KpbRadius.mdBr,
          ),
          textStyle: const TextStyle(
            fontFamily: KpbTextStyles.bodyFamily,
            fontSize: KpbFontSize.md,
            fontWeight: FontWeight.w600,
          ),
          elevation: 0,
          shadowColor: Colors.transparent,
        ),
      ),

      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: KpbColors.textPrimary,
          backgroundColor: KpbColors.surface,
          minimumSize: const Size.fromHeight(52),
          shape: const RoundedRectangleBorder(
            borderRadius: KpbRadius.mdBr,
          ),
          side: const BorderSide(color: KpbColors.borderStrong),
          textStyle: const TextStyle(
            fontFamily: KpbTextStyles.bodyFamily,
            fontSize: KpbFontSize.md,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),

      // Cible tactile d'au moins 48 × 48 dp (WCAG 2.5.5 / Material) : un
      // TextButton isolé était à 22 dp de haut. Un lien inline dans un
      // contexte dense peut encore passer `minimumSize`/`tapTargetSize` en
      // local — jamais pour une action isolée.
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: KpbColors.actionPrimary,
          textStyle: const TextStyle(
            fontFamily: KpbTextStyles.bodyFamily,
            fontSize: KpbFontSize.sm,
            fontWeight: FontWeight.w600,
          ),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
          minimumSize:
              const Size(kMinInteractiveDimension, kMinInteractiveDimension),
          tapTargetSize: MaterialTapTargetSize.padded,
        ),
      ),

      // ── Navigation ───────────────────────────────────────────────────────
      // NB : la nav flottante custom du shell étudiant ne lit pas ce thème ;
      // il reste la référence pour toute NavigationBar Material standard.
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: KpbColors.surface,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        shadowColor: KpbShadow.scrimLight,
        indicatorColor: KpbColors.actionPrimarySoft,
        iconTheme: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return const IconThemeData(
                color: KpbColors.actionPrimary, size: 22);
          }
          // textMuted (pas textFaint) : icônes porteuses de sens ⇒ ≥ 3:1.
          return const IconThemeData(color: KpbColors.textMuted, size: 22);
        }),
        labelTextStyle: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return const TextStyle(
              fontFamily: KpbTextStyles.bodyFamily,
              color: KpbColors.actionPrimary,
              fontSize: KpbFontSize.xs,
              fontWeight: FontWeight.w600,
            );
          }
          return const TextStyle(
            fontFamily: KpbTextStyles.bodyFamily,
            color: KpbColors.textMuted,
            fontSize: KpbFontSize.xs,
            fontWeight: FontWeight.w500,
          );
        }),
      ),

      // ── Dividers ─────────────────────────────────────────────────────────
      dividerTheme: const DividerThemeData(
        color: KpbColors.surfaceMuted,
        thickness: 1,
        space: 1,
      ),

      // ── ListTile ──────────────────────────────────────────────────────────
      listTileTheme: const ListTileThemeData(
        contentPadding: EdgeInsets.symmetric(horizontal: KpbSpacing.md),
        iconColor: KpbColors.textSecondary,
      ),

      // ── Icônes ────────────────────────────────────────────────────────────
      iconTheme: const IconThemeData(color: KpbColors.textSecondary),

      // ── BottomSheet ──────────────────────────────────────────────────────
      bottomSheetTheme: const BottomSheetThemeData(
        backgroundColor: KpbColors.surface,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(
            top: Radius.circular(KpbRadius.xl),
          ),
        ),
        showDragHandle: true,
      ),

      // ── Dialog ────────────────────────────────────────────────────────────
      dialogTheme: const DialogThemeData(
        backgroundColor: KpbColors.surface,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(borderRadius: KpbRadius.lgBr),
        titleTextStyle: KpbTextStyles.title,
        contentTextStyle: KpbTextStyles.body,
      ),

      // ── SnackBar ──────────────────────────────────────────────────────────
      snackBarTheme: const SnackBarThemeData(
        backgroundColor: KpbColors.brandNavy,
        contentTextStyle: TextStyle(
          color: Colors.white,
          fontSize: KpbFontSize.sm,
          fontFamily: KpbTextStyles.bodyFamily,
        ),
        actionTextColor: KpbColors.actionOnDark,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: KpbRadius.smBr),
      ),

      // ── TabBar ────────────────────────────────────────────────────────────
      tabBarTheme: const TabBarThemeData(
        labelColor: KpbColors.actionPrimary,
        unselectedLabelColor: KpbColors.textMuted,
        indicatorColor: KpbColors.actionPrimary,
        dividerColor: KpbColors.border,
        labelStyle: TextStyle(
            fontFamily: KpbTextStyles.bodyFamily,
            fontSize: KpbFontSize.sm,
            fontWeight: FontWeight.w600),
        unselectedLabelStyle: TextStyle(
            fontFamily: KpbTextStyles.bodyFamily,
            fontSize: KpbFontSize.sm,
            fontWeight: FontWeight.w500),
      ),

      // ── Tooltip ───────────────────────────────────────────────────────────
      tooltipTheme: TooltipThemeData(
        decoration: BoxDecoration(
          color: KpbColors.brandNavy.withValues(alpha: 0.92),
          borderRadius: KpbRadius.smBr,
        ),
        textStyle: const TextStyle(
            fontFamily: KpbTextStyles.bodyFamily,
            color: Colors.white,
            fontSize: KpbFontSize.xs),
      ),

      // ── Menus ─────────────────────────────────────────────────────────────
      popupMenuTheme: const PopupMenuThemeData(
        color: KpbColors.surface,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: KpbRadius.smBr,
          side: BorderSide(color: KpbColors.border),
        ),
      ),

      // ── Drawer ────────────────────────────────────────────────────────────
      drawerTheme: const DrawerThemeData(
        backgroundColor: KpbColors.canvas,
        surfaceTintColor: Colors.transparent,
      ),

      // ── FAB ───────────────────────────────────────────────────────────────
      // Le Coach FAB garde son navy distinctif (choix produit, via token).
      floatingActionButtonTheme: const FloatingActionButtonThemeData(
        backgroundColor: KpbColors.actionPrimary,
        foregroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: KpbRadius.mdBr),
      ),

      // ── Switch / Checkbox / Radio ─────────────────────────────────────────
      switchTheme: SwitchThemeData(
        thumbColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) return Colors.white;
          return KpbColors.borderStrong;
        }),
        trackColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return KpbColors.actionPrimary;
          }
          return KpbColors.border;
        }),
      ),
      checkboxTheme: CheckboxThemeData(
        fillColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return KpbColors.actionPrimary;
          }
          return Colors.transparent;
        }),
        side: const BorderSide(color: KpbColors.borderStrong, width: 1.5),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
      ),
      radioTheme: RadioThemeData(
        fillColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return KpbColors.actionPrimary;
          }
          return KpbColors.borderStrong;
        }),
      ),

      // ── SegmentedButton ───────────────────────────────────────────────────
      segmentedButtonTheme: SegmentedButtonThemeData(
        style: ButtonStyle(
          backgroundColor: WidgetStateProperty.resolveWith((states) {
            if (states.contains(WidgetState.selected)) {
              return KpbColors.actionPrimarySoft;
            }
            return KpbColors.surface;
          }),
          foregroundColor: WidgetStateProperty.resolveWith((states) {
            if (states.contains(WidgetState.selected)) {
              return KpbColors.actionPrimary;
            }
            return KpbColors.textSecondary;
          }),
          side: const WidgetStatePropertyAll(
            BorderSide(color: KpbColors.border),
          ),
        ),
      ),

      // ── Progress ──────────────────────────────────────────────────────────
      progressIndicatorTheme: const ProgressIndicatorThemeData(
        color: KpbColors.actionPrimary,
        linearTrackColor: KpbColors.surfaceMuted,
        linearMinHeight: 8,
      ),

      // ── Badge ─────────────────────────────────────────────────────────────
      badgeTheme: const BadgeThemeData(
        backgroundColor: KpbColors.error,
        textColor: Colors.white,
      ),

      // ── Text ─────────────────────────────────────────────────────────────
      // Titres (display/headline/title L) en Plus Jakarta Sans ; le reste en
      // Inter via le fontFamily global. Tailles issues de KpbFontSize.
      textTheme: const TextTheme(
        displayLarge: KpbTextStyles.display,
        displayMedium: KpbTextStyles.displaySm,
        displaySmall: KpbTextStyles.displayXs,
        headlineLarge: KpbTextStyles.headlineLg,
        headlineMedium: KpbTextStyles.headline,
        headlineSmall: KpbTextStyles.headlineSm,
        titleLarge: KpbTextStyles.title,
        titleMedium: KpbTextStyles.titleMd,
        titleSmall: KpbTextStyles.titleSm,
        bodyLarge: KpbTextStyles.body,
        bodyMedium: KpbTextStyles.body,
        bodySmall: KpbTextStyles.bodySm,
        labelLarge: KpbTextStyles.label,
        labelMedium: KpbTextStyles.labelSm,
        labelSmall: KpbTextStyles.caption,
      ),
    );
  }
}
