// Fichier : lib/widgets/collection/moxfield_import_sheet.dart
// Parcours guide d'import de collection Moxfield.
//
// Trois etats : explication (ou exporter chez Moxfield), verification (ce
// que le parser a compris du fichier, avant d'ecrire quoi que ce soit) et
// bilan (ce que l'import a produit).
//
// Voir docs/superpowers/specs/2026-09-19-import-moxfield-design.md

import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:file_picker/file_picker.dart';

import '../../models/moxfield_import.dart';
import '../../providers/preferred_language_provider.dart';
import '../../providers/service_providers.dart';
import '../../services/moxfield_collection_parser.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_text_styles.dart';

enum _Screen { explanation, verification, result }

class MoxfieldImportSheet extends ConsumerStatefulWidget {
  const MoxfieldImportSheet({super.key, this.debugParsed});

  /// Ouvre directement l'ecran de verification avec ce resultat, sans passer
  /// par le selecteur de fichier. Reserve aux tests -- une couture, jamais
  /// utilisee par le parcours reel.
  @visibleForTesting
  final CollectionParseResult? debugParsed;

  @override
  ConsumerState<MoxfieldImportSheet> createState() => _MoxfieldImportSheetState();
}

class _MoxfieldImportSheetState extends ConsumerState<MoxfieldImportSheet> {
  late _Screen _screen;
  CollectionParseResult? _parsed;
  CollectionImportResult? _result;
  bool _busy = false;

  /// Message affiche sur l'ecran d'explication quand la selection ou la
  /// lecture du fichier a echoue (permission refusee, fichier supprime,
  /// encodage invalide...). Un echec de cette etape ne doit jamais rester
  /// silencieux : c'est tout l'argument de ce parcours.
  String? _pickError;

  @override
  void initState() {
    super.initState();
    if (widget.debugParsed != null) {
      _parsed = widget.debugParsed;
      _screen = _Screen.verification;
    } else {
      _screen = _Screen.explanation;
    }
  }

