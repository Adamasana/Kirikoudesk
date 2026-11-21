
import 'dart:async';

import 'package:flutter/services.dart';

class ScannerUsbController {
  final Future<void> Function(String code) onCodeScanne;
  final bool Function() estActif;
  final void Function(Object erreur)? onErreur;

  String _bufferScanner = '';
  DateTime? _dernierCaractereScanner;
  Timer? _timerScanner;

  Future<void> _fileTraitement = Future<void>.value();

  bool _initialise = false;

  ScannerUsbController({
    required this.onCodeScanne,
    required this.estActif,
    this.onErreur,
  });

  void demarrer() {
    if (_initialise) return;

    HardwareKeyboard.instance.addHandler(
      _gererEvenementScanner,
    );

    _initialise = true;
  }

  bool _gererEvenementScanner(KeyEvent event) {
    if (event is! KeyDownEvent) {
      return false;
    }

    if (!estActif()) {
      _reinitialiserBuffer();
      return false;
    }

    final maintenant = DateTime.now();

    if (_dernierCaractereScanner != null) {
      final ecart = maintenant.difference(
        _dernierCaractereScanner!,
      );

      if (ecart > const Duration(milliseconds: 120)) {
        _bufferScanner = '';
      }
    }

    _dernierCaractereScanner = maintenant;

    if (event.logicalKey == LogicalKeyboardKey.enter ||
        event.logicalKey == LogicalKeyboardKey.numpadEnter) {
      final code = _bufferScanner.trim();

      _reinitialiserBuffer();

      if (code.isNotEmpty) {
        _ajouterAlaFile(code);
      }

      return true;
    }

    final caractere = event.character;

    if (caractere != null &&
        caractere.isNotEmpty &&
        caractere.length == 1 &&
        !HardwareKeyboard.instance.isControlPressed &&
        !HardwareKeyboard.instance.isAltPressed &&
        !HardwareKeyboard.instance.isMetaPressed) {
      _bufferScanner += caractere;

      _timerScanner?.cancel();

      _timerScanner = Timer(
        const Duration(milliseconds: 180),
        _reinitialiserBuffer,
      );

      return false;
    }

    return false;
  }

  void _ajouterAlaFile(String code) {
    _fileTraitement = _fileTraitement
        .then((_) => onCodeScanne(code))
        .catchError((Object erreur) {
          onErreur?.call(erreur);
        });
  }

  void _reinitialiserBuffer() {
    _bufferScanner = '';
    _dernierCaractereScanner = null;
    _timerScanner?.cancel();
  }

  void dispose() {
    if (_initialise) {
      HardwareKeyboard.instance.removeHandler(
        _gererEvenementScanner,
      );
    }

    _reinitialiserBuffer();
    _initialise = false;
  }
}
