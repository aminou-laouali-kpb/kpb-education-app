import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../data/world_countries.dart';
import '../app_tokens.dart';
import '../kpb_haptics.dart';

/// Le choix fait dans la feuille : un pays, ou la ligne « Autre ».
class CountryPick {
  const CountryPick.country(WorldCountry this.country);
  const CountryPick.other() : country = null;

  final WorldCountry? country;
  bool get isOther => country == null;
}

/// Feuille de choix d'un pays parmi TOUS les pays ([worldCountries]), avec
/// une recherche. Rend le choix, ou `null` si la feuille est refermée.
///
/// Une liste déroulante de 242 lignes ne se parcourt pas : la recherche
/// trouve « Kenya » en tapant « ken », « keny » sans accent, « 254 » ou
/// « ke ». Les pays du public de l'app restent en tête
/// ([priorityCountryIso2]) : la plupart des élèves choisissent sans taper.
///
/// - [showDialCodes] : affiche l'indicatif de chaque pays (choix de
///   l'indicatif du téléphone).
/// - [otherLabel] : non nul, ajoute en fin de liste une ligne « Autre »,
///   toujours visible — même quand la recherche ne trouve rien, il reste une
///   issue.
Future<CountryPick?> showCountryPickerSheet(
  BuildContext context, {
  required String title,
  String? selectedIso2,
  bool otherSelected = false,
  bool showDialCodes = false,
  String? otherLabel,
}) {
  return showModalBottomSheet<CountryPick>(
    context: context,
    isScrollControlled: true,
    backgroundColor: KpbColors.surface,
    builder: (sheetContext) => SafeArea(
      child: SizedBox(
        height: MediaQuery.of(sheetContext).size.height * 0.85,
        child: Padding(
          padding: EdgeInsets.only(
            left: KpbSpacing.page,
            right: KpbSpacing.page,
            top: KpbSpacing.md,
            bottom: MediaQuery.of(sheetContext).viewInsets.bottom,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Semantics(
                      header: true,
                      child: Text(title, style: KpbTextStyles.title),
                    ),
                  ),
                  IconButton(
                    tooltip:
                        MaterialLocalizations.of(sheetContext).closeButtonLabel,
                    icon: const Icon(Icons.close_rounded),
                    onPressed: () => Navigator.of(sheetContext).pop(),
                  ),
                ],
              ),
              const SizedBox(height: KpbSpacing.sm),
              Expanded(
                child: CountryPickerList(
                  selectedIso2: selectedIso2,
                  otherSelected: otherSelected,
                  showDialCodes: showDialCodes,
                  otherLabel: otherLabel,
                  onPicked: (pick) => Navigator.of(sheetContext).pop(pick),
                ),
              ),
            ],
          ),
        ),
      ),
    ),
  );
}

/// La recherche et la liste de [showCountryPickerSheet].
class CountryPickerList extends StatefulWidget {
  const CountryPickerList({
    super.key,
    required this.onPicked,
    this.selectedIso2,
    this.otherSelected = false,
    this.showDialCodes = false,
    this.otherLabel,
  });

  final ValueChanged<CountryPick> onPicked;
  final String? selectedIso2;
  final bool otherSelected;
  final bool showDialCodes;
  final String? otherLabel;

  @override
  State<CountryPickerList> createState() => _CountryPickerListState();
}

class _CountryPickerListState extends State<CountryPickerList> {
  final _query = TextEditingController();
  late final String? _language = Get.locale?.languageCode;
  late final List<WorldCountry> _all = worldCountriesInListOrder(_language);

