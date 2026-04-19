import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

const _btnColor = Color(0xFF5B242F);
const _titleColor = Color(0xFF1A0A0E);
const _bodyColor = Color(0xFF2C1A1E);

class RoutineIntroScreen extends StatelessWidget {
  final String title;
  final String badgeLabel;
  final String scienceText;
  final List<String> steps;
  final String buttonLabel;
  final VoidCallback onStart;
  final Color accentColor;

  const RoutineIntroScreen({
    super.key,
    required this.title,
    required this.badgeLabel,
    required this.scienceText,
    required this.steps,
    required this.onStart,
    this.buttonLabel = 'Commencer',
    this.accentColor = const Color(0xFF735983),
  });

  @override
  Widget build(BuildContext context) {
    return Stack(
      fit: StackFit.expand,
      children: [
        Image.asset(
          'assets/images/Fonds-02.png',
          fit: BoxFit.cover,
        ),
        Container(color: Colors.white.withValues(alpha: 0.10)),
        SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 28),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: SingleChildScrollView(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const SizedBox(height: 16),
                        IconButton(
                          onPressed: () => Navigator.of(context).pop(),
                          icon: const Icon(Icons.arrow_back_ios_new, size: 18),
                          style: IconButton.styleFrom(
                            foregroundColor: accentColor,
                            backgroundColor: accentColor.withValues(alpha: 0.12),
                            shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12)),
                          ),
                        ),
                        const SizedBox(height: 28),
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 14, vertical: 6),
                          decoration: BoxDecoration(
                            color: Colors.transparent,
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(
                                color: _btnColor.withValues(alpha: 0.35),
                                width: 1),
                          ),
                          child: Text(
                            badgeLabel,
                            style: GoogleFonts.poppins(
                              color: _btnColor,
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                        const SizedBox(height: 14),
                        Text(
                          title.toUpperCase(),
                          style: GoogleFonts.poppins(
                            fontSize: 40,
                            fontWeight: FontWeight.w500,
                            color: _titleColor,
                            height: 1.1,
                          ),
                        ),
                        const SizedBox(height: 28),
                        Text(
                          'FONDEMENT SCIENTIFIQUE :',
                          style: GoogleFonts.poppins(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            color: _titleColor,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          scienceText,
                          style: GoogleFonts.poppins(
                            fontSize: 15,
                            fontWeight: FontWeight.w500,
                            color: _bodyColor.withValues(alpha: 0.72),
                            height: 1.40,
                          ),
                        ),
                        const SizedBox(height: 32),
                        for (int i = 0; i < steps.length; i++) ...[
                          _IntroStep(
                            number: '${i + 1}',
                            text: steps[i],
                            accentColor: accentColor,
                          ),
                          if (i < steps.length - 1) const SizedBox(height: 14),
                        ],
                        const SizedBox(height: 24),
                      ],
                    ),
                  ),
                ),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: onStart,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: _btnColor,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 18),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(30)),
                      elevation: 0,
                    ),
                    child: Text(
                      buttonLabel,
                      style: GoogleFonts.poppins(
                        fontSize: 17,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 24),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _IntroStep extends StatelessWidget {
  final String number;
  final String text;
  final Color accentColor;

  const _IntroStep({
    required this.number,
    required this.text,
    required this.accentColor,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 28,
          height: 28,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: Colors.transparent,
            border: Border.all(
                color: _btnColor.withValues(alpha: 0.40), width: 1.5),
          ),
          child: Center(
            child: Text(
              number,
              style: const TextStyle(
                color: _btnColor,
                fontSize: 13,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Text(
            text,
            style: GoogleFonts.poppins(
              fontSize: 14,
              fontWeight: FontWeight.w500,
              color: _bodyColor,
            ),
          ),
        ),
      ],
    );
  }
}
