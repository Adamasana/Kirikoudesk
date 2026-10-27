import 'package:flutter/material.dart';
import '../services/api/api_client.dart';

import '../main.dart';
import '../repositories/authentification_repository.dart';
import '../theme/couleurs.dart';

class ConnexionPage extends StatefulWidget {
  const ConnexionPage({super.key});

  @override
  State<ConnexionPage> createState() => _ConnexionPageState();
}

class _ConnexionPageState extends State<ConnexionPage> {
  final _formKey = GlobalKey<FormState>();

  final _emailController = TextEditingController();
  final _motDePasseController = TextEditingController();

  final AuthentificationRepository _authentificationRepository =
      AuthentificationRepository();

  bool _afficherMotDePasse = false;
  bool _seSouvenir = false;
  bool _connexionEnCours = false;

  String? _erreurConnexion;

  @override
  void dispose() {
    _emailController.dispose();
    _motDePasseController.dispose();
    _authentificationRepository.fermer();
    super.dispose();
  }

  // ============================================================
  // VALIDATION EMAIL
  // ============================================================

  String? _verifierEmail(String? valeur) {
    final email = valeur?.trim() ?? '';

    if (email.isEmpty) {
      return 'Veuillez saisir votre adresse e-mail.';
    }

    final expression = RegExp(
      r'^[^@\s]+@[^@\s]+\.[^@\s]+$',
    );

    if (!expression.hasMatch(email)) {
      return 'Veuillez saisir une adresse e-mail valide.';
    }

    return null;
  }

  // ============================================================
  // VALIDATION MOT DE PASSE
  // ============================================================

  String? _verifierMotDePasse(String? valeur) {
    final motDePasse = valeur ?? '';

    if (motDePasse.isEmpty) {
      return 'Veuillez saisir votre mot de passe.';
    }

    if (motDePasse.length < 6) {
      return 'Le mot de passe doit contenir au moins 6 caractères.';
    }

    return null;
  }

  // ============================================================
  // CONNEXION
  // ============================================================

  Future<void> _seConnecter() async {
    FocusScope.of(context).unfocus();

    if (_erreurConnexion != null) {
      setState(() {
        _erreurConnexion = null;
      });
    }

    if (!_formKey.currentState!.validate()) {
      return;
    }

    setState(() {
      _connexionEnCours = true;
    });

    try {
      await _authentificationRepository.connecter(
        email: _emailController.text.trim(),
        motDePasse: _motDePasseController.text,
      );

      if (!mounted) {
        return;
      }

      setState(() {
        _connexionEnCours = false;
      });

      Navigator.of(context).pushReplacement(
        MaterialPageRoute(
          builder: (_) => const ApplicationPage(),
        ),
      );
    } on AuthentificationException catch (e) {
      if (!mounted) {
        return;
      }

      setState(() {
        _connexionEnCours = false;
        _erreurConnexion = e.message;
      });
    } on ApiException catch (e) {
      if (!mounted) {
        return;
      }

      setState(() {
        _connexionEnCours = false;
        _erreurConnexion = e.message;
      });
    } catch (_) {
      if (!mounted) {
        return;
      }

      setState(() {
        _connexionEnCours = false;
        _erreurConnexion =
            'Impossible de se connecter au serveur.';
      });
    }
  }

  // ============================================================
  // MOT DE PASSE OUBLIÉ
  // ============================================================

