import 'package:flutter/material.dart';

class AccommodationSettingsView extends StatelessWidget {
  const AccommodationSettingsView({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Majoitusten Asetukset'),
      ),
      body: const Center(
        child: Text(
          'Täällä hallitaan majoituksia.',
          style: TextStyle(fontSize: 18),
        ),
      ),
    );
  }
} 