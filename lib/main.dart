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
      home: const TimerListPage(),
    );
  }
}

class TimerListPage extends StatefulWidget {
  const TimerListPage({super.key});

  @override
  State<TimerListPage> createState() => _TimerListPageState();
}

class _TimerListPageState extends State<TimerListPage> {
  final List<SavedTimer> _savedTimers = [];

  @override
  void initState() {
    super.initState();
    // Set up listeners for scheduled timers
    _setupTimerListeners();
  }

  void _setupTimerListeners() {
    for (var timer in _savedTimers) {
      timer.onScheduledStart = () => _onTimerScheduledStart(timer);
    }
  }

  void _onTimerScheduledStart(SavedTimer timer) {
    if (mounted) {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => TimerRunningPage(savedTimer: timer),
        ),
      );
    }
  }

  void _addTimer() {
    showDialog(
      context: context,
      builder: (context) => AddTimerDialog(
        onAdd: (hours, minutes, seconds, name, scheduledTime) {
          setState(() {
            final newTimer = SavedTimer(
              name: name,
              hours: hours,
              minutes: minutes,
              seconds: seconds,
              scheduledTime: scheduledTime,
            );
            newTimer.onScheduledStart = () => _onTimerScheduledStart(newTimer);
            _savedTimers.add(newTimer);
          });
        },
      ),
    );
  }

  void _removeTimer(int index) {
    setState(() {
      _savedTimers[index].dispose();
      _savedTimers.removeAt(index);
    });
  }

  @override
  void dispose() {
    for (var timer in _savedTimers) {
      timer.dispose();
    }
    super.dispose();
  }

  void _startTimer(SavedTimer timer) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => TimerRunningPage(savedTimer: timer),
      ),
    );
  }

  String _formatScheduledTime(DateTime time) {
    final hour = time.hour.toString().padLeft(2, '0');
    final minute = time.minute.toString().padLeft(2, '0');
    final day = time.day.toString().padLeft(2, '0');
    final month = time.month.toString().padLeft(2, '0');

    final now = DateTime.now();
    final isToday = time.day == now.day && time.month == now.month && time.year == now.year;

    if (isToday) {
      return 'Today at $hour:$minute';
    } else {
      return '$day/$month at $hour:$minute';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
        title: const Text('My Timers'),
      ),
      body: _savedTimers.isEmpty
          ? const Center(
              child: Text('No timers. Add one using the + button!'),
            )
          : ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: _savedTimers.length,
              itemBuilder: (context, index) {
                final timer = _savedTimers[index];
                return Card(
                  margin: const EdgeInsets.only(bottom: 12),
                  child: InkWell(
                    onTap: () => _startTimer(timer),
                    child: Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: Row(
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  timer.name,
                                  style: const TextStyle(
                                    fontSize: 18,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  '${timer.hours.toString().padLeft(2, '0')}:${timer.minutes.toString().padLeft(2, '0')}:${timer.seconds.toString().padLeft(2, '0')}',
                                  style: const TextStyle(fontSize: 16),
                                ),
                                if (timer.scheduledTime != null && timer.isScheduled)
                                  Padding(
                                    padding: const EdgeInsets.only(top: 4),
                                    child: Text(
                                      'Scheduled: ${_formatScheduledTime(timer.scheduledTime!)}',
                                      style: TextStyle(
                                        fontSize: 12,
                                        color: Colors.orange[700],
                                        fontStyle: FontStyle.italic,
                                      ),
                                    ),
                                  ),
                              ],
                            ),
                          ),
                          IconButton(
                            onPressed: () => _removeTimer(index),
                            icon: const Icon(Icons.delete),
                            color: Colors.red,
                          ),
                        ],
                      ),
                    ),
                  ),
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

class SavedTimer {
  final String name;
  final int hours;
  final int minutes;
  final int seconds;
  final DateTime? scheduledTime;

  int remainingSeconds = 0;
  Timer? _timer;
  Timer? _schedulerTimer;
  bool isRunning = false;
  bool isScheduled = false;
  bool wasScheduledStart = false; // Track if this timer was started by schedule
  final List<VoidCallback> _listeners = [];
  VoidCallback? onScheduledStart;

  SavedTimer({
    required this.name,
    required this.hours,
    required this.minutes,
    required this.seconds,
    this.scheduledTime,
  }) {
    remainingSeconds = totalSeconds;
    if (scheduledTime != null) {
      isScheduled = true;
      wasScheduledStart = true;
      _scheduleTimer();
    }
  }

