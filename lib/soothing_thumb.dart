import 'dart:async';
import 'package:flutter/material.dart';
import 'package:vibration/vibration.dart';

class SoothingThumb extends StatefulWidget {
  final Color baseColor;

  const SoothingThumb({
    Key? key,
    this.baseColor = Colors.teal,
  }) : super(key: key);

  @override
  _SoothingThumbState createState() => _SoothingThumbState();
}

class _SoothingThumbState extends State<SoothingThumb>
    with SingleTickerProviderStateMixin {
  late AnimationController _animController;
  late Animation<double> _scaleAnimation;
  late Animation<double> _opacityAnimation;

  Timer? _vibrationTimer;
  bool _isPressed = false;
  String _statusMessage = "Posez votre pouce sur le cercle";

  @override
  void initState() {
    super.initState();

    _animController = AnimationController(
      duration: const Duration(milliseconds: 2000),
      vsync: this,
    );

    _scaleAnimation = Tween<double>(begin: 1.0, end: 4.0).animate(
      CurvedAnimation(parent: _animController, curve: Curves.easeOut),
    );

    _opacityAnimation = Tween<double>(begin: 0.5, end: 0.0).animate(
      CurvedAnimation(parent: _animController, curve: Curves.easeOut),
    );
  }

  void _startRoutine() {
    setState(() {
      _isPressed = true;
      _statusMessage = "Inspirez... Expirez...";
    });

    _animController.repeat();
    _triggerHeartbeat();
    _vibrationTimer =
        Timer.periodic(const Duration(milliseconds: 2000), (timer) {
      _triggerHeartbeat();
    });
  }

  Future<void> _triggerHeartbeat() async {
    if (await Vibration.hasVibrator() ?? false) {
      Vibration.vibrate(
          pattern: [0, 100, 100, 50], intensities: [0, 255, 0, 100]);
    }
  }

  void _stopRoutine() {
    if (!_isPressed) return;

    setState(() {
      _isPressed = false;
      _statusMessage = "Contact rompu";
    });

    _animController.stop();
    _animController.reset();
    _vibrationTimer?.cancel();
    Vibration.cancel();

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        title: const Text("Routine interrompue"),
        content: const Text("Vous avez relache la zone de contact."),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.of(context).pop();
              setState(
                  () => _statusMessage = "Posez votre pouce pour reprendre");
            },
            child: const Text("Reprendre"),
          )
        ],
      ),
    );
  }

  @override
  void dispose() {
    _animController.dispose();
    _vibrationTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF101010),
      appBar: AppBar(
        title: const Text("Routine Apaisante"),
        backgroundColor: Colors.transparent,
        elevation: 0,
      ),
      body: Stack(
        children: [
          Align(
            alignment: Alignment.topCenter,
            child: Padding(
              padding: const EdgeInsets.only(top: 50.0),
              child: Text(
                _statusMessage,
                style: TextStyle(
                  color: Colors.white.withOpacity(0.8),
                  fontSize: 20,
                  fontWeight: FontWeight.w300,
                ),
              ),
            ),
          ),
          Center(
            child: GestureDetector(
              onTapDown: (_) => _startRoutine(),
              onTapUp: (_) => _stopRoutine(),
              onTapCancel: () => _stopRoutine(),
              child: Stack(
                alignment: Alignment.center,
                children: [
                  AnimatedBuilder(
                    animation: _animController,
                    builder: (context, child) {
                      return Opacity(
                        opacity: _opacityAnimation.value,
                        child: Transform.scale(
                          scale: _scaleAnimation.value,
                          child: Container(
                            width: 100,
                            height: 100,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: widget.baseColor.withOpacity(0.5),
                            ),
                          ),
                        ),
                      );
                    },
                  ),
                  Container(
                    width: 100,
                    height: 100,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: widget.baseColor,
                      boxShadow: [
                        BoxShadow(
                          color: widget.baseColor.withOpacity(0.6),
                          blurRadius: 20,
                          spreadRadius: 2,
                        )
                      ],
                    ),
                    child: const Icon(Icons.fingerprint,
                        size: 50, color: Colors.white),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
