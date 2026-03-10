// Fichier : lib/pages/onboarding/onboarding_page.dart
// Sprint 14, US-14.4 : Onboarding 3 ecrans pour les nouveaux utilisateurs.

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../router/app_routes.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_text_styles.dart';

/// Cle SharedPreferences pour savoir si l'onboarding a ete vu.
const String kHasSeenOnboarding = 'has_seen_onboarding';

/// Page d'onboarding avec 3 ecrans swipables.
class OnboardingPage extends StatefulWidget {
  const OnboardingPage({super.key});

  @override
  State<OnboardingPage> createState() => _OnboardingPageState();
}

class _OnboardingPageState extends State<OnboardingPage> {
  final PageController _pageController = PageController();
  int _currentPage = 0;

  static const List<_OnboardingStep> _steps = [
    _OnboardingStep(
      icon: Icons.favorite,
      iconColor: Colors.redAccent,
      title: 'Compteur de Vie',
      description:
          'Suivez vos points de vie, poison, energie et degats de commandant '
          'avec un compteur intuitif multi-joueurs.\n\n'
          'Supportez de 2 a 10 joueurs avec des backgrounds personnalises.',
    ),
    _OnboardingStep(
      icon: Icons.camera_alt,
      iconColor: Colors.blueAccent,
      title: 'Scanner & Collection',
      description:
          'Scannez vos cartes avec la camera pour les identifier instantanement.\n\n'
          'Gerez votre collection, suivez les prix en temps reel '
          'et construisez vos wishlists.',
    ),
    _OnboardingStep(
      icon: Icons.style,
      iconColor: Colors.amber,
      title: 'Decks & Outils',
      description:
          'Construisez et analysez vos decks avec des statistiques detaillees, '
          'synergies et suggestions.\n\n'
          'Consultez le glossaire, lancez des des et calculez '
          'vos probabilites de pioche.',
    ),
  ];

  Future<void> _completeOnboarding() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(kHasSeenOnboarding, true);
    if (!mounted) return;
    context.go(AppRoutes.lifeCounter);
  }

  void _nextPage() {
    if (_currentPage < _steps.length - 1) {
      _pageController.nextPage(
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
      );
    } else {
      _completeOnboarding();
    }
  }

  void _skip() {
    _completeOnboarding();
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.scaffoldBackground,
      body: SafeArea(
        child: Column(
          children: [
            // Skip button
            Align(
              alignment: Alignment.topRight,
              child: TextButton(
                onPressed: _skip,
                child: Text(
                  'Passer',
                  style: AppTextStyles.cinzel(color: AppColors.textMuted),
                ),
              ),
            ),

            // Page content
            Expanded(
              child: PageView.builder(
                controller: _pageController,
                itemCount: _steps.length,
                onPageChanged: (index) => setState(() => _currentPage = index),
                itemBuilder: (context, index) {
                  final step = _steps[index];
                  return _buildPage(step);
                },
              ),
            ),

            // Page indicators
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 16),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: List.generate(
                  _steps.length,
                  (index) => AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    margin: const EdgeInsets.symmetric(horizontal: 4),
                    width: _currentPage == index ? 24 : 8,
                    height: 8,
                    decoration: BoxDecoration(
                      color: _currentPage == index
                          ? AppColors.primaryShade800
                          : AppColors.borderMedium,
                      borderRadius: BorderRadius.circular(4),
                    ),
                  ),
                ),
              ),
            ),

            // Navigation button
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
              child: SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _nextPage,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primaryShade800,
                    foregroundColor: AppColors.textOnPrimary,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: Text(
                    _currentPage == _steps.length - 1
                        ? "C'est parti !"
                        : 'Suivant',
                    style: AppTextStyles.bold(
                      color: AppColors.textOnPrimary,
                      fontSize: 16,
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPage(_OnboardingStep step) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 32),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          // Icon with decorative container
          Container(
            width: 120,
            height: 120,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: step.iconColor.withValues(alpha: 0.15),
              border: Border.all(
                color: step.iconColor.withValues(alpha: 0.4),
                width: 2,
              ),
            ),
            child: Icon(step.icon, size: 56, color: step.iconColor),
          ),
          const SizedBox(height: 40),

          // Title
          Text(
            step.title,
            style: AppTextStyles.pageTitle(fontSize: 28),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 20),

          // Description
          Text(
            step.description,
            style: AppTextStyles.cinzel(
              color: AppColors.textSecondary,
              fontSize: 14,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}

/// Donnees d'une etape d'onboarding.
class _OnboardingStep {
  final IconData icon;
  final Color iconColor;
  final String title;
  final String description;

  const _OnboardingStep({
    required this.icon,
    required this.iconColor,
    required this.title,
    required this.description,
  });
}
