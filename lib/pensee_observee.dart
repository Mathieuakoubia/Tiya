// Routine 36 — Défusion cognitive (ACT)
import 'dart:async';
import 'package:flutter/material.dart';

class _Ico {
  static const String _f = 'icomoon';
  static const IconData magic = IconData(0xe94c, fontFamily: _f);
}

const _bg    = Color(0xFF121212);
const _teal  = Color(0xFF0DAABA);
const _dark  = Color(0xFF065963);
const _gold  = Color(0xFFE8B86E);
const _lilas = Color(0xFFD9CCE8);

enum _ACTStep { input, reformulation, pause, choice, complete }

class PenseeObservee extends StatefulWidget {
  final VoidCallback? onComplete;
  const PenseeObservee({super.key, this.onComplete});

  @override
  State<PenseeObservee> createState() => _PenseeObserveeState();
}

class _PenseeObserveeState extends State<PenseeObservee> {
  final _ctrl = TextEditingController();
  _ACTStep _step   = _ACTStep.input;
  String   _thought = '';
  Timer?   _pauseTimer;
  int      _pauseElapsed = 0;

  @override
  void dispose() {
    _ctrl.dispose();
    _pauseTimer?.cancel();
    super.dispose();
  }

  void _submit() {
    final txt = _ctrl.text.trim();
    if (txt.isEmpty) return;
    // Validation longueur (OWASP M4 — input validation)
    if (txt.length > 200) return;
    setState(() {
      _thought = txt;
      _step    = _ACTStep.reformulation;
    });
    Future.delayed(const Duration(seconds: 3), () {
      if (mounted) _startPause();
    });
  }

  void _startPause() {
    setState(() { _step = _ACTStep.pause; _pauseElapsed = 0; });
    _pauseTimer = Timer.periodic(const Duration(seconds: 1), (t) {
      if (!mounted) { t.cancel(); return; }
      setState(() => _pauseElapsed++);
      if (_pauseElapsed >= 10) { t.cancel(); setState(() => _step = _ACTStep.choice); }
    });
  }

