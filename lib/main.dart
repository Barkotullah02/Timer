import 'package:flutter/material.dart';
import 'dart:async';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Multi Timer',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.deepPurple),
        useMaterial3: true,
      ),
      home: const TimerHomePage(),
    );
  }
}

class TimerHomePage extends StatefulWidget {
  const TimerHomePage({super.key});

  @override
  State<TimerHomePage> createState() => _TimerHomePageState();
}

class _TimerHomePageState extends State<TimerHomePage> {
  final List<TimerItem> _timers = [];

  void _addTimer() {
    setState(() {
      _timers.add(TimerItem());
    });
  }

  void _removeTimer(int index) {
    setState(() {
      _timers[index].dispose();
      _timers.removeAt(index);
    });
  }

  @override
  void dispose() {
    for (var timer in _timers) {
      timer.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
        title: const Text('Multi Timer'),
      ),
      body: _timers.isEmpty
          ? const Center(
              child: Text('No timers. Add one using the + button!'),
            )
          : ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: _timers.length,
              itemBuilder: (context, index) {
                return TimerWidget(
                  timer: _timers[index],
                  onRemove: () => _removeTimer(index),
                );
              },
            ),
      floatingActionButton: FloatingActionButton(
        onPressed: _addTimer,
        child: const Icon(Icons.add),
      ),
    );
  }
}

class TimerItem {
  int hours = 0;
  int minutes = 0;
  int seconds = 0;
  int remainingSeconds = 0;
  Timer? _timer;
  bool isRunning = false;
  final ValueNotifier<int> notifier = ValueNotifier<int>(0);

  void start() {
    if (hours == 0 && minutes == 0 && seconds == 0) return;

    // Prevent multiple timers from running
    if (isRunning) return;

    // Cancel any existing timer as a safety measure
    _timer?.cancel();

    if (remainingSeconds == 0) {
      remainingSeconds = hours * 3600 + minutes * 60 + seconds;
    }

    isRunning = true;
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (remainingSeconds > 0) {
        remainingSeconds--;
        notifier.value = remainingSeconds;
      } else {
        stop();
      }
    });
  }

  void pause() {
    isRunning = false;
    _timer?.cancel();
  }

  void reset() {
    _timer?.cancel();
    isRunning = false;
    remainingSeconds = 0;
    notifier.value = 0;
  }

  void stop() {
    _timer?.cancel();
    isRunning = false;
  }

  void dispose() {
    _timer?.cancel();
    notifier.dispose();
  }
}

class TimerWidget extends StatefulWidget {
  final TimerItem timer;
  final VoidCallback onRemove;

  const TimerWidget({
    super.key,
    required this.timer,
    required this.onRemove,
  });

  @override
  State<TimerWidget> createState() => _TimerWidgetState();
}

class _TimerWidgetState extends State<TimerWidget> {
  final _hoursController = TextEditingController();
  final _minutesController = TextEditingController();
  final _secondsController = TextEditingController();

  @override
  void dispose() {
    _hoursController.dispose();
    _minutesController.dispose();
    _secondsController.dispose();
    super.dispose();
  }

  void _setTimer() {
    setState(() {
      widget.timer.hours = int.tryParse(_hoursController.text) ?? 0;
      widget.timer.minutes = int.tryParse(_minutesController.text) ?? 0;
      widget.timer.seconds = int.tryParse(_secondsController.text) ?? 0;
      widget.timer.reset();
    });
  }

  String _formatTime(int totalSeconds) {
    int h = totalSeconds ~/ 3600;
    int m = (totalSeconds % 3600) ~/ 60;
    int s = totalSeconds % 60;
    return '${h.toString().padLeft(2, '0')}:${m.toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _hoursController,
                    decoration: const InputDecoration(labelText: 'Hours'),
                    keyboardType: TextInputType.number,
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: TextField(
                    controller: _minutesController,
                    decoration: const InputDecoration(labelText: 'Minutes'),
                    keyboardType: TextInputType.number,
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: TextField(
                    controller: _secondsController,
                    decoration: const InputDecoration(labelText: 'Seconds'),
                    keyboardType: TextInputType.number,
                  ),
                ),
                const SizedBox(width: 8),
                ElevatedButton(
                  onPressed: _setTimer,
                  child: const Text('Set'),
                ),
              ],
            ),
            const SizedBox(height: 16),
            ValueListenableBuilder<int>(
              valueListenable: widget.timer.notifier,
              builder: (context, value, child) {
                return Text(
                  _formatTime(widget.timer.remainingSeconds),
                  style: Theme.of(context).textTheme.headlineLarge,
                );
              },
            ),
            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                ElevatedButton.icon(
                  onPressed: () {
                    setState(() {
                      widget.timer.start();
                    });
                  },
                  icon: const Icon(Icons.play_arrow),
                  label: const Text('Start'),
                ),
                const SizedBox(width: 8),
                ElevatedButton.icon(
                  onPressed: () {
                    setState(() {
                      widget.timer.pause();
                    });
                  },
                  icon: const Icon(Icons.pause),
                  label: const Text('Pause'),
                ),
                const SizedBox(width: 8),
                ElevatedButton.icon(
                  onPressed: () {
                    setState(() {
                      widget.timer.reset();
                    });
                  },
                  icon: const Icon(Icons.refresh),
                  label: const Text('Reset'),
                ),
                const SizedBox(width: 8),
                IconButton(
                  onPressed: widget.onRemove,
                  icon: const Icon(Icons.delete),
                  color: Colors.red,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