  int get totalSeconds => hours * 3600 + minutes * 60 + seconds;

  void _scheduleTimer() {
    if (scheduledTime == null) return;

    final now = DateTime.now();
    final difference = scheduledTime!.difference(now);

    if (difference.isNegative) {
      // Scheduled time has passed
      isScheduled = false;
      return;
    }

    _schedulerTimer = Timer(difference, () {
      isScheduled = false;
      _notifyListeners();
      onScheduledStart?.call();
      start();
    });
  }

  void addListener(VoidCallback listener) {
    _listeners.add(listener);
  }

  void removeListener(VoidCallback listener) {
    _listeners.remove(listener);
  }

  void _notifyListeners() {
    for (var listener in _listeners) {
      listener();
    }
  }

  void start() {
    if (isRunning) return;

    _timer?.cancel();
    isRunning = true;
    _notifyListeners();

    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (remainingSeconds > 0) {
        remainingSeconds--;
        _notifyListeners();
      } else {
        stop();
      }
    });
  }

  void pause() {
    isRunning = false;
    _timer?.cancel();
    _notifyListeners();
  }

  void reset() {
    _timer?.cancel();
    isRunning = false;
    remainingSeconds = totalSeconds;
    _notifyListeners();
  }

  void stop() {
    _timer?.cancel();
    isRunning = false;
    _notifyListeners();
  }

  void dispose() {
    _timer?.cancel();
    _schedulerTimer?.cancel();
    _listeners.clear();
  }
}

class AddTimerDialog extends StatefulWidget {
  final Function(int hours, int minutes, int seconds, String name, DateTime? scheduledTime) onAdd;

  const AddTimerDialog({super.key, required this.onAdd});

  @override
  State<AddTimerDialog> createState() => _AddTimerDialogState();
}

class _AddTimerDialogState extends State<AddTimerDialog> {
  final _nameController = TextEditingController();
  final _hoursController = TextEditingController(text: '0');
  final _minutesController = TextEditingController(text: '0');
  final _secondsController = TextEditingController(text: '0');
  DateTime? _scheduledTime;
  bool _enableSchedule = false;

  @override
  void dispose() {
    _nameController.dispose();
    _hoursController.dispose();
    _minutesController.dispose();
    _secondsController.dispose();
    super.dispose();
  }

  Future<void> _pickScheduledTime() async {
    final date = await showDatePicker(
      context: context,
      initialDate: DateTime.now(),
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 365)),
    );

    if (date == null) return;

    if (!mounted) return;

    final time = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.now(),
    );

    if (time == null) return;

    setState(() {
      _scheduledTime = DateTime(
        date.year,
        date.month,
        date.day,
        time.hour,
        time.minute,
      );
    });
  }

  void _addTimer() {
    final name = _nameController.text.trim();
    if (name.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter a timer name')),
      );
      return;
    }

    final hours = int.tryParse(_hoursController.text) ?? 0;
    final minutes = int.tryParse(_minutesController.text) ?? 0;
    final seconds = int.tryParse(_secondsController.text) ?? 0;

    if (hours == 0 && minutes == 0 && seconds == 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please set a time greater than 0')),
      );
      return;
    }

    if (_enableSchedule && _scheduledTime == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select a scheduled time')),
      );
      return;
    }

    if (_enableSchedule && _scheduledTime!.isBefore(DateTime.now())) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Scheduled time must be in the future')),
      );
      return;
    }

    widget.onAdd(hours, minutes, seconds, name, _enableSchedule ? _scheduledTime : null);
    Navigator.pop(context);
  }

  String _formatScheduledTime(DateTime time) {
    final hour = time.hour.toString().padLeft(2, '0');
    final minute = time.minute.toString().padLeft(2, '0');
    final day = time.day.toString().padLeft(2, '0');
    final month = time.month.toString().padLeft(2, '0');
    final year = time.year;

    return '$day/$month/$year at $hour:$minute';
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Add New Timer'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: _nameController,
              decoration: const InputDecoration(
                labelText: 'Timer Name',
                hintText: 'e.g., Workout, Study, etc.',
              ),
            ),
            const SizedBox(height: 16),
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
              ],
            ),
            const SizedBox(height: 16),
            CheckboxListTile(
              title: const Text('Schedule Timer'),
              value: _enableSchedule,
              onChanged: (value) {
                setState(() {
                  _enableSchedule = value ?? false;
                  if (!_enableSchedule) {
                    _scheduledTime = null;
                  }
                });
              },
            ),
            if (_enableSchedule)
              Column(
                children: [
                  const SizedBox(height: 8),
                  ElevatedButton.icon(
                    onPressed: _pickScheduledTime,
                    icon: const Icon(Icons.schedule),
                    label: Text(
                      _scheduledTime == null
                          ? 'Select Date & Time'
                          : _formatScheduledTime(_scheduledTime!),
                    ),
                  ),
                ],
              ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        ElevatedButton(
          onPressed: _addTimer,
          child: const Text('Add'),
        ),
      ],
    );
  }
}