  void _choose(String action) {
    setState(() => _step = _ACTStep.complete);
    widget.onComplete?.call();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _bg,
      resizeToAvoidBottomInset: true,
      body: SafeArea(
        child: AnimatedSwitcher(
          duration: const Duration(milliseconds: 500),
          child: _buildStep(),
        ),
      ),
    );
  }

  Widget _buildStep() {
    switch (_step) {
      case _ACTStep.input:         return _buildInput();
      case _ACTStep.reformulation: return _buildReformulation();
      case _ACTStep.pause:         return _buildPause();
      case _ACTStep.choice:        return _buildChoice();
      case _ACTStep.complete:      return _buildComplete();
    }
  }

  Widget _buildInput() => Padding(
    key: const ValueKey('input'),
    padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 32),
    child: Column(children: [
      const Spacer(),
      Icon(_Ico.magic, color: _lilas.withValues(alpha: 0.60), size: 44),
      const SizedBox(height: 24),
      const Text(
        'Votre esprit tourne.\nNommons ce qui passe.',
        textAlign: TextAlign.center,
        style: TextStyle(
            fontFamily: 'Gelica', color: Colors.white,
            fontSize: 20, fontWeight: FontWeight.w200,
            fontStyle: FontStyle.italic, height: 1.4),
      ),
      const SizedBox(height: 32),
      TextField(
        controller: _ctrl,
        autofocus: true,
        maxLength: 200,
        maxLines: 4,
        textCapitalization: TextCapitalization.sentences,
        style: const TextStyle(color: Colors.white, fontSize: 15),
        decoration: InputDecoration(
          counterText: '',
          hintText: 'La pensée qui revient...',
          hintStyle: TextStyle(
              color: Colors.white.withValues(alpha: 0.22), fontSize: 14),
          filled: true,
          fillColor: Colors.white.withValues(alpha: 0.04),
          border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14),
              borderSide: BorderSide.none),
          focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14),
              borderSide: BorderSide(color: _lilas, width: 1.5)),
        ),
        onChanged: (_) => setState(() {}),
      ),
      const SizedBox(height: 28),
      SizedBox(
        width: double.infinity,
        child: ElevatedButton(
          onPressed: _ctrl.text.trim().isNotEmpty ? _submit : null,
          style: ElevatedButton.styleFrom(
              backgroundColor: _dark,
              disabledBackgroundColor: _dark.withValues(alpha: 0.30),
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 14),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(30)),
              elevation: 0),
          child: const Text('Observer cette pensée',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
        ),
      ),
      const Spacer(),
    ]),
  );

  Widget _buildReformulation() => Container(
    key: const ValueKey('reform'),
    color: _bg,
    child: SafeArea(child: Center(child: Padding(
      padding: const EdgeInsets.symmetric(horizontal: 36),
      child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
        Text('Vous avez la pensée que',
            style: TextStyle(
                color: Colors.white.withValues(alpha: 0.40),
                fontSize: 14, fontWeight: FontWeight.w300)),
        const SizedBox(height: 20),
        Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            color: _lilas.withValues(alpha: 0.06),
            border: Border.all(color: _lilas.withValues(alpha: 0.20)),
          ),
          child: Text(
            '"$_thought"',
            textAlign: TextAlign.center,
            style: const TextStyle(
                fontFamily: 'Gelica', color: Colors.white,
                fontSize: 18, fontWeight: FontWeight.w200,
                fontStyle: FontStyle.italic, height: 1.5),
          ),
        ),
      ]),
    ))),
  );

  Widget _buildPause() => Container(
    key: const ValueKey('pause'),
    color: _bg,
    child: SafeArea(child: Center(child: Padding(
      padding: const EdgeInsets.symmetric(horizontal: 36),
      child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
        Text('"$_thought"',
            textAlign: TextAlign.center,
            style: TextStyle(
                fontFamily: 'Gelica',
                color: Colors.white.withValues(alpha: 0.35),
                fontSize: 16, fontWeight: FontWeight.w200,
                fontStyle: FontStyle.italic)),
        const SizedBox(height: 32),
        const Text(
          'Cette pensée est\nun événement mental,\npas une vérité.',
          textAlign: TextAlign.center,
          style: TextStyle(
              fontFamily: 'Gelica', color: Colors.white,
              fontSize: 20, fontWeight: FontWeight.w200,
              fontStyle: FontStyle.italic, height: 1.5),
        ),
        const SizedBox(height: 40),
        LinearProgressIndicator(
          value: _pauseElapsed / 10,
          backgroundColor: Colors.white.withValues(alpha: 0.08),
          valueColor: const AlwaysStoppedAnimation(_lilas),
        ),
      ]),
    ))),
  );

  Widget _buildChoice() => Container(
    key: const ValueKey('choice'),
    color: _bg,
    child: SafeArea(child: Center(child: Padding(
      padding: const EdgeInsets.symmetric(horizontal: 36),
      child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
        const Text(
          'Que souhaitez-vous\nfaire avec cette pensée ?',
          textAlign: TextAlign.center,
          style: TextStyle(
              fontFamily: 'Gelica', color: Colors.white,
              fontSize: 19, fontWeight: FontWeight.w200,
              fontStyle: FontStyle.italic),
        ),
        const SizedBox(height: 40),
        _ChoiceButton(
          label: 'La laisser passer',
          icon: Icons.air,
          color: _teal,
          onTap: () => _choose('laisser'),
        ),
        const SizedBox(height: 14),
        _ChoiceButton(
          label: 'La noter pour plus tard',
          icon: Icons.bookmark_border,
          color: _gold,
          onTap: () => _choose('noter'),
        ),
        const SizedBox(height: 14),
        _ChoiceButton(
          label: 'La contester',
          icon: Icons.search,
          color: _lilas,
          onTap: () => _choose('contester'),
        ),
      ]),
    ))),
  );

  Widget _buildComplete() => Stack(
    key: const ValueKey('done'),
    fit: StackFit.expand,
    children: [
      Image.asset('assets/images/Fonds-02.png', fit: BoxFit.cover),
      Container(color: Colors.white.withValues(alpha: 0.10)),
      SafeArea(child: Center(child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 36),
        child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
          Container(
            width: 88, height: 88,
            decoration: const BoxDecoration(shape: BoxShape.circle, color: _dark),
            child: const Icon(_Ico.magic, color: Colors.white, size: 44),
          ),
          const SizedBox(height: 28),
          const Text("'Vous avez observé\nvotre pensée avec distance.'",
              textAlign: TextAlign.center,
              style: TextStyle(
                  fontFamily: 'Gelica', color: Color(0xFF232323),
                  fontSize: 22, fontWeight: FontWeight.w200,
                  fontStyle: FontStyle.italic, height: 1.45)),
          const SizedBox(height: 52),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: () => Navigator.of(context).pop(),
              style: ElevatedButton.styleFrom(
                  backgroundColor: _dark, foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 10),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(30)),
                  elevation: 0),
              child: const Text('Continuer',
                  style: TextStyle(fontSize: 17, fontWeight: FontWeight.w600)),
            ),
          ),
        ]),
      ))),
    ],
  );
}

class _ChoiceButton extends StatelessWidget {
  final String label;
  final IconData icon;
  final Color color;
  final VoidCallback onTap;
  const _ChoiceButton({
    required this.label, required this.icon,
    required this.color, required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          color: color.withValues(alpha: 0.08),
          border: Border.all(color: color.withValues(alpha: 0.25)),
        ),
        child: Row(children: [
          Icon(icon, color: color, size: 22),
          const SizedBox(width: 14),
          Text(label,
              style: TextStyle(
                  color: color, fontSize: 15, fontWeight: FontWeight.w500)),
        ]),
      ),
    );
  }
}
