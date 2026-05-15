import 'package:flutter/material.dart';
import '../../../training/presentation/widgets/training_history_tab.dart';

class ActivityScreen extends StatelessWidget {
  const ActivityScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('HISTORIA')),
      body: const SafeArea(child: TrainingHistoryTab()),
    );
  }
}
