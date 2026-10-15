import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../../core/models/scholarship_match.dart';
import '../../../core/ui/app_tokens.dart';
import 'match_choice.dart';

/// Minuscules, sans accents : « cote » trouve « Côte d'Ivoire ».
String matchFoldForSearch(String raw) {
  const accents = 'àáâäãåèéêëìíîïòóôöõùúûüçñ';
  const plain = 'aaaaaaeeeeiiiiooooouuuucn';
  final buffer = StringBuffer();
  for (final rune in raw.toLowerCase().runes) {
    final char = String.fromCharCode(rune);
    final i = accents.indexOf(char);
    buffer.write(i == -1 ? char : plain[i]);
  }
  return buffer.toString().replaceAll('’', "'").trim();
}

/// Les pays servis par le serveur, filtrés par la recherche (les prioritaires
/// d'abord, déjà triés par le modèle).
List<MatchCountryOption> filterMatchCountries(
  List<MatchCountryOption> countries,
  String query,
) {
  final needle = matchFoldForSearch(query);
  if (needle.isEmpty) return countries;
  return countries
      .where((c) =>
          matchFoldForSearch(c.name).contains(needle) || c.code == needle)
      .toList(growable: false);
}

/// La liste des pays SERVIE (`options.countries`), avec une recherche. Les
/// pays d'Afrique de l'Ouest et centrale francophone viennent en tête.
class MatchCountryList extends StatefulWidget {
  const MatchCountryList({
    super.key,
    required this.countries,
    required this.selected,
    required this.onSelected,
    this.searchKey,
  });

  final List<MatchCountryOption> countries;
  final String? selected;
  final ValueChanged<String> onSelected;
  final Key? searchKey;

  @override
  State<MatchCountryList> createState() => _MatchCountryListState();
}

class _MatchCountryListState extends State<MatchCountryList> {
  final _query = TextEditingController();

  @override
  void dispose() {
    _query.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final visible = filterMatchCountries(widget.countries, _query.text);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        TextField(
          key: widget.searchKey,
          controller: _query,
          onChanged: (_) => setState(() {}),
          textInputAction: TextInputAction.search,
          decoration: InputDecoration(
            prefixIcon: const Icon(Icons.search_rounded),
            hintText: 'scholarship_match_country_search'.tr,
          ),
        ),
        const SizedBox(height: KpbSpacing.sm),
        Expanded(
          child: visible.isEmpty
              ? Padding(
                  padding: const EdgeInsets.all(KpbSpacing.md),
                  child: Text(
                    'scholarship_match_country_none'.tr,
                    style: KpbTextStyles.bodySm,
                  ),
                )
              : ListView.builder(
                  itemCount: visible.length,
                  itemBuilder: (context, i) {
                    final country = visible[i];
                    return MatchChoice(
                      key: ValueKey<String>('match-country-${country.code}'),
                      label: country.name,
                      selected: country.code == widget.selected,
                      onTap: () => widget.onSelected(country.code),
                    );
                  },
                ),
        ),
      ],
    );
  }
}

/// Feuille de choix d'un pays (deuxième nationalité, résidence). Rend le code
/// choisi, ou `null`.
Future<String?> showMatchCountrySheet(
  BuildContext context, {
  required String title,
  required List<MatchCountryOption> countries,
  String? selected,
}) {
  return showModalBottomSheet<String>(
    context: context,
    isScrollControlled: true,
    backgroundColor: KpbColors.surface,
    builder: (sheetContext) => SafeArea(
      child: SizedBox(
        height: MediaQuery.of(sheetContext).size.height * 0.8,
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
              Semantics(
                header: true,
                child: Text(title, style: KpbTextStyles.title),
              ),
              const SizedBox(height: KpbSpacing.md),
              Expanded(
                child: MatchCountryList(
                  countries: countries,
                  selected: selected,
                  onSelected: (code) => Navigator.of(sheetContext).pop(code),
                ),
              ),
            ],
          ),
        ),
      ),
    ),
  );
}