  Future<void> _pickFile() async {
    setState(() {
      _busy = true;
      _pickError = null;
    });
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['csv'],
      );
      if (result == null || result.files.isEmpty || result.files.single.path == null) {
        return;
      }
      final file = File(result.files.single.path!);
      final content = await file.readAsString();
      final parsed = MoxfieldCollectionParser.parse(content);
      if (!mounted) return;
      setState(() {
        _parsed = parsed;
        _screen = _Screen.verification;
      });
    } catch (e) {
      // Selection annulee/refusee, fichier supprime entre la selection et la
      // lecture, encodage invalide... quelle que soit la cause, l'utilisateur
      // doit le savoir : un echec silencieux serait le pire comportement
      // possible pour une fonctionnalite dont l'argument est de ne jamais se
      // tromper sans le dire.
      if (!mounted) return;
      setState(() => _pickError = 'Impossible de lire le fichier : $e');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _doImport() async {
    final parsed = _parsed;
    if (parsed == null) return;
    setState(() => _busy = true);

    final lang = await readPreferredLanguage();
    final service = ref.read(collectionImportServiceProvider);
    final result = await service.import(parsed, preferredLang: lang);

    // Le drain part sans etre attendu : l'utilisateur voit son bilan tout de
    // suite, les traductions arrivent ensuite en tache de fond.
    unawaited(ref.read(translationWorkerProvider).drain());

    if (!mounted) return;
    setState(() {
      _result = result;
      _busy = false;
      _screen = _Screen.result;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      child: Container(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
        decoration: const BoxDecoration(
          color: AppColors.scaffoldBackground,
          borderRadius: BorderRadius.only(
            topLeft: Radius.circular(16),
            topRight: Radius.circular(16),
          ),
        ),
        child: SafeArea(
          top: false,
          child: switch (_screen) {
            _Screen.explanation => _buildExplanation(),
            _Screen.verification => _buildVerification(),
            _Screen.result => _buildResult(),
          },
        ),
      ),
    );
  }

  // ============================================================
  // ECRAN 1 : EXPLICATION
  // ============================================================

  Widget _buildExplanation() {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Importer depuis Moxfield', style: AppTextStyles.sectionTitle()),
        const SizedBox(height: 8),
        Text(
          "Moxfield permet d'exporter ta collection. L'app lit le fichier — "
          'elle ne se connecte jamais a ton compte.',
          style: AppTextStyles.body(color: AppColors.textSecondary),
        ),
        const SizedBox(height: 16),
        _step(1, 'Ouvre moxfield.com et connecte-toi'),
        _step(2, 'Va dans Collection, puis More → Export'),
        _step(3, 'Choisis le format CSV et telecharge'),
        _step(4, 'Reviens ici et selectionne le fichier'),
        if (_pickError != null) ...[
          const SizedBox(height: 12),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: AppColors.surfaceDark,
              borderRadius: BorderRadius.circular(9),
              border: Border.all(color: AppColors.error.withValues(alpha: 0.45)),
            ),
            child: Text(_pickError!, style: AppTextStyles.body(color: AppColors.error)),
          ),
        ],
        const SizedBox(height: 16),
        SizedBox(
          width: double.infinity,
          child: ElevatedButton(
            onPressed: _busy ? null : _pickFile,
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primaryShade800,
              foregroundColor: AppColors.textOnPrimary,
              padding: const EdgeInsets.symmetric(vertical: 14),
            ),
            child: _busy
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.textOnPrimary),
                  )
                : Text('Choisir le fichier', style: AppTextStyles.buttonText(color: AppColors.textOnPrimary)),
          ),
        ),
      ],
    );
  }

  Widget _step(int n, String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 11),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 20,
            child: Text(
              '$n',
              style: AppTextStyles.cinzel(color: AppColors.primaryShade800, fontWeight: FontWeight.bold),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(text, style: AppTextStyles.body(color: AppColors.textSecondary)),
          ),
        ],
      ),
    );
  }

  // ============================================================
  // ECRAN 2 : VERIFICATION
  // ============================================================

  Widget _buildVerification() {
    final parsed = _parsed!;

    if (parsed.refusal != null) {
      return Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Verification du fichier', style: AppTextStyles.sectionTitle()),
          const SizedBox(height: 12),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: AppColors.surfaceDark,
              borderRadius: BorderRadius.circular(9),
              border: Border.all(color: AppColors.error.withValues(alpha: 0.45)),
            ),
            child: Text(
              parsed.refusal!,
              style: AppTextStyles.body(color: AppColors.error),
            ),
          ),
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            child: TextButton(
              onPressed: () => Navigator.of(context).maybePop(),
              child: Text('Fermer', style: AppTextStyles.buttonText(color: AppColors.textSecondary)),
            ),
          ),
        ],
      );
    }

    final degraded = parsed.isDegraded;

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Verification du fichier', style: AppTextStyles.sectionTitle()),
        const SizedBox(height: 12),
        _panel(
          label: 'Lignes lues',
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.baseline,
            textBaseline: TextBaseline.alphabetic,
            children: [
              Text('${parsed.linesRead}', style: AppTextStyles.pageTitle(fontSize: 26)),
              const SizedBox(width: 6),
              Text('cartes', style: AppTextStyles.label(color: AppColors.textMuted)),
            ],
          ),
        ),
        const SizedBox(height: 10),
        _panel(
          label: 'Colonnes reconnues',
          warn: degraded,
          child: Wrap(
            spacing: 6,
            runSpacing: 6,
            children: [
              for (final col in parsed.recognizedColumns) _chip(col, ok: true),
              if (degraded)
                for (final col in parsed.missingIdentityColumns) _chip(col, ok: false),
            ],
          ),
        ),
        const SizedBox(height: 12),
        Text(
          degraded
              ? 'Sans edition ni numero, les cartes seront identifiees par leur '
                  'nom seul : tu obtiendras une edition arbitraire, en anglais.'
              : 'Les quantites du fichier remplaceront les tiennes pour ces '
                  'tirages. Rien ne sera supprime.',
          style: AppTextStyles.body(color: AppColors.textSecondary),
        ),
        const SizedBox(height: 16),
        Row(
          children: [
            Expanded(
              child: OutlinedButton(
                onPressed: _busy ? null : () => Navigator.of(context).maybePop(),
                style: OutlinedButton.styleFrom(
                  foregroundColor: AppColors.textSecondary,
                  side: const BorderSide(color: AppColors.borderMedium),
                  padding: const EdgeInsets.symmetric(vertical: 14),
                ),
                child: const Text('Annuler'),
              ),
            ),
            const SizedBox(width: 9),
            Expanded(
              child: ElevatedButton(
                onPressed: _busy ? null : _doImport,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primaryShade800,
                  foregroundColor: AppColors.textOnPrimary,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                ),
                child: _busy
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.textOnPrimary),
                      )
                    : Text(degraded ? 'Importer quand même' : 'Importer'),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _chip(String label, {required bool ok}) {
    final color = ok ? AppColors.success : AppColors.amber;
    // Une colonne manquante porte une croix en prefixe plutot qu'un adjectif
    // accorde ("absente"/"absent" selon le genre du nom de colonne serait
    // faux pour "Collector Number") : indice textuel, aucun accord invente,
    // et l'information ne repose plus seulement sur la couleur (accessibilite
    // daltonisme).
    final text = ok ? label : '✕ $label';
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: color.withValues(alpha: 0.45)),
      ),
      child: Text(text, style: AppTextStyles.cinzel(color: color, fontSize: 11)),
    );
  }

  // ============================================================
  // ECRAN 3 : BILAN
  // ============================================================

  Widget _buildResult() {
    final result = _result!;
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Import termine', style: AppTextStyles.sectionTitle()),
        const SizedBox(height: 12),
        _statLine('Cartes importees', '${result.imported}', color: AppColors.success),
        _statLine('Ajoutees', '${result.added}'),
        _statLine('Quantite mise a jour', '${result.updated}'),
        if (result.tagged > 0) _statLine('Taguees a verifier', '${result.tagged}', color: AppColors.amber),
        if (result.notIdentified > 0) _statLine('Non identifiees', '${result.notIdentified}', color: AppColors.error),
        if (result.failedTransient > 0)
          _statLine('Echecs reseau (a reessayer)', '${result.failedTransient}', color: AppColors.amber),
        if (result.unreadableLines.isNotEmpty)
          _statLine('Lignes illisibles', '${result.unreadableLines.length}', color: AppColors.error),
        const SizedBox(height: 16),
        SizedBox(
          width: double.infinity,
          child: ElevatedButton(
            onPressed: () => Navigator.of(context).maybePop(),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primaryShade800,
              foregroundColor: AppColors.textOnPrimary,
              padding: const EdgeInsets.symmetric(vertical: 14),
            ),
            child: const Text('Fermer'),
          ),
        ),
      ],
    );
  }

  Widget _statLine(String label, String value, {Color? color}) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 8),
      decoration: const BoxDecoration(
        border: Border(top: BorderSide(color: AppColors.borderMedium)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: AppTextStyles.body(color: AppColors.textSecondary)),
          Text(value, style: AppTextStyles.body(color: color ?? AppColors.textPrimary)),
        ],
      ),
    );
  }

  Widget _panel({required String label, required Widget child, bool warn = false}) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.surfaceDark,
        borderRadius: BorderRadius.circular(9),
        border: Border.all(color: warn ? AppColors.amber.withValues(alpha: 0.45) : AppColors.borderMedium),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label.toUpperCase(),
            style: AppTextStyles.label(color: AppColors.textMuted, fontSize: 10),
          ),
          const SizedBox(height: 8),
          child,
        ],
      ),
    );
  }
}
