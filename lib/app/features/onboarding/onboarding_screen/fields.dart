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
String? validateOnboardingPhone(String? value, {required bool required}) {
  final text = value?.trim() ?? '';
  if (text.isEmpty) return required ? 'field_required'.tr : null;
  if (text.contains('+')) return 'phone_no_plus'.tr;
  final digits = text.replaceAll(RegExp(r'\D'), '');
  if (digits.length < 7 || digits.length > 12) return 'phone_digits_range'.tr;
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
  });
  final TextEditingController controller;
  final TextEditingController customCodeController;
  final _DialCode dialCode;
  final String label;
  final bool required;
  final ValueChanged<_DialCode> onDialCode;

  @override
  Widget build(BuildContext context) {
    final row = Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          height: 52,
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(KpbRadius.md),
            border: Border.all(color: KpbColors.border),
          ),
          child: DropdownButtonHideUnderline(
            child: DropdownButton<_DialCode>(
              value: dialCode,
              isDense: true,
              padding: const EdgeInsets.symmetric(horizontal: 10),
              items: [..._dialCodes, _otherDialCode]
                  .map((d) => DropdownMenuItem(
                        value: d,
                        child: Text(
                          identical(d, _otherDialCode)
                              ? '${d.flag} ${'dial_code_other'.tr}'
                              : d.label,
                          style: const TextStyle(fontSize: 14),
                        ),
                      ))
                  .toList(),
              onChanged: (v) {
                if (v != null) onDialCode(v);
              },
            ),
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: TextFormField(
            controller: controller,
            keyboardType: TextInputType.phone,
            validator: (v) => validateOnboardingPhone(v, required: required),
            decoration: InputDecoration(labelText: label),
          ),
        ),
      ],
    );
    if (!identical(dialCode, _otherDialCode)) return row;
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
