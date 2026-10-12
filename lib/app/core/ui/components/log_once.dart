import 'package:flutter/widgets.dart';

/// Appelle [onFirstMount] UNE fois, quand ce widget entre dans l'arbre.
///
/// Pour les écrans sans état (`StatelessWidget`) qui doivent émettre un
/// événement de consultation : un appel dans `build()` partirait à chaque
/// reconstruction (GetX en provoque beaucoup) et gonflerait les comptes.
class LogOnce extends StatefulWidget {
  const LogOnce({super.key, required this.onFirstMount, required this.child});

  final VoidCallback onFirstMount;
  final Widget child;

  @override
  State<LogOnce> createState() => _LogOnceState();
}

class _LogOnceState extends State<LogOnce> {
  @override
  void initState() {
    super.initState();
    widget.onFirstMount();
  }

  @override
  Widget build(BuildContext context) => widget.child;
}