  @override
  void dispose() {
    _query.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final searching = _query.text.trim().isNotEmpty;
    final visible = filterWorldCountries(_all, _query.text);
    final hasOther = widget.otherLabel != null;
    // Sans recherche, un filet sépare les pays mis en tête du reste de la
    // liste alphabétique : sinon « Canada » suivi d'« Afghanistan » ressemble
    // à un tri cassé.
    final dividerAfter = searching ? -1 : priorityCountryIso2.length - 1;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        TextField(
          key: const ValueKey('country-picker-search'),
          controller: _query,
          onChanged: (_) => setState(() {}),
          textInputAction: TextInputAction.search,
          autocorrect: false,
          decoration: InputDecoration(
            prefixIcon: const Icon(Icons.search_rounded),
            hintText: widget.showDialCodes
                ? 'country_picker_search_dial'.tr
                : 'country_picker_search'.tr,
          ),
        ),
        const SizedBox(height: KpbSpacing.sm),
        Expanded(
          child: ListView.builder(
            key: const ValueKey('country-picker-list'),
            keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
            itemCount:
                visible.length + (visible.isEmpty ? 1 : 0) + (hasOther ? 1 : 0),
            itemBuilder: (context, index) {
              if (visible.isEmpty && index == 0) {
                return Padding(
                  padding: const EdgeInsets.symmetric(vertical: KpbSpacing.md),
                  child: Text(
                    hasOther
                        ? 'country_picker_none_other'
                            .trParams({'other': widget.otherLabel!})
                        : 'country_picker_none'.tr,
                    style: KpbTextStyles.bodySm,
                  ),
                );
              }
              if (index >= visible.length) {
                return _CountryRow(
                  key: const ValueKey('country-picker-other'),
                  flag: '🌍',
                  name: widget.otherLabel!,
                  selected: widget.otherSelected,
                  onTap: () => widget.onPicked(const CountryPick.other()),
                );
              }
              final country = visible[index];
              final row = _CountryRow(
                key: ValueKey<String>('country-picker-${country.iso2}'),
                flag: country.flag,
                name: country.nameFor(_language),
                dialCode: widget.showDialCodes ? country.dialCode : null,
                selected: !widget.otherSelected &&
                    country.iso2 == widget.selectedIso2,
                onTap: () => widget.onPicked(CountryPick.country(country)),
              );
              if (index != dividerAfter) return row;
              return Column(
                mainAxisSize: MainAxisSize.min,
                children: [row, const Divider(height: KpbSpacing.md)],
              );
            },
          ),
        ),
      ],
    );
  }
}

class _CountryRow extends StatelessWidget {
  const _CountryRow({
    super.key,
    required this.flag,
    required this.name,
    required this.selected,
    required this.onTap,
    this.dialCode,
  });

  final String flag;
  final String name;
  final String? dialCode;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      selected: selected,
      label: dialCode == null ? name : '$name, $dialCode',
      excludeSemantics: true,
      onTap: onTap,
      child: Material(
        color: selected ? KpbColors.actionPrimarySoft : Colors.transparent,
        borderRadius: BorderRadius.circular(KpbRadius.md),
        child: InkWell(
          borderRadius: BorderRadius.circular(KpbRadius.md),
          onTap: () {
            KpbHaptics.selection();
            onTap();
          },
          child: ConstrainedBox(
            constraints: const BoxConstraints(minHeight: 48),
            child: Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: KpbSpacing.sm,
                vertical: KpbSpacing.sm,
              ),
              child: Row(
                children: [
                  Text(flag, style: const TextStyle(fontSize: 22)),
                  const SizedBox(width: KpbSpacing.md),
                  Expanded(child: Text(name, style: KpbTextStyles.body)),
                  if (dialCode != null) ...[
                    const SizedBox(width: KpbSpacing.sm),
                    Text(
                      dialCode!,
                      style: KpbTextStyles.body.copyWith(
                        color: KpbColors.textSecondary,
                        fontFeatures: const [FontFeature.tabularFigures()],
                      ),
                    ),
                  ],
                  if (selected) ...[
                    const SizedBox(width: KpbSpacing.sm),
                    const Icon(
                      Icons.check_rounded,
                      size: 20,
                      color: KpbColors.actionPrimary,
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