  void _motDePasseOublie() {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text(
          'La récupération du mot de passe sera ajoutée plus tard.',
          style: TextStyle(
            fontFamily: 'Inter',
          ),
        ),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  // ============================================================
  // INTERFACE
  // ============================================================

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Couleurs.fond,
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, contraintes) {
            final largeur = contraintes.maxWidth;
            final hauteur = contraintes.maxHeight;

            final margeHorizontale = largeur >= 700
                ? 32.0
                : largeur >= 450
                    ? 24.0
                    : 16.0;

            final margeVerticale = hauteur >= 650
                ? 40.0
                : hauteur >= 500
                    ? 24.0
                    : 12.0;

            return SingleChildScrollView(
              padding: EdgeInsets.symmetric(
                horizontal: margeHorizontale,
                vertical: margeVerticale,
              ),
              child: ConstrainedBox(
                constraints: BoxConstraints(
                  minHeight: hauteur - (margeVerticale * 2),
                ),
                child: Center(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(
                      maxWidth: 470,
                    ),
                    child: _construireFormulaire(),
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }

  // ============================================================
  // FORMULAIRE PRINCIPAL
  // ============================================================

  Widget _construireFormulaire() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(42),
      decoration: BoxDecoration(
        color: Couleurs.blanc,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: Couleurs.bordure,
        ),
        boxShadow: const [
          BoxShadow(
            color: Color(0x12000000),
            blurRadius: 30,
            offset: Offset(0, 12),
          ),
        ],
      ),
      child: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _construireEntete(),

            const SizedBox(height: 32),

            _construireChamp(
              label: 'Adresse e-mail',
              hint: 'votre@email.com',
              icon: Icons.email_outlined,
              controller: _emailController,
              validator: _verifierEmail,
              keyboardType: TextInputType.emailAddress,
              textInputAction: TextInputAction.next,
              onChanged: (_) {
                if (_erreurConnexion != null) {
                  setState(() {
                    _erreurConnexion = null;
                  });
                }
              },
            ),

            const SizedBox(height: 20),

            _construireChamp(
              label: 'Mot de passe',
              hint: 'Votre mot de passe',
              icon: Icons.lock_outline,
              controller: _motDePasseController,
              validator: _verifierMotDePasse,
              obscureText: !_afficherMotDePasse,
              textInputAction: TextInputAction.done,
              onChanged: (_) {
                if (_erreurConnexion != null) {
                  setState(() {
                    _erreurConnexion = null;
                  });
                }
              },
              onFieldSubmitted: (_) {
                if (!_connexionEnCours) {
                  _seConnecter();
                }
              },
              suffixIcon: IconButton(
                tooltip: _afficherMotDePasse
                    ? 'Masquer le mot de passe'
                    : 'Afficher le mot de passe',
                onPressed: () {
                  setState(() {
                    _afficherMotDePasse =
                        !_afficherMotDePasse;
                  });
                },
                icon: Icon(
                  _afficherMotDePasse
                      ? Icons.visibility_off_outlined
                      : Icons.visibility_outlined,
                  size: 20,
                  color: Couleurs.muted,
                ),
              ),
            ),

            const SizedBox(height: 13),

            _construireOptions(),

            if (_erreurConnexion != null) ...[
              const SizedBox(height: 18),
              _construireErreurConnexion(),
            ],

            const SizedBox(height: 25),

            _construireBoutonConnexion(),

            const SizedBox(height: 27),

            _construirePied(),
          ],
        ),
      ),
    );
  }

  // ============================================================
  // ENTÊTE
  // ============================================================

  Widget _construireEntete() {
    return Column(
      children: [
        Container(
          width: 54,
          height: 54,
          decoration: BoxDecoration(
            color: Couleurs.primaire,
            borderRadius: BorderRadius.circular(12),
          ),
          alignment: Alignment.center,
          child: const Text(
            'K',
            style: TextStyle(
              fontFamily: 'Inter',
              fontSize: 25,
              fontWeight: FontWeight.w700,
              color: Couleurs.blanc,
            ),
          ),
        ),

        const SizedBox(height: 22),

        const Text(
          'Connexion',
          textAlign: TextAlign.center,
          style: TextStyle(
            fontFamily: 'Inter',
            fontSize: 26,
            fontWeight: FontWeight.w700,
            color: Couleurs.texte,
            letterSpacing: -0.5,
          ),
        ),

        const SizedBox(height: 8),

        const Text(
          'Connectez-vous à votre espace de gestion.',
          textAlign: TextAlign.center,
          style: TextStyle(
            fontFamily: 'Inter',
            fontSize: 13.5,
            fontWeight: FontWeight.w400,
            color: Couleurs.muted,
            height: 1.5,
          ),
        ),
      ],
    );
  }

  // ============================================================
  // OPTIONS
  // ============================================================

  Widget _construireOptions() {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        SizedBox(
          width: 19,
          height: 19,
          child: Checkbox(
            value: _seSouvenir,
            activeColor: Couleurs.primaire,
            side: const BorderSide(
              color: Couleurs.bordure,
              width: 1.4,
            ),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(4),
            ),
            onChanged: (valeur) {
              setState(() {
                _seSouvenir = valeur ?? false;
              });
            },
          ),
        ),

        const SizedBox(width: 9),

        const Expanded(
          child: Text(
            'Se souvenir de moi',
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontFamily: 'Inter',
              fontSize: 12.5,
              fontWeight: FontWeight.w400,
              color: Couleurs.muted,
            ),
          ),
        ),

        const SizedBox(width: 8),

        TextButton(
          onPressed: _motDePasseOublie,
          style: TextButton.styleFrom(
            padding: EdgeInsets.zero,
            minimumSize: Size.zero,
            tapTargetSize:
                MaterialTapTargetSize.shrinkWrap,
          ),
          child: const Text(
            'Mot de passe oublié ?',
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontFamily: 'Inter',
              fontSize: 12,
              fontWeight: FontWeight.w500,
              color: Couleurs.primaire,
            ),
          ),
        ),
      ],
    );
  }

  // ============================================================
  // MESSAGE D'ERREUR DE CONNEXION
  // ============================================================

  Widget _construireErreurConnexion() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(
        horizontal: 13,
        vertical: 11,
      ),
      decoration: BoxDecoration(
        color: Couleurs.danger.withValues(alpha: 0.07),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: Couleurs.danger.withValues(alpha: 0.18),
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Padding(
            padding: EdgeInsets.only(top: 1),
            child: Icon(
              Icons.error_outline,
              size: 19,
              color: Couleurs.danger,
            ),
          ),

          const SizedBox(width: 9),

          Expanded(
            child: Text(
              _erreurConnexion!,
              style: const TextStyle(
                fontFamily: 'Inter',
                fontSize: 12,
                fontWeight: FontWeight.w500,
                color: Couleurs.danger,
                height: 1.4,
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ============================================================
  // BOUTON CONNEXION
  // ============================================================

  Widget _construireBoutonConnexion() {
    return SizedBox(
      height: 49,
      width: double.infinity,
      child: MouseRegion(
        cursor: _connexionEnCours
            ? SystemMouseCursors.basic
            : SystemMouseCursors.click,
        child: ElevatedButton(
          onPressed:
              _connexionEnCours ? null : _seConnecter,
          style: ElevatedButton.styleFrom(
            elevation: 0,
            backgroundColor: Couleurs.primaire,
            disabledBackgroundColor:
                Couleurs.secondaire.withValues(alpha: 0.65),
            foregroundColor: Couleurs.blanc,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(8),
            ),
          ),
          child: _connexionEnCours
              ? const SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(
                    strokeWidth: 2.1,
                    valueColor:
                        AlwaysStoppedAnimation<Color>(
                      Couleurs.blanc,
                    ),
                  ),
                )
              : const Text(
                  'Se connecter',
                  style: TextStyle(
                    fontFamily: 'Inter',
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                  ),
                ),
        ),
      ),
    );
  }

  // ============================================================
  // PIED DE FORMULAIRE
  // ============================================================

  Widget _construirePied() {
    return Column(
      children: [
        Row(
          children: [
            const Expanded(
              child: Divider(
                color: Couleurs.bordure,
                height: 1,
              ),
            ),

            Padding(
              padding:
                  const EdgeInsets.symmetric(horizontal: 12),
              child: Text(
                'KirikouBF',
                style: TextStyle(
                  fontFamily: 'Inter',
                  fontSize: 11,
                  fontWeight: FontWeight.w500,
                  color:
                      Couleurs.muted.withValues(alpha: 0.8),
                ),
              ),
            ),

            const Expanded(
              child: Divider(
                color: Couleurs.bordure,
                height: 1,
              ),
            ),
          ],
        ),

        const SizedBox(height: 15),

        const Text(
          'Système de gestion',
          textAlign: TextAlign.center,
          style: TextStyle(
            fontFamily: 'Inter',
            fontSize: 11.5,
            fontWeight: FontWeight.w400,
            color: Couleurs.muted,
          ),
        ),
      ],
    );
  }

  // ============================================================
  // CHAMP
  // ============================================================

  Widget _construireChamp({
    required String label,
    required String hint,
    required IconData icon,
    required TextEditingController controller,
    required String? Function(String?) validator,
    TextInputType? keyboardType,
    bool obscureText = false,
    Widget? suffixIcon,
    TextInputAction? textInputAction,
    void Function(String)? onFieldSubmitted,
    void Function(String)? onChanged,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(
            fontFamily: 'Inter',
            fontSize: 13,
            fontWeight: FontWeight.w600,
            color: Couleurs.texte,
          ),
        ),

        const SizedBox(height: 8),

        TextFormField(
          controller: controller,
          validator: validator,
          keyboardType: keyboardType,
          obscureText: obscureText,
          textInputAction: textInputAction,
          onFieldSubmitted: onFieldSubmitted,
          onChanged: onChanged,

          style: const TextStyle(
            fontFamily: 'Inter',
            fontSize: 13.5,
            fontWeight: FontWeight.w400,
            color: Couleurs.texte,
          ),

          decoration: InputDecoration(
            hintText: hint,

            hintStyle: const TextStyle(
              fontFamily: 'Inter',
              fontSize: 13,
              fontWeight: FontWeight.w400,
              color: Couleurs.muted,
            ),

            prefixIcon: Icon(
              icon,
              size: 20,
              color: Couleurs.muted,
            ),

            suffixIcon: suffixIcon,

            filled: true,
            fillColor: Couleurs.blanc,

            contentPadding:
                const EdgeInsets.symmetric(
              horizontal: 14,
              vertical: 14,
            ),

            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: const BorderSide(
                color: Couleurs.bordure,
              ),
            ),

            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: const BorderSide(
                color: Couleurs.bordure,
              ),
            ),

            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: const BorderSide(
                color: Couleurs.primaire,
                width: 1.5,
              ),
            ),

            errorBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: const BorderSide(
                color: Couleurs.danger,
              ),
            ),

            focusedErrorBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: const BorderSide(
                color: Couleurs.danger,
                width: 1.5,
              ),
            ),
          ),
        ),
      ],
    );
  }
}