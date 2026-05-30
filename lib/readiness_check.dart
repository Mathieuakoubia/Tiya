// Routine 30 — Préparation mentale avant un événement
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:vibration/vibration.dart';

class _Ico {
  static const String _f = 'icomoon';
  static const IconData calendar = IconData(0xe91e, fontFamily: _f);
  static const IconData check    = IconData(0xe92a, fontFamily: _f);
}

const _bg    = Color(0xFF121212);
const _teal  = Color(0xFF0DAABA);
const _dark  = Color(0xFF065963);
const _gold  = Color(0xFFE8B86E);
const _lilas = Color(0xFFD9CCE8);

const _bodyScanZones = [
  'Respirez... Sentez votre souffle.',
  'Relâchez vos épaules.',
  'Détendez votre mâchoire.',
  'Posez vos pieds sur le sol.',
];

enum _Step { eventName, bodyScan, breathing, visualization, complete }

class ReadinessCheck extends StatefulWidget {
  final String? eventName;
  final VoidCallback? onComplete;

  const ReadinessCheck({super.key, this.eventName, this.onComplete});

  @override
  State<ReadinessCheck> createState() => _ReadinessCheckState();
}

class _ReadinessCheckState extends State<ReadinessCheck>
    with SingleTickerProviderStateMixin {
  static const int _breathSec   = 30;
  static const int _visuSec     = 30;

  _Step  _step         = _Step.eventName;
  String _event        = '';
  int    _scanIndex    = 0;
  int    _breathElapsed = 0;
  int    _visuElapsed  = 0;
  bool   _isInhaling   = true;

  final _eventCtrl = TextEditingController();

  late AnimationController _breathCtrl;
  late Animation<double>   _breathAnim;

  Timer? _scanTimer;
  Timer? _breathTimer;
  Timer? _visuTimer;

  @override
  void initState() {
    super.initState();
    _breathCtrl = AnimationController(
        duration: const Duration(seconds: 10), vsync: this);
    _breathAnim = TweenSequence<double>([
      TweenSequenceItem(
          tween: Tween(begin: 0.75, end: 1.28)
              .chain(CurveTween(curve: Curves.easeInOut)),
          weight: 5),
      TweenSequenceItem(
          tween: Tween(begin: 1.28, end: 0.75)
              .chain(CurveTween(curve: Curves.easeInOut)),
          weight: 5),
    ]).animate(_breathCtrl);
    _breathCtrl.addListener(() {
      final inhale = _breathCtrl.value < 0.5;
      if (inhale != _isInhaling) setState(() => _isInhaling = inhale);
    });
    if (widget.eventName?.isNotEmpty == true) {
      _event = widget.eventName!;
      _step  = _Step.bodyScan;
      WidgetsBinding.instance.addPostFrameCallback((_) => _startBodyScan());
    }
  }

  void _submitEvent() {
    final txt = _eventCtrl.text.trim();
    if (txt.isEmpty) return;
    setState(() { _event = txt; _step = _Step.bodyScan; });
    _startBodyScan();
  }

  void _startBodyScan() {
    setState(() => _scanIndex = 0);
    _scanTimer = Timer.periodic(const Duration(seconds: 5), (t) {
      if (!mounted) { t.cancel(); return; }
      if (_scanIndex < _bodyScanZones.length - 1) {
        setState(() => _scanIndex++);
        Vibration.vibrate(duration: 80);
      } else {
        t.cancel();
        _startBreathing();
      }
    });
  }

  void _startBreathing() {
    setState(() { _step = _Step.breathing; _breathElapsed = 0; });
    _breathCtrl.repeat();
    Vibration.vibrate(duration: 50);
    _breathTimer = Timer.periodic(const Duration(seconds: 1), (t) {
      if (!mounted) { t.cancel(); return; }
      setState(() => _breathElapsed++);
      if (_breathElapsed >= _breathSec) { t.cancel(); _startVisualization(); }
    });
  }

  void _startVisualization() {
    _breathCtrl.stop();
    setState(() { _step = _Step.visualization; _visuElapsed = 0; });
    _visuTimer = Timer.periodic(const Duration(seconds: 1), (t) {
      if (!mounted) { t.cancel(); return; }
      setState(() => _visuElapsed++);
      if (_visuElapsed >= _visuSec) { t.cancel(); _complete(); }
    });
  }

  void _complete() {
    Vibration.vibrate(pattern: [0, 200, 100, 200]);
    setState(() => _step = _Step.complete);
    widget.onComplete?.call();
  }

  @override
  void dispose() {
    _eventCtrl.dispose();
    _breathCtrl.dispose();
    _scanTimer?.cancel();
    _breathTimer?.cancel();
    _visuTimer?.cancel();
    Vibration.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _bg,
      resizeToAvoidBottomInset: true,
      body: AnimatedSwitcher(
        duration: const Duration(milliseconds: 500),
        child: _buildStep(),
      ),
    );
  }

  Widget _buildStep() {
    switch (_step) {
      case _Step.eventName:     return _buildEventName();
      case _Step.bodyScan:      return _buildBodyScan();
      case _Step.breathing:     return _buildBreathing();
      case _Step.visualization: return _buildVisualization();
      case _Step.complete:      return _buildComplete();
    }
  }

  Widget _buildEventName() => Container(
    key: const ValueKey('event'),
    color: _bg,
    child: SafeArea(child: Padding(
      padding: const EdgeInsets.symmetric(horizontal: 36, vertical: 40),
      child: Column(children: [
        const Spacer(),
        Icon(_Ico.calendar, color: _teal.withValues(alpha: 0.60), size: 48),
        const SizedBox(height: 24),
        const Text(
          'Dans quelques minutes,\nvous allez avoir :',
          textAlign: TextAlign.center,
          style: TextStyle(
              fontFamily: 'Gelica', color: Colors.white,
              fontSize: 20, fontWeight: FontWeight.w200,
              fontStyle: FontStyle.italic),
        ),
        const SizedBox(height: 32),
        TextField(
          controller: _eventCtrl,
          autofocus: true,
          maxLength: 50,
          textCapitalization: TextCapitalization.sentences,
          style: const TextStyle(color: Colors.white, fontSize: 16),
          decoration: InputDecoration(
            counterText: '',
            hintText: 'Réunion, examen, rendez-vous...',
            hintStyle: TextStyle(
                color: Colors.white.withValues(alpha: 0.25), fontSize: 15),
            filled: true,
            fillColor: Colors.white.withValues(alpha: 0.05),
            border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
                borderSide: BorderSide.none),
            focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
                borderSide: BorderSide(color: _teal, width: 1.5)),
          ),
          onSubmitted: (_) => _submitEvent(),
        ),
        const SizedBox(height: 28),
        SizedBox(
          width: double.infinity,
          child: ElevatedButton(
            onPressed: _submitEvent,
            style: ElevatedButton.styleFrom(
                backgroundColor: _dark, foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(30)),
                elevation: 0),
            child: const Text('Préparer ma journée',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
          ),
        ),
        const Spacer(),
      ]),
    )),
  );

  Widget _buildBodyScan() => Container(
    key: const ValueKey('scan'),
    color: _bg,
    child: SafeArea(child: Center(child: Padding(
      padding: const EdgeInsets.symmetric(horizontal: 36),
      child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
        Text('Préparons votre système.',
            textAlign: TextAlign.center,
            style: TextStyle(
                color: Colors.white.withValues(alpha: 0.45),
                fontSize: 14, fontWeight: FontWeight.w300)),
        const SizedBox(height: 40),
        AnimatedSwitcher(
          duration: const Duration(milliseconds: 400),
          child: Text(
            _bodyScanZones[_scanIndex],
            key: ValueKey(_scanIndex),
            textAlign: TextAlign.center,
            style: const TextStyle(
                fontFamily: 'Gelica', color: Colors.white,
                fontSize: 22, fontWeight: FontWeight.w200,
                fontStyle: FontStyle.italic, height: 1.5),
          ),
        ),
        const SizedBox(height: 40),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: List.generate(4, (i) => Container(
            margin: const EdgeInsets.symmetric(horizontal: 4),
            width: i <= _scanIndex ? 10 : 7,
            height: i <= _scanIndex ? 10 : 7,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: i <= _scanIndex
                  ? _teal
                  : Colors.white.withValues(alpha: 0.15),
            ),
          )),
        ),
      ]),
    ))),
  );

  Widget _buildBreathing() => AnimatedBuilder(
    key: const ValueKey('breath'),
    animation: _breathCtrl,
    builder: (_, __) => Stack(children: [
      const Positioned.fill(child: ColoredBox(color: _bg)),
      Center(child: Transform.scale(
        scale: _breathAnim.value,
        child: Container(
          width: 160, height: 160,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: _teal.withValues(alpha: 0.08),
            boxShadow: [BoxShadow(
              color: _teal.withValues(alpha: 0.18),
              blurRadius: 50, spreadRadius: 10)],
          ),
        ),
      )),
      Align(
        alignment: Alignment.topCenter,
        child: SafeArea(child: Padding(
          padding: const EdgeInsets.only(top: 40),
          child: Text(_isInhaling ? 'Inspirez...' : 'Expirez...',
              style: const TextStyle(
                  fontFamily: 'Gelica', color: Colors.white,
                  fontSize: 20, fontWeight: FontWeight.w200,
                  fontStyle: FontStyle.italic)),
        )),
      ),
    ]),
  );

  Widget _buildVisualization() => Container(
    key: const ValueKey('visu'),
    color: _bg,
    child: SafeArea(child: Center(child: Padding(
      padding: const EdgeInsets.symmetric(horizontal: 36),
      child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
        Container(
          width: 80, height: 80,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: _gold.withValues(alpha: 0.10),
            border: Border.all(color: _gold.withValues(alpha: 0.30)),
          ),
          child: Icon(_Ico.check, color: _gold.withValues(alpha: 0.70), size: 36),
        ),
        const SizedBox(height: 32),
        Text(
          'Imaginez-vous à la fin\nde $_event.',
          textAlign: TextAlign.center,
          style: const TextStyle(
              fontFamily: 'Gelica', color: Colors.white,
              fontSize: 20, fontWeight: FontWeight.w200,
              fontStyle: FontStyle.italic, height: 1.5),
        ),
        const SizedBox(height: 16),
        Text('Vous l\'avez traversé. Comment vous sentez-vous ?',
            textAlign: TextAlign.center,
            style: TextStyle(
                color: Colors.white.withValues(alpha: 0.40),
                fontSize: 14, height: 1.5)),
        const SizedBox(height: 36),
        LinearProgressIndicator(
          value: _visuElapsed / _visuSec,
          backgroundColor: Colors.white.withValues(alpha: 0.08),
          valueColor: const AlwaysStoppedAnimation(_gold),
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
            child: const Icon(_Ico.check, color: Colors.white, size: 44),
          ),
          const SizedBox(height: 28),
          Text("'Vous êtes prête\npour $_event.'",
              textAlign: TextAlign.center,
              style: const TextStyle(
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
