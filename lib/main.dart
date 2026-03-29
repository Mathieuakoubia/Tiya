import 'package:flutter/material.dart';
import 'emdr_widget.dart';
import 'soothing_thumb.dart';
import 'cognitive_sorting.dart';
import 'aura_cleaning.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Tiyia MVP',
      theme: ThemeData(
        brightness: Brightness.dark,
        primarySwatch: Colors.blue,
        scaffoldBackgroundColor: const Color(0xFF121212),
        useMaterial3: true,
      ),
      home: const HomePage(),
    );
  }
}

class HomePage extends StatelessWidget {
  const HomePage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Tiyia - Prototypes")),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Text(
              "Selectionnez une routine",
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 40),

            // BOUTON 1 : EMDR
            SizedBox(
              width: 280,
              height: 60,
              child: ElevatedButton.icon(
                icon: const Icon(Icons.remove_red_eye),
                label: const Text(" Saccadic Reset "),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.blueAccent,
                  foregroundColor: Colors.white,
                  textStyle: const TextStyle(fontSize: 18),
                ),
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => const EyeMovementEMDR(
                        baseSpeedDuration: 2000,
                      ),
                    ),
                  );
                },
              ),
            ),

            const SizedBox(height: 20),

            // BOUTON 2 : POUCE APAISANT
            SizedBox(
              width: 280,
              height: 60,
              child: ElevatedButton.icon(
                icon: const Icon(Icons.fingerprint),
                label: const Text("Le Pouce Apaisant"),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.teal,
                  foregroundColor: Colors.white,
                  textStyle: const TextStyle(fontSize: 18),
                ),
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                        builder: (context) => const SoothingThumb()),
                  );
                },
              ),
            ),

            const SizedBox(height: 20),

            // BOUTON 3 : COGNITIVE SORTING
            SizedBox(
              width: 280,
              height: 60,
              child: ElevatedButton.icon(
                icon: const Icon(Icons.delete_sweep_outlined),
                label: const Text("Vide-Poubelle Mental"),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF735983),
                  foregroundColor: Colors.white,
                  textStyle: const TextStyle(fontSize: 18),
                ),
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => const CognitiveSorting(),
                    ),
                  );
                },
              ),
            ),

            const SizedBox(height: 20),

            // BOUTON 4 : AURA CLEANING
            SizedBox(
              width: 280,
              height: 60,
              child: ElevatedButton.icon(
                icon: const Icon(Icons.auto_awesome),
                label: const Text("Aura Cleaning"),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF82667F),
                  foregroundColor: Colors.white,
                  textStyle: const TextStyle(fontSize: 18),
                ),
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => const AuraCleaning(),
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}
