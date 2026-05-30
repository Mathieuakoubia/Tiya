// Selfie Flash — Capture biométrique avant/après une routine
// Utilisé par Reset Flash (Routine 1) pour mesurer l'impact
// RGPD : seul le score Aura final est sauvegardé dans Firestore
import 'dart:async';
import 'package:flutter/material.dart';
import 'biometric_service.dart';

class SelfieFlash extends StatefulWidget {
  /// 'before' = capture initiale, 'after' = capture post-routine
  final String moment;
  final VoidCallback? onComplete;
  final void Function(AuraResult result)? onAuraReady;

  const SelfieFlash({
    super.key,
    this.moment = 'before',
    this.onComplete,
    this.onAuraReady,
  });

  @override
  State<SelfieFlash> createState() => _SelfieFlashState();
}

class _SelfieFlashState extends State<SelfieFlash>
    with SingleTickerProviderStateMixin {
  String _step = 'camera'; // 'camera' | 'voice' | 'processing' | 'done' | 'error'
  AuraResult? _result;

  late AnimationController _pulseCtrl;
  late Animation<double>   _pulse;

  @override
  void initState() {
    super.initState();
    _pulseCtrl = AnimationController(
        duration: const Duration(seconds: 2), vsync: this)..repeat(reverse: true);
    _pulse = Tween(begin: 0.85, end: 1.15)
        .chain(CurveTween(curve: Curves.easeInOut))
        .animate(_pulseCtrl);
    WidgetsBinding.instance.addPostFrameCallback((_) => _run());
  }

  Future<void> _run() async {
    try {
      final result = await biometricService.runFullAnalysis(
        onProgress: (step) {
          if (mounted) setState(() => _step = step);
        },
      );
      if (!mounted) return;
      setState(() { _step = 'done'; _result = result; });
      widget.onAuraReady?.call(result);
      await Future.delayed(const Duration(milliseconds: 1500));
      widget.onComplete?.call();
    } catch (e) {
      if (mounted) setState(() { _step = 'error'; _errorMsg = e.toString(); });
    }
  }

  @override
  void dispose() {
    _pulseCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF121212),
      body: SafeArea(child: Center(child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 36),
        child: AnimatedSwitcher(
          duration: const Duration(milliseconds: 400),
          child: _buildStep(),
        ),
      ))),
    );
  }

  Widget _buildStep() {
    switch (_step) {
      case 'camera':     return _buildCamera();
      case 'voice':      return _buildVoice();
      case 'processing': return _buildProcessing();
      case 'done':       return _buildDone();
      case 'error':      return _buildError();
      default:           return _buildCamera();
    }
  }

  Widget _buildCamera() => AnimatedBuilder(
    key: const ValueKey('cam'),
    animation: _pulse,
    builder: (_, __) => Column(mainAxisAlignment: MainAxisAlignment.center, children: [
      Transform.scale(scale: _pulse.value, child: Container(
        width: 120, height: 120,
        decoration: BoxDecoration(shape: BoxShape.circle,
            color: const Color(0xFF0DAABA).withValues(alpha: 0.12),
            border: Border.all(color: const Color(0xFF0DAABA).withValues(alpha: 0.40), width: 2)),
        child: const Icon(Icons.face, color: Color(0xFF0DAABA), size: 52))),
      const SizedBox(height: 28),
      Text(
        widget.moment == 'before' ? 'Regardez la caméra\n6 secondes' : 'On mesure votre\nAura après la routine',
        textAlign: TextAlign.center,
        style: const TextStyle(fontFamily: 'Gelica', color: Colors.white,
            fontSize: 20, fontWeight: FontWeight.w200, fontStyle: FontStyle.italic, height: 1.4)),
      const SizedBox(height: 12),
      Text('Détection faciale en cours...',
          style: TextStyle(color: Colors.white.withValues(alpha: 0.35), fontSize: 13)),
    ]));

  Widget _buildVoice() => Column(
    key: const ValueKey('voice'),
    mainAxisAlignment: MainAxisAlignment.center,
    children: [
      SizedBox(width: 80, height: 80,
          child: CircularProgressIndicator(strokeWidth: 3,
              valueColor: AlwaysStoppedAnimation(const Color(0xFFE8B86E).withValues(alpha: 0.80)))),
      const SizedBox(height: 28),
      const Text('Dites quelque chose\nou respirez 3 secondes...',
          textAlign: TextAlign.center,
          style: TextStyle(fontFamily: 'Gelica', color: Colors.white,
              fontSize: 20, fontWeight: FontWeight.w200, fontStyle: FontStyle.italic, height: 1.4)),
      const SizedBox(height: 12),
      Text('Analyse vocale en cours...',
          style: TextStyle(color: Colors.white.withValues(alpha: 0.35), fontSize: 13)),
    ]);

  Widget _buildProcessing() => Column(
    key: const ValueKey('proc'),
    mainAxisAlignment: MainAxisAlignment.center,
    children: [
      SizedBox(width: 48, height: 48,
          child: CircularProgressIndicator(strokeWidth: 2.5,
              valueColor: AlwaysStoppedAnimation(const Color(0xFFD9CCE8).withValues(alpha: 0.80)))),
      const SizedBox(height: 24),
      Text('Calcul de votre Aura...',
          style: TextStyle(color: Colors.white.withValues(alpha: 0.45), fontSize: 15)),
    ]);

  Widget _buildDone() {
    final result = _result;
    if (result == null) return const SizedBox.shrink();
    final color = BiometricService.auraColor(result.hexColor);
    final label = switch (result.state) {
      AuraState.serene    => 'Sereine',
      AuraState.balanced  => 'Équilibrée',
      AuraState.tense     => 'Tendue',
      AuraState.veryTense => 'Très tendue',
    };
    return Column(
      key: const ValueKey('done'),
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Container(width: 120, height: 120,
            decoration: BoxDecoration(shape: BoxShape.circle,
                color: color.withValues(alpha: 0.20),
                boxShadow: [BoxShadow(color: color.withValues(alpha: 0.35), blurRadius: 40, spreadRadius: 8)],
                border: Border.all(color: color.withValues(alpha: 0.60), width: 2))),
        const SizedBox(height: 24),
        Text('Votre Aura : $label',
            textAlign: TextAlign.center,
            style: TextStyle(fontFamily: 'Gelica', color: color,
                fontSize: 22, fontWeight: FontWeight.w600)),
        const SizedBox(height: 8),
        Text(result.hexColor,
            style: TextStyle(color: Colors.white.withValues(alpha: 0.30), fontSize: 12,
                fontFamily: 'monospace')),
      ]);
  }

  Widget _buildError() => Column(
    key: const ValueKey('err'),
    mainAxisAlignment: MainAxisAlignment.center,
    children: [
      Icon(Icons.error_outline, color: Colors.white.withValues(alpha: 0.40), size: 48),
      const SizedBox(height: 20),
      Text('Analyse indisponible.\nVotre routine continue normalement.',
          textAlign: TextAlign.center,
          style: TextStyle(color: Colors.white.withValues(alpha: 0.45), fontSize: 14, height: 1.5)),
      const SizedBox(height: 24),
      ElevatedButton(
        onPressed: widget.onComplete,
        style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF065963),
            foregroundColor: Colors.white, padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 12),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)), elevation: 0),
        child: const Text('Continuer quand même'),
      ),
    ]);
}
