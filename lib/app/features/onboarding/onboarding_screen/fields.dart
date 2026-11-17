part of '../onboarding_screen.dart';

// Champs : langue, liste déroulante, téléphone avec indicatif.

// ─────────────────────────────────────────────────────────────────────────────
// Helpers
// ─────────────────────────────────────────────────────────────────────────────
class _LangBtn extends StatelessWidget {
  const _LangBtn({
    required this.label,
    required this.selected,
    required this.onTap,
  });
  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: KpbPressable(
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          padding: const EdgeInsets.symmetric(vertical: 12),
          decoration: BoxDecoration(
            color: selected ? KpbColors.actionPrimary : Colors.white,
            borderRadius: KpbRadius.mdBr,
            border: selected ? null : Border.all(color: KpbColors.border),
            boxShadow: selected ? KpbShadow.card : null,
          ),
          child: Center(
            child: Text(
              label,
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: selected ? Colors.white : KpbColors.textMuted,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _DD extends StatelessWidget {
  const _DD({
    required this.label,
    required this.value,
    required this.items,
    required this.onChanged,
    this.required = false,
  });
  final String label;

  /// Null tant que rien n'est choisi (onboarding V2) : le champ reste vide.
  final String? value;
  final List<(String, String)> items;
  final ValueChanged<String?> onChanged;

  /// Exigé pour continuer : l'erreur s'écrit dans le champ.
  final bool required;

  @override
  Widget build(BuildContext context) {
    return DropdownButtonFormField<String>(
      initialValue: value,
      decoration: InputDecoration(labelText: label),
      validator:
          required ? (v) => v == null ? 'field_required'.tr : null : null,
      items: items
          .map((e) =>
              DropdownMenuItem(value: e.$1, child: Text(_optionLabel(e.$1))))
          .toList(),
      onChanged: onChanged,
    );
  }
}

/// Contrôle du numéro, sans l'indicatif (choisi à gauche).
///
/// Un « + » tapé dans le numéro donnait « +227 +22790… », illisible pour
/// WhatsApp ; 7 à 12 chiffres couvrent les plans de numérotation du public
/// (Comores 7, Nigeria 10 ou 11, Côte d'Ivoire 10) sans accepter « 12 » ni une
/// ligne de chiffres collés (audit build 57, T1-10). Vide : seulement refusé
/// quand le champ est obligatoire.
///
/// [minDigits] et [maxDigits] viennent du pays de l'indicatif choisi
/// ([WorldCountry]) : quelques pays ont des mobiles plus courts (Andorre, 6
/// chiffres) ou plus longs (Autriche, 13), et les refuser reviendrait à ne
/// pas avoir leur indicatif.
String? validateOnboardingPhone(
  String? value, {
  required bool required,
  int minDigits = WorldCountry.defaultMinDigits,
  int maxDigits = WorldCountry.defaultMaxDigits,
}) {
  final text = value?.trim() ?? '';
  if (text.isEmpty) return required ? 'field_required'.tr : null;
  if (text.contains('+')) return 'phone_no_plus'.tr;
  final digits = text.replaceAll(RegExp(r'\D'), '');
  if (digits.length < minDigits || digits.length > maxDigits) {
    return 'phone_digits_range'
        .trParams({'min': '$minDigits', 'max': '$maxDigits'});
  }
  return null;
}

/// « Autre indicatif » : hors de la table `_dialCodes` (dont chaque `code`
/// est un indicatif propre) ; l'élève tape le sien (audit build 57, T1-10).
const _otherDialCode = _DialCode('🌍', '', 'Autre');

/// L'indicatif réellement enregistré : celui de la liste, ou celui tapé par
/// l'élève quand il a choisi « Autre indicatif ».
String _dialCodeOf(_DialCode code, TextEditingController custom) =>
    identical(code, _otherDialCode)
        ? '+${custom.text.replaceAll(RegExp(r'\D'), '')}'
        : code.code;

/// Indicatif tapé à la main : 1 à 4 chiffres, « + » facultatif.
String? validateCustomDialCode(String? value) {
  final text = value?.trim() ?? '';
  if (text.isEmpty) return 'field_required'.tr;
  if (!RegExp(r'^\+?\d{1,4}$').hasMatch(text)) {
    return 'dial_code_custom_invalid'.tr;
  }
  return null;
}

class _PhoneRow extends StatelessWidget {
  const _PhoneRow({
    required this.controller,
    required this.customCodeController,
    required this.dialCode,
    required this.label,
    required this.required,
    required this.onDialCode,
    this.dialCodeKey,
  });

  /// Clé du bouton d'indicatif (tests).
  final Key? dialCodeKey;
  final TextEditingController controller;
  final TextEditingController customCodeController;
  final _DialCode dialCode;
  final String label;
  final bool required;
  final ValueChanged<_DialCode> onDialCode;

  @override
  Widget build(BuildContext context) {
    final isOther = identical(dialCode, _otherDialCode);
    Future<void> pickDialCode() async {
      final pick = await showCountryPickerSheet(
        context,
        title: 'dial_code_picker_title'.tr,
        selectedIso2: dialCode.world?.iso2,
        otherSelected: isOther,
        showDialCodes: true,
        otherLabel: 'dial_code_other'.tr,
      );
      // Le formulaire a pu être quitté pendant que la feuille était ouverte.
      if (pick == null || !context.mounted) return;
      onDialCode(
          pick.isOther ? _otherDialCode : _dialCodeByIso2[pick.country!.iso2]!);
    }

    final row = Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Un bouton qui ouvre la liste de TOUS les indicatifs, avec une
        // recherche : le menu déroulant n'en proposait que 37.
        Semantics(
          button: true,
          label:
              '${'dial_code_picker_title'.tr} : ${isOther ? 'dial_code_other'.tr : '${dialCode.world!.nameFor(Get.locale?.languageCode)} ${dialCode.code}'}',
          excludeSemantics: true,
          // Le lecteur d'écran n'entend que ce libellé : l'action doit être
          // portée ici aussi, sinon le bouton s'annonce mais ne s'ouvre pas.
          onTap: pickDialCode,
          child: Material(
            color: Colors.white,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(KpbRadius.md),
              side: BorderSide(color: KpbColors.border),
            ),
            child: InkWell(
              key: dialCodeKey,
              borderRadius: BorderRadius.circular(KpbRadius.md),
              onTap: pickDialCode,
              child: SizedBox(
                height: 52,
                child: Padding(
                  padding: const EdgeInsets.only(left: 12, right: 4),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        isOther
                            ? '${dialCode.flag} ${'dial_code_other'.tr}'
                            : '${dialCode.flag} ${dialCode.code}',
                        style: const TextStyle(fontSize: 14),
                      ),
                      Icon(Icons.arrow_drop_down_rounded,
                          color: KpbColors.textMuted),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: TextFormField(
            controller: controller,
            keyboardType: TextInputType.phone,
            validator: (v) => validateOnboardingPhone(
              v,
              required: required,
              minDigits:
                  dialCode.world?.minDigits ?? WorldCountry.defaultMinDigits,
              maxDigits:
                  dialCode.world?.maxDigits ?? WorldCountry.defaultMaxDigits,
            ),
            decoration: InputDecoration(labelText: label),
          ),
        ),
      ],
    );
    if (!isOther) return row;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        row,
        const SizedBox(height: 8),
        TextFormField(
          key: const ValueKey('onboarding-custom-dial-code'),
          controller: customCodeController,
          keyboardType: TextInputType.phone,
          validator: validateCustomDialCode,
          decoration: InputDecoration(
            labelText: 'dial_code_custom_label'.tr,
            hintText: '+254',
          ),
        ),
      ],
    );
  }
}

/// Le pays de résidence : un champ qui ouvre la liste de TOUS les pays, avec
/// une recherche.
///
/// C'était une liste déroulante de 34 pays : un élève du Kenya ou d'Haïti
/// n'avait que « Autre ». La valeur enregistrée reste le nom français du pays
/// ([WorldCountry.nameFr]), celui que le serveur sait relire ; seul
/// l'affichage suit la langue de l'app.
class _CountryField extends StatelessWidget {
  const _CountryField({
    required this.value,
    required this.required,
    required this.onChanged,
  });

  /// Nul tant que rien n'est choisi (onboarding V2) : le champ reste vide.
  final String? value;

  /// Exigé pour continuer : l'erreur s'écrit dans le champ.
  final bool required;
  final ValueChanged<String?> onChanged;

  @override
  Widget build(BuildContext context) {
    return FormField<String>(
      key: const ValueKey('onboarding-country'),
      initialValue: value,
      validator: required
          ? (v) => (v == null || v.trim().isEmpty) ? 'field_required'.tr : null
          : null,
      builder: (field) {
        final current = field.value;
        final isOther = current == _otherCountry;
        final country = isOther ? null : worldCountryByName(current);
        final shown = current == null
            ? null
            : isOther
                ? '🌍 ${'country_other'.tr}'
                : country == null
                    ? current
                    : '${country.flag} ${country.nameFor(Get.locale?.languageCode)}';
        Future<void> pickCountry() async {
          final pick = await showCountryPickerSheet(
            context,
            title: 'country_picker_title'.tr,
            selectedIso2: country?.iso2,
            otherSelected: isOther,
            otherLabel: 'country_other'.tr,
          );
          if (pick == null || !field.mounted) return;
          final picked = pick.isOther ? _otherCountry : pick.country!.nameFr;
          field.didChange(picked);
          onChanged(picked);
        }

        return Semantics(
          button: true,
          label: shown == null ? 'country'.tr : '${'country'.tr} : $shown',
          excludeSemantics: true,
          onTap: pickCountry,
          child: InkWell(
            borderRadius: BorderRadius.circular(KpbRadius.md),
            onTap: pickCountry,
            child: InputDecorator(
              isEmpty: shown == null,
              decoration: InputDecoration(
                labelText: 'country'.tr,
                errorText: field.errorText,
                suffixIcon: const Icon(Icons.arrow_drop_down_rounded),
              ),
              child: shown == null ? null : Text(shown),
            ),
          ),
        );
      },
    );
  }
}
