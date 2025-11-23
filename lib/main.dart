import 'package:flutter/material.dart';
import 'dart:async';
import 'database_helper.dart';

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
      debugShowCheckedModeBanner: false,
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
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadTimers();
  }

  Future<void> _loadTimers() async {
    final dbTimers = await DatabaseHelper.instance.getAllTimers();
    setState(() {
      _savedTimers.clear();
      for (var timerMap in dbTimers) {
        final timer = SavedTimer.fromMap(timerMap);
        timer.onScheduledStart = () => _onTimerScheduledStart(timer);
        _savedTimers.add(timer);
      }
      _isLoading = false;
    });
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
        onAdd: (hours, minutes, seconds, name, scheduledTime, endMessage) async {
          final newTimer = SavedTimer(
            name: name,
            hours: hours,
            minutes: minutes,
            seconds: seconds,
            scheduledTime: scheduledTime,
            endMessage: endMessage,
          );
          newTimer.onScheduledStart = () => _onTimerScheduledStart(newTimer);

          // Save to database
          final id = await DatabaseHelper.instance.insertTimer(newTimer.toMap());
          newTimer.id = id;

          setState(() {
            _savedTimers.add(newTimer);
          });
        },
      ),
    );
  }

  void _removeTimer(int index) async {
    final timer = _savedTimers[index];

    // Delete from database if it has an ID
    if (timer.id != null) {
      await DatabaseHelper.instance.deleteTimer(timer.id!);
    }

    setState(() {
      timer.dispose();
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
        backgroundColor: Color(0xFF183f78),
        title: const Text('My Timers'),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _savedTimers.isEmpty
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
  int? id; // Database ID
  final String name;
  final int hours;
  final int minutes;
  final int seconds;
  final DateTime? scheduledTime;
  final String? endMessage; // Custom message to show when timer ends

  int remainingSeconds = 0;
  Timer? _timer;
  Timer? _schedulerTimer;
  bool isRunning = false;
  bool isScheduled = false;
  bool wasScheduledStart = false; // Track if this timer was started by schedule
  final List<VoidCallback> _listeners = [];
  VoidCallback? onScheduledStart;

  SavedTimer({
    this.id,
    required this.name,
    required this.hours,
    required this.minutes,
    required this.seconds,
    this.scheduledTime,
    this.endMessage,
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

  // Convert SavedTimer to Map for database storage
  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'hours': hours,
      'minutes': minutes,
      'seconds': seconds,
      'scheduledTime': scheduledTime?.toIso8601String(),
      'isScheduled': isScheduled ? 1 : 0,
      'wasScheduledStart': wasScheduledStart ? 1 : 0,
      'endMessage': endMessage,
    };
  }

  // Create SavedTimer from Map (database row)
  factory SavedTimer.fromMap(Map<String, dynamic> map) {
    final timer = SavedTimer(
      id: map['id'] as int?,
      name: map['name'] as String,
      hours: map['hours'] as int,
      minutes: map['minutes'] as int,
      seconds: map['seconds'] as int,
      scheduledTime: map['scheduledTime'] != null
          ? DateTime.parse(map['scheduledTime'] as String)
          : null,
      endMessage: map['endMessage'] as String?,
    );
    timer.isScheduled = (map['isScheduled'] as int) == 1;
    timer.wasScheduledStart = (map['wasScheduledStart'] as int) == 1;
    return timer;
  }
}

class AddTimerDialog extends StatefulWidget {
  final Function(int hours, int minutes, int seconds, String name, DateTime? scheduledTime, String? endMessage) onAdd;

  const AddTimerDialog({super.key, required this.onAdd});

  @override
  State<AddTimerDialog> createState() => _AddTimerDialogState();
}

class _AddTimerDialogState extends State<AddTimerDialog> {
  final _nameController = TextEditingController();
  final _hoursController = TextEditingController(text: '0');
  final _minutesController = TextEditingController(text: '0');
  final _secondsController = TextEditingController(text: '0');
  final _endMessageController = TextEditingController();
  DateTime? _scheduledTime;
  bool _enableSchedule = false;

  @override
  void dispose() {
    _nameController.dispose();
    _hoursController.dispose();
    _minutesController.dispose();
    _secondsController.dispose();
    _endMessageController.dispose();
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

    final endMessage = _endMessageController.text.trim().isEmpty
        ? null
        : _endMessageController.text.trim();

    widget.onAdd(hours, minutes, seconds, name, _enableSchedule ? _scheduledTime : null, endMessage);
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
            TextField(
              controller: _endMessageController,
              decoration: const InputDecoration(
                labelText: 'End Message (Optional)',
                hintText: 'Message to show when timer ends',
              ),
              maxLines: 2,
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
  Timer? _clockTimer;
  bool _showEndModal = false;

  @override
  void initState() {
    super.initState();
    widget.savedTimer.addListener(_onTimerUpdate);
    // Update the clock every second
    _clockTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (mounted) {
        setState(() {});
      }
    });
  }

  @override
  void dispose() {
    widget.savedTimer.removeListener(_onTimerUpdate);
    _clockTimer?.cancel();
    super.dispose();
  }

  void _onTimerUpdate() {
    setState(() {});

    // Check if timer has 1 second remaining and has an end message
    // Show modal 1 second before timer ends to ensure visibility
    if (widget.savedTimer.remainingSeconds == 1 &&
        widget.savedTimer.isRunning &&
        !_showEndModal &&
        widget.savedTimer.endMessage != null &&
        widget.savedTimer.endMessage!.isNotEmpty) {
      _showEndModal = true;
      _showTimerEndModal();
    }
  }

  void _showTimerEndModal() {
    final message = widget.savedTimer.endMessage!;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => Dialog(
        backgroundColor: Colors.transparent,
        child: Container(
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Image.asset(
                'images/nsu_logo.png',
                width: 80,
              ),
              const SizedBox(height: 16),
              Text(
                message,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: Colors.black87,
                ),
              ),
              const SizedBox(height: 24),
              ElevatedButton(
                onPressed: () {
                  Navigator.of(context).pop();
                  Navigator.of(context).pop(); // Go back to timer list
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF183f78),
                  padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 12),
                ),
                child: const Text(
                  'OK',
                  style: TextStyle(fontSize: 18, color: Colors.white),
                ),
              ),
            ],
          ),
        ),
      ),
    );
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
    final progress = widget.savedTimer.totalSeconds > 0
        ? 1.0 - (widget.savedTimer.remainingSeconds / widget.savedTimer.totalSeconds)
        : 0.0;

    return Scaffold(
      appBar: AppBar(
        backgroundColor: Color(0xFF183f78),
        title: Text(
            widget.savedTimer.name,
          style: TextStyle(
            color: Colors.white,
          ),
        ),
      ),
      body: Stack(
        children: [
          // Background image
          Positioned.fill(
            child: Image.asset(
              'images/background_img.png',
              fit: BoxFit.cover,
            ),
          ),
          // Dark overlay
          Positioned.fill(
            child: Container(
              color: Colors.black.withOpacity(0.7),
            ),
          ),
          // Extra dark overlay when timer ends
          if (_showEndModal)
            Positioned.fill(
              child: Container(
                color: Colors.black.withOpacity(0.5),
              ),
            ),
          // Content
          Column(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              const SizedBox(height: 12),
              Center(
                child: Image.asset(
                  'images/logo.png',
                  width: 180,
                ),
              ),
              const SizedBox(height: 2),
              Center(
                child: Text(
                  _formatTime(widget.savedTimer.remainingSeconds),
                  style: const TextStyle(
                    fontSize: 190,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                    height: 1.0,
                  ),
                ),
              ),
              const SizedBox(height: 25),
              Center(
                child: Text(
                  _formatCurrentDate(),
                  style: TextStyle(
                    fontSize: 24,
                    color: Colors.white,
                    height: 1.0,
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Center(
                child: Text(
                  _formatCurrentTime(),
                  style: TextStyle(
                    fontSize: 42,
                    color: Colors.white,
                    fontWeight: FontWeight.w500,
                    height: 1.0,
                  ),
                ),
              ),
              const SizedBox(height: 2),
              if (isScheduled && widget.savedTimer.scheduledTime != null)
                Padding(
                  padding: const EdgeInsets.only(bottom: 24),
                  child: Text(
                    'Scheduled to start at ${_formatScheduledTimeDisplay(widget.savedTimer.scheduledTime!)}',
                    style: TextStyle(
                      fontSize: 16,
                      color: Colors.orange[300],
                      fontStyle: FontStyle.italic,
                    ),
                  ),
                ),
              const SizedBox(height: 8),
              Center(
                child: Text(
                  "Powered by NSU IT",
                  style: TextStyle(
                    color: Colors.white.withOpacity(0.5),
                    fontFamily: 'Monospace',
                    fontSize: 24,
                    fontWeight: FontWeight.w600,
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
                    const SizedBox(width: 8),
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
          // Progress bar at the bottom
          Positioned(
            bottom: 0,
            left: 0,
            right: 0,
            child: LinearProgressIndicator(
              value: progress,
              backgroundColor: Colors.white,
              valueColor: const AlwaysStoppedAnimation<Color>(Color(0xFF071642)),
              minHeight: 20,
            ),
          ),
        ],
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

  String _formatCurrentDate() {
    // Get current time in UTC+6 (Dhaka timezone)
    final now = DateTime.now().toUtc().add(const Duration(hours: 6));

    // Get day of week
    const daysOfWeek = ['Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday', 'Saturday', 'Sunday'];
    final dayOfWeek = daysOfWeek[now.weekday - 1];

    // Get month name
    const months = ['January', 'February', 'March', 'April', 'May', 'June',
                    'July', 'August', 'September', 'October', 'November', 'December'];
    final monthName = months[now.month - 1];

    return '$dayOfWeek, $monthName ${now.day}, ${now.year}';
  }

  String _formatCurrentTime() {
    // Get current time in UTC+6 (Dhaka timezone)
    final now = DateTime.now().toUtc().add(const Duration(hours: 6));

    // Format time in 12-hour format
    int hour = now.hour;
    final amPm = hour >= 12 ? 'PM' : 'AM';
    hour = hour % 12;
    if (hour == 0) hour = 12; // Convert 0 to 12 for 12 AM/PM

    final minute = now.minute.toString().padLeft(2, '0');
    final second = now.second.toString().padLeft(2, '0');

    return '$hour:$minute:$second $amPm';
  }
}