class TimerRunningPage extends StatefulWidget {
  final SavedTimer savedTimer;

  const TimerRunningPage({super.key, required this.savedTimer});

  @override
  State<TimerRunningPage> createState() => _TimerRunningPageState();
}

class _TimerRunningPageState extends State<TimerRunningPage> {
  @override
  void initState() {
    super.initState();
    widget.savedTimer.addListener(_onTimerUpdate);
  }

  @override
  void dispose() {
    widget.savedTimer.removeListener(_onTimerUpdate);
    super.dispose();
  }

  void _onTimerUpdate() {
    setState(() {});
  }

  String _formatTime(int totalSeconds) {
    int h = totalSeconds ~/ 3600;
    int m = (totalSeconds % 3600) ~/ 60;
    int s = totalSeconds % 60;
    return '${h.toString().padLeft(2, '0')}:${m.toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    final isScheduled = widget.savedTimer.isScheduled;
    final wasScheduledStart = widget.savedTimer.wasScheduledStart;

    return Scaffold(
      appBar: AppBar(
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
        title: Text(widget.savedTimer.name),
      ),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              _formatTime(widget.savedTimer.remainingSeconds),
              style: const TextStyle(
                fontSize: 72,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 16),
            Text(
              _formatCurrentDateTime(),
              style: TextStyle(
                fontSize: 16,
                color: Colors.grey[600],
              ),
            ),
            const SizedBox(height: 48),
            if (isScheduled && widget.savedTimer.scheduledTime != null)
              Padding(
                padding: const EdgeInsets.only(bottom: 24),
                child: Text(
                  'Scheduled to start at ${_formatScheduledTimeDisplay(widget.savedTimer.scheduledTime!)}',
                  style: TextStyle(
                    fontSize: 16,
                    color: Colors.orange[700],
                    fontStyle: FontStyle.italic,
                  ),
                ),
              ),
            // Only show buttons if timer was NOT started by schedule
            if (!wasScheduledStart)
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  ElevatedButton.icon(
                    onPressed: widget.savedTimer.isRunning ? null : () => widget.savedTimer.start(),
                    icon: const Icon(Icons.play_arrow),
                    label: const Text('Start'),
                    style: ElevatedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 24,
                        vertical: 16,
                      ),
                    ),
                  ),
                  const SizedBox(width: 16),
                  ElevatedButton.icon(
                    onPressed: widget.savedTimer.isRunning ? () => widget.savedTimer.pause() : null,
                    icon: const Icon(Icons.pause),
                    label: const Text('Pause'),
                    style: ElevatedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 24,
                        vertical: 16,
                      ),
                    ),
                  ),
                  const SizedBox(width: 16),
                  ElevatedButton.icon(
                    onPressed: () => widget.savedTimer.reset(),
                    icon: const Icon(Icons.refresh),
                    label: const Text('Reset'),
                    style: ElevatedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 24,
                        vertical: 16,
                      ),
                    ),
                  ),
                ],
              ),
          ],
        ),
      ),
    );
  }

  String _formatScheduledTimeDisplay(DateTime time) {
    final hour = time.hour.toString().padLeft(2, '0');
    final minute = time.minute.toString().padLeft(2, '0');
    final day = time.day.toString().padLeft(2, '0');
    final month = time.month.toString().padLeft(2, '0');

    final now = DateTime.now();
    final isToday = time.day == now.day && time.month == now.month && time.year == now.year;

    if (isToday) {
      return 'today at $hour:$minute';
    } else {
      return '$day/$month at $hour:$minute';
    }
  }

  String _formatCurrentDateTime() {
    final now = DateTime.now();

    // Get day of week
    const daysOfWeek = ['Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday', 'Saturday', 'Sunday'];
    final dayOfWeek = daysOfWeek[now.weekday - 1];

    // Get month name
    const months = ['January', 'February', 'March', 'April', 'May', 'June',
                    'July', 'August', 'September', 'October', 'November', 'December'];
    final monthName = months[now.month - 1];

    return '$dayOfWeek, $monthName ${now.day}, ${now.year}';
  }
}
