import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'dart:async';
import 'dart:math' as Math;
import 'database_helper.dart';
import 'package:window_manager/window_manager.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  // Initialize window manager for desktop platforms
  await windowManager.ensureInitialized();

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
  final List<SavedGreeting> _savedGreetings = [];
  bool _isLoading = true;
  bool _isFullScreen = false;

  @override
  void initState() {
    super.initState();
    _loadAll();
  }

  Future<void> _loadAll() async {
    final dbTimers = await DatabaseHelper.instance.getAllTimers();
    final dbGreetings = await DatabaseHelper.instance.getAllGreetings();
    final List<SavedTimer> overdueScheduled = [];

    setState(() {
      _savedTimers.clear();
      for (var timerMap in dbTimers) {
        final timer = SavedTimer.fromMap(timerMap);
        timer.onScheduledStart = () => _onTimerScheduledStart(timer);
        _savedTimers.add(timer);

        // Detect timers whose scheduled time has already passed while the
        // app was closed — we'll re-run _scheduleTimer for them now that the
        // onScheduledStart callback is wired up.
        if (timer.scheduledTime != null &&
            timer.wasScheduledStart &&
            timer.scheduledTime!.isBefore(DateTime.now())) {
          overdueScheduled.add(timer);
        }
      }

      _savedGreetings.clear();
      for (var greetingMap in dbGreetings) {
        _savedGreetings.add(SavedGreeting.fromMap(greetingMap));
      }

      _isLoading = false;
    });

    // Re-run _scheduleTimer() for any scheduled timers that should have
    // already fired while the app was closed. The SavedTimer constructor
    // couldn't invoke onScheduledStart because the callback wasn't wired yet,
    // so we trigger the schedule now — it will compute remaining time, call
    // start(), and fire onScheduledStart → auto-routing to the running page.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      for (var timer in overdueScheduled) {
        timer.rescheduleIfOverdue();
      }
    });
  }

  Future<void> _toggleFullScreen() async {
    setState(() {
      _isFullScreen = !_isFullScreen;
    });

    if (_isFullScreen) {
      await windowManager.setFullScreen(true);
    } else {
      await windowManager.setFullScreen(false);
    }
  }

  void _onTimerScheduledStart(SavedTimer timer) {
    if (!mounted) return;

    // Always push a fresh running page for this timer. The list page is the
    // root route, so any TimerRunningPage stacked above it represents an
    // active scheduled timer that the user should see ticking down.
    Navigator.push(
      context,
      MaterialPageRoute(
        settings: RouteSettings(name: 'timer-${timer.id}'),
        builder: (context) => TimerRunningPage(savedTimer: timer),
      ),
    );
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

  void _addGreeting() {
    showDialog(
      context: context,
      builder: (context) => AddGreetingDialog(
        onAdd: (title) async {
          final newGreeting = SavedGreeting(title: title);
          final id = await DatabaseHelper.instance.insertGreeting(newGreeting.toMap());
          newGreeting.id = id;
          setState(() {
            _savedGreetings.add(newGreeting);
          });
        },
      ),
    );
  }

  void _openGreeting(SavedGreeting greeting) {
    Navigator.push(
      context,
      MaterialPageRoute(
        settings: RouteSettings(name: 'greeting-${greeting.id}'),
        builder: (context) => GreetingPage(savedGreeting: greeting),
      ),
    );
  }

  void _removeGreeting(int index) async {
    final greeting = _savedGreetings[index];
    if (greeting.id != null) {
      await DatabaseHelper.instance.deleteGreeting(greeting.id!);
    }
    setState(() {
      _savedGreetings.removeAt(index);
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

  Widget _buildTimerCard(SavedTimer timer, int index) {
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
  }

  Widget _buildGreetingCard(SavedGreeting greeting, int index) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: InkWell(
        onTap: () => _openGreeting(greeting),
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Row(
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: const Color(0xFF183f78).withOpacity(0.12),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(
                  Icons.waving_hand,
                  color: Color(0xFF183f78),
                  size: 26,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      greeting.title,
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Tap to display fullscreen',
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.grey[600],
                        fontStyle: FontStyle.italic,
                      ),
                    ),
                  ],
                ),
              ),
              IconButton(
                onPressed: () => _removeGreeting(index),
                icon: const Icon(Icons.delete),
                color: Colors.red,
              ),
            ],
          ),
        ),
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
    return KeyboardListener(
      focusNode: FocusNode(),
      autofocus: true,
      onKeyEvent: (KeyEvent event) {
        if (event is KeyDownEvent && event.logicalKey == LogicalKeyboardKey.f11) {
          _toggleFullScreen();
        }
      },
      child: Scaffold(
        appBar: AppBar(
          backgroundColor: Color(0xFF183f78),
          iconTheme: IconThemeData(color: Colors.white),
          title: const Text(
            'My Timers',
            style: TextStyle(color: Colors.white),
          ),
          actions: [
            IconButton(
              icon: Icon(
                _isFullScreen ? Icons.fullscreen_exit : Icons.fullscreen,
              ),
              onPressed: _toggleFullScreen,
              tooltip: _isFullScreen ? 'Exit Fullscreen' : 'Enter Fullscreen',
            ),
          ],
        ),
        body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // ---------- Timers section ----------
                  Row(
                    children: [
                      const Expanded(
                        child: Text(
                          'Timers',
                          style: TextStyle(
                            fontSize: 22,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF183f78),
                          ),
                        ),
                      ),
                      TextButton.icon(
                        onPressed: _addTimer,
                        icon: const Icon(Icons.add, color: Color(0xFF183f78)),
                        label: const Text(
                          'Add Timer',
                          style: TextStyle(color: Color(0xFF183f78)),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  if (_savedTimers.isEmpty)
                    const Padding(
                      padding: EdgeInsets.symmetric(vertical: 16),
                      child: Text(
                        'No timers yet. Tap "Add Timer" to create one.',
                        textAlign: TextAlign.center,
                        style: TextStyle(color: Colors.black54, fontStyle: FontStyle.italic),
                      ),
                    )
                  else
                    ..._savedTimers.asMap().entries.map((entry) {
                      final index = entry.key;
                      final timer = entry.value;
                      return _buildTimerCard(timer, index);
                    }),

                  const SizedBox(height: 24),

                  // ---------- Greetings section ----------
                  Row(
                    children: [
                      const Expanded(
                        child: Text(
                          'Greeting Pages',
                          style: TextStyle(
                            fontSize: 22,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF183f78),
                          ),
                        ),
                      ),
                      TextButton.icon(
                        onPressed: _addGreeting,
                        icon: const Icon(Icons.add, color: Color(0xFF183f78)),
                        label: const Text(
                          'Add Greeting Page',
                          style: TextStyle(color: Color(0xFF183f78)),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  if (_savedGreetings.isEmpty)
                    const Padding(
                      padding: EdgeInsets.symmetric(vertical: 16),
                      child: Text(
                        'No greeting pages yet. Tap "Add Greeting Page" to create one.',
                        textAlign: TextAlign.center,
                        style: TextStyle(color: Colors.black54, fontStyle: FontStyle.italic),
                      ),
                    )
                  else
                    ..._savedGreetings.asMap().entries.map((entry) {
                      final index = entry.key;
                      final greeting = entry.value;
                      return _buildGreetingCard(greeting, index);
                    }),
                ],
              ),
            ),
      floatingActionButton: null,
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
      _handleOverdueSchedule(now);
      return;
    }

    _schedulerTimer = Timer(difference, () {
      isScheduled = false;
      _notifyListeners();
      onScheduledStart?.call();
      start();
    });
  }

  /// Called after construction (once `onScheduledStart` is wired up) to
  /// re-evaluate any scheduled timer whose trigger time has already passed.
  /// Computes the remaining time, starts the countdown, and auto-routes to
  /// the running screen via `onScheduledStart`.
  void rescheduleIfOverdue() {
    if (scheduledTime == null) return;
    if (isRunning) return; // Already running, nothing to do.

    final now = DateTime.now();
    if (scheduledTime!.isAfter(now)) {
      // Not overdue anymore — just rely on the normal _schedulerTimer.
      return;
    }

    _handleOverdueSchedule(now);
  }

  void _handleOverdueSchedule(DateTime now) {
    // Scheduled time has already passed (e.g. app was closed when trigger fired).
    // Don't drop the timer — compute remaining seconds from how much of the
    // duration has elapsed since the scheduled start, cap it to the full
    // duration, and notify listeners so the running page can auto-launch.
    final elapsedSinceStart = now.difference(scheduledTime!).inSeconds;
    final recomputed = totalSeconds - elapsedSinceStart;

    if (recomputed <= 0) {
      // The whole timer has already expired — nothing left to run.
      remainingSeconds = 0;
      isScheduled = false;
      _notifyListeners();
      return;
    }

    // Some time still remains — clamp to total duration in case the timer
    // was scheduled far in the past relative to its own length.
    remainingSeconds = recomputed > totalSeconds ? totalSeconds : recomputed;
    isScheduled = false;
    _notifyListeners();

    // Auto-launch the running screen (if a callback is wired up) and start
    // the countdown with the recomputed remaining time.
    onScheduledStart?.call();
    start();
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

class _TimerRunningPageState extends State<TimerRunningPage> with TickerProviderStateMixin {
  Timer? _clockTimer;
  bool _showEndModal = false;
  bool _isFullScreen = false;
  bool _isPageActive = true; // Track if this page is still active
  bool _isModalShowing = false; // Track if modal is currently visible
  late AnimationController _waveController;
  late Animation<double> _waveAnimation;
  late AnimationController _progressController;
  late Animation<double> _progressAnimation;
  double _currentProgress = 0.0;
  double _targetProgress = 0.0;

  @override
  void initState() {
    super.initState();
    widget.savedTimer.addListener(_onTimerUpdate);

    // Initialize wave animation for smooth, continuous wave motion
    _waveController = AnimationController(
      duration: const Duration(milliseconds: 1500),
      vsync: this,
    )..repeat(); // Continuous repeat without reverse for flowing water effect

    _waveAnimation = Tween<double>(begin: 0, end: 1).animate(
      CurvedAnimation(parent: _waveController, curve: Curves.linear),
    );

    // Initialize smooth progress animation controller
    _progressController = AnimationController(
      duration: const Duration(milliseconds: 1000), // 1 second smooth transition
      vsync: this,
    );

    _progressAnimation = Tween<double>(begin: 0, end: 0).animate(
      CurvedAnimation(parent: _progressController, curve: Curves.linear),
    )..addListener(() {
      setState(() {
        _currentProgress = _progressAnimation.value;
      });
    });

    // Calculate initial progress
    _currentProgress = widget.savedTimer.totalSeconds > 0
        ? (widget.savedTimer.totalSeconds - widget.savedTimer.remainingSeconds) / widget.savedTimer.totalSeconds
        : 0.0;
    _targetProgress = _currentProgress;

    // Update the clock every second
    _clockTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (mounted) {
        setState(() {});
      }
    });
  }

  @override
  void dispose() {
    _isPageActive = false;
    widget.savedTimer.removeListener(_onTimerUpdate);
    _clockTimer?.cancel();
    _waveController.dispose();
    _progressController.dispose();
    // Ensure any dialog still showing is closed and flags cleared
    _closeModalSafely();
    super.dispose();
  }

  @override
  void deactivate() {
    // Mark page as inactive when navigation moves away from this page
    _isPageActive = false;

    // Close the modal immediately if it's showing and clear overlay flag
    _closeModalSafely();

    super.deactivate();
  }

  @override
  void activate() {
    // Mark page as active when navigation returns to this page
    _isPageActive = true;
    super.activate();
  }

  void _closeModalSafely() {
    if (_isModalShowing) {
      _isModalShowing = false;
      _showEndModal = false;

      // Use post-frame callback to ensure we're not in the middle of a build
      WidgetsBinding.instance.addPostFrameCallback((_) {
        try {
          if (mounted && Navigator.of(context, rootNavigator: true).canPop()) {
            Navigator.of(context, rootNavigator: true).pop();
          }
        } catch (_) {
          // Silently handle any navigation errors
        }
      });
    }
  }

  Future<void> _toggleFullScreen() async {
    setState(() {
      _isFullScreen = !_isFullScreen;
    });

    if (_isFullScreen) {
      await windowManager.setFullScreen(true);
    } else {
      await windowManager.setFullScreen(false);
    }
  }

  void _onTimerUpdate() {
    // Calculate new target progress
    final newTargetProgress = widget.savedTimer.totalSeconds > 0
        ? (widget.savedTimer.totalSeconds - widget.savedTimer.remainingSeconds) / widget.savedTimer.totalSeconds
        : 0.0;

    // Animate progress smoothly from current to target over 1 second
    if (newTargetProgress != _targetProgress) {
      _targetProgress = newTargetProgress;

      _progressAnimation = Tween<double>(
        begin: _currentProgress,
        end: _targetProgress,
      ).animate(
        CurvedAnimation(parent: _progressController, curve: Curves.linear),
      )..addListener(() {
        if (mounted) {
          setState(() {
            _currentProgress = _progressAnimation.value;
          });
        }
      });

      _progressController.forward(from: 0.0);
    }

    if (mounted) {
      setState(() {});
    }

    // Check if timer has 1 second remaining and has an end message
    // Show modal 1 second before timer ends to ensure visibility
    // Only show if:
    // 1. This page is still active (not replaced by new scheduled timer)
    // 2. Widget is still mounted
    // 3. Modal is not already showing
    // 4. Timer has an end message
    if (widget.savedTimer.remainingSeconds == 1 &&
        widget.savedTimer.isRunning &&
        !_showEndModal &&
        !_isModalShowing &&
        _isPageActive &&
        mounted &&
        widget.savedTimer.endMessage != null &&
        widget.savedTimer.endMessage!.isNotEmpty) {
      _showEndModal = true;
      // Use post-frame callback to ensure we're not in the middle of a build
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted && _isPageActive && !_isModalShowing) {
          _showTimerEndModal();
        }
      });
    }
  }

  void _showTimerEndModal() {
    if (!_isPageActive || !mounted || _isModalShowing) return;

    final message = widget.savedTimer.endMessage!;
    _isModalShowing = true;
    _showEndModal = true;

    showDialog(
      context: context,
      barrierDismissible: false,
      useRootNavigator: true,
      builder: (context) => WillPopScope(
        onWillPop: () async => false, // Prevent back button from dismissing
        child: Dialog(
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
                    // Clear flags before navigation
                    _isModalShowing = false;
                    _showEndModal = false;

                    // Only close the dialog, stay on the timer page
                    try {
                      if (Navigator.of(context, rootNavigator: true).canPop()) {
                        Navigator.of(context, rootNavigator: true).pop();
                      }
                    } catch (_) {
                      // Silently handle navigation errors
                    }
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
      ),
    ).then((_) {
      // Dialog closed manually. Clear flags.
      if (mounted) {
        setState(() {
          _isModalShowing = false;
          _showEndModal = false;
        });
      }
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
    final isScheduled = widget.savedTimer.isScheduled;
    final wasScheduledStart = widget.savedTimer.wasScheduledStart;
    // Use the smoothly animated progress value
    final progress = _currentProgress;

    return KeyboardListener(
      focusNode: FocusNode(),
      autofocus: true,
      onKeyEvent: (KeyEvent event) {
        if (event is KeyDownEvent && event.logicalKey == LogicalKeyboardKey.f11) {
          _toggleFullScreen();
        }
      },
      child: Scaffold(
        appBar: AppBar(
          backgroundColor: Color(0xFF183f78),
          iconTheme: IconThemeData(color: Colors.white),
          leading: IconButton(
            icon: const Icon(Icons.arrow_back),
            onPressed: () {
              Navigator.of(context).pop();
            },
          ),
          title: Text(
            widget.savedTimer.name,
            style: TextStyle(
              color: Colors.white,
            ),
          ),
          actions: [
            IconButton(
              icon: Icon(
                _isFullScreen ? Icons.fullscreen_exit : Icons.fullscreen,
              ),
              onPressed: _toggleFullScreen,
              tooltip: _isFullScreen ? 'Exit Fullscreen' : 'Enter Fullscreen',
            ),
          ],
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
          SingleChildScrollView(
            child: ConstrainedBox(
              constraints: BoxConstraints(
                minHeight: MediaQuery.of(context).size.height - kToolbarHeight,
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
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
                child: Stack(
                  children: [
                    // Main timer text (base layer)
                    Text(
                      _formatTime(widget.savedTimer.remainingSeconds),
                      style: const TextStyle(
                        fontSize: 200,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                        height: 1.0,
                        fontFamily: 'Courier',
                        fontFeatures: [FontFeature.tabularFigures()],
                      ),
                    ),
                    // Water fill effect overlay with wave animation
                    AnimatedBuilder(
                      animation: _waveAnimation,
                      builder: (context, child) {
                        return ClipPath(
                          clipper: WaterWaveClipper(
                            progress: progress,
                            waveOffset: _waveAnimation.value,
                          ),
                          child: ShaderMask(
                            shaderCallback: (Rect bounds) {
                              return LinearGradient(
                                begin: Alignment.topCenter,
                                end: Alignment.bottomCenter,
                                colors: [
                                  Color(0xFF00D4FF).withOpacity(0.8), // Bright cyan at top
                                  Color(0xFF0099FF).withOpacity(0.9), // Blue in middle
                                  Color(0xFF0066FF), // Deeper blue at bottom
                                ],
                                stops: [0.0, 0.5, 1.0],
                              ).createShader(bounds);
                            },
                            child: Text(
                              _formatTime(widget.savedTimer.remainingSeconds),
                              style: TextStyle(
                                fontSize: 200,
                                fontWeight: FontWeight.bold,
                                color: Colors.white,
                                height: 1.0,
                                fontFamily: 'Courier',
                                fontFeatures: [FontFeature.tabularFigures()],
                                // shadows: [
                                //   Shadow(
                                //     color: Color(0xFF00D4FF).withOpacity(0.5),
                                //     blurRadius: 20,
                                //     offset: Offset(0, 0),
                                //   ),
                                //   Shadow(
                                //     color: Color(0xFF0099FF).withOpacity(0.3),
                                //     blurRadius: 30,
                                //     offset: Offset(0, 5),
                                //   ),
                                // ],
                              ),
                            ),
                          ),
                        );
                      },
                    ),
                  ],
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
          ),
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

// Custom clipper for water wave effect
class WaterWaveClipper extends CustomClipper<Path> {
  final double progress;
  final double waveOffset;

  WaterWaveClipper({required this.progress, required this.waveOffset});

  @override
  Path getClip(Size size) {
    final path = Path();

    // Calculate water level - rises from bottom (0) to top (size.height)
    // progress goes from 0.0 to 1.0 as timer counts down
    final waterLevel = size.height * (1 - progress);

    // If no progress yet, return empty path
    if (progress <= 0.0) {
      return path;
    }

    // If fully filled, return full rectangle
    if (progress >= 1.0) {
      path.addRect(Rect.fromLTWH(0, 0, size.width, size.height));
      return path;
    }

    // Wave parameters for realistic water motion
    final waveHeight = 8.0; // Reduced height for subtler waves
    final waveCount = 3.0; // Number of waves across the width
    final waveFrequency = (waveCount * 2 * 3.14159) / size.width;

    // Start from bottom-left corner
    path.moveTo(0, size.height);

    // Draw bottom edge
    path.lineTo(size.width, size.height);

    // Draw right edge up to water level
    path.lineTo(size.width, waterLevel);

    // Create smooth sinusoidal wave at the water surface
    // The waveOffset (0 to 1) animates the wave horizontally
    final phaseShift = waveOffset * 2 * 3.14159;

    // Draw wave from right to left
    for (double x = size.width; x >= 0; x -= 1) {
      final y = waterLevel +
                waveHeight * Math.sin(waveFrequency * x + phaseShift) +
                (waveHeight * 0.3) * Math.sin(waveFrequency * x * 2.3 + phaseShift * 1.7); // Add secondary wave for more realism
      path.lineTo(x, y);
    }

    // Close the path
    path.lineTo(0, waterLevel);
    path.lineTo(0, size.height);
    path.close();

    return path;
  }

  @override
  bool shouldReclip(WaterWaveClipper oldClipper) {
    return oldClipper.progress != progress || oldClipper.waveOffset != waveOffset;
  }
}

// =====================================================================
// Greeting Page feature
// =====================================================================

class SavedGreeting {
  int? id; // Database ID
  final String title;
  final DateTime createdAt;

  SavedGreeting({
    this.id,
    required this.title,
    DateTime? createdAt,
  }) : createdAt = createdAt ?? DateTime.now();

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'title': title,
      'createdAt': createdAt.toIso8601String(),
    };
  }

  factory SavedGreeting.fromMap(Map<String, dynamic> map) {
    return SavedGreeting(
      id: map['id'] as int?,
      title: map['title'] as String,
      createdAt: DateTime.parse(map['createdAt'] as String),
    );
  }
}

class AddGreetingDialog extends StatefulWidget {
  final Function(String title) onAdd;

  const AddGreetingDialog({super.key, required this.onAdd});

  @override
  State<AddGreetingDialog> createState() => _AddGreetingDialogState();
}

class _AddGreetingDialogState extends State<AddGreetingDialog> {
  final _titleController = TextEditingController();

  @override
  void dispose() {
    _titleController.dispose();
    super.dispose();
  }

  void _add() {
    final title = _titleController.text.trim();
    if (title.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter a greeting page title')),
      );
      return;
    }
    widget.onAdd(title);
    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Add Greeting Page'),
      content: TextField(
        controller: _titleController,
        autofocus: true,
        textInputAction: TextInputAction.done,
        onSubmitted: (_) => _add(),
        maxLength: 80,
        decoration: const InputDecoration(
          labelText: 'Greeting Page Title',
          hintText: 'e.g., Welcome to NSU',
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        ElevatedButton(
          onPressed: _add,
          child: const Text('Add'),
        ),
      ],
    );
  }
}

class GreetingPage extends StatefulWidget {
  final SavedGreeting savedGreeting;

  const GreetingPage({super.key, required this.savedGreeting});

  @override
  State<GreetingPage> createState() => _GreetingPageState();
}

class _GreetingPageState extends State<GreetingPage> with TickerProviderStateMixin {
  Timer? _clockTimer;
  bool _isFullScreen = false;

  late final AnimationController _fadeController;
  late final Animation<double> _fadeAnimation;
  late final AnimationController _slideController;
  late final Animation<Offset> _slideAnimation;
  late final AnimationController _scaleController;
  late final Animation<double> _scaleAnimation;

  @override
  void initState() {
    super.initState();

    _fadeController = AnimationController(
      duration: const Duration(milliseconds: 1400),
      vsync: this,
    )..forward();
    _fadeAnimation = CurvedAnimation(parent: _fadeController, curve: Curves.easeOut);

    _slideController = AnimationController(
      duration: const Duration(milliseconds: 1200),
      vsync: this,
    )..forward();
    _slideAnimation = Tween<Offset>(
      begin: const Offset(0, 0.15),
      end: Offset.zero,
    ).animate(CurvedAnimation(parent: _slideController, curve: Curves.easeOutCubic));

    _scaleController = AnimationController(
      duration: const Duration(milliseconds: 1600),
      vsync: this,
    )..forward();
    _scaleAnimation = Tween<double>(begin: 0.92, end: 1.0).animate(
      CurvedAnimation(parent: _scaleController, curve: Curves.easeOutBack),
    );

    // Tick once per second to keep the clock fresh.
    _clockTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _clockTimer?.cancel();
    _fadeController.dispose();
    _slideController.dispose();
    _scaleController.dispose();
    super.dispose();
  }

  Future<void> _toggleFullScreen() async {
    setState(() {
      _isFullScreen = !_isFullScreen;
    });
    if (_isFullScreen) {
      await windowManager.setFullScreen(true);
    } else {
      await windowManager.setFullScreen(false);
    }
  }

  String _formatDhakaTime12h() {
    final dhaka = DateTime.now().toUtc().add(const Duration(hours: 6));
    int hour = dhaka.hour;
    final amPm = hour >= 12 ? 'PM' : 'AM';
    hour = hour % 12;
    if (hour == 0) hour = 12;

    final h = hour.toString().padLeft(2, '0');
    final m = dhaka.minute.toString().padLeft(2, '0');
    final s = dhaka.second.toString().padLeft(2, '0');
    return '$h:$m:$s $amPm';
  }

  String _formatDhakaDate() {
    final dhaka = DateTime.now().toUtc().add(const Duration(hours: 6));
    const daysOfWeek = [
      'Monday', 'Tuesday', 'Wednesday', 'Thursday',
      'Friday', 'Saturday', 'Sunday'
    ];
    const months = [
      'January', 'February', 'March', 'April', 'May', 'June',
      'July', 'August', 'September', 'October', 'November', 'December'
    ];
    final dayName = daysOfWeek[dhaka.weekday - 1];
    final monthName = months[dhaka.month - 1];
    return '$dayName, $monthName ${dhaka.day}, ${dhaka.year}';
  }

  @override
  Widget build(BuildContext context) {
    final title = widget.savedGreeting.title;
    final mediaQuery = MediaQuery.of(context);

    return KeyboardListener(
      focusNode: FocusNode(),
      autofocus: true,
      onKeyEvent: (KeyEvent event) {
        if (event is KeyDownEvent && event.logicalKey == LogicalKeyboardKey.f11) {
          _toggleFullScreen();
        }
      },
      child: Scaffold(
        appBar: AppBar(
          backgroundColor: const Color(0xFF183f78),
          iconTheme: const IconThemeData(color: Colors.white),
          title: Text(
            title,
            style: const TextStyle(color: Colors.white),
          ),
          actions: [
            IconButton(
              icon: Icon(
                _isFullScreen ? Icons.fullscreen_exit : Icons.fullscreen,
                color: Colors.white,
              ),
              onPressed: _toggleFullScreen,
              tooltip: _isFullScreen ? 'Exit Fullscreen' : 'Enter Fullscreen',
            ),
          ],
        ),
        body: Stack(
          fit: StackFit.expand,
          children: [
            // Campus photo background
            Image.asset(
              'images/greeting_page.png',
              fit: BoxFit.cover,
            ),
            // Dark gradient overlay for legibility
            Positioned.fill(
              child: DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      Colors.black.withOpacity(0.45),
                      Colors.black.withOpacity(0.65),
                      Colors.black.withOpacity(0.80),
                    ],
                    stops: const [0.0, 0.5, 1.0],
                  ),
                ),
              ),
            ),
            // Subtle vignette glow centered behind the title
            Positioned.fill(
              child: IgnorePointer(
                child: Center(
                  child: Container(
                    width: mediaQuery.size.width * 0.9,
                    height: mediaQuery.size.width * 0.9,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: RadialGradient(
                        colors: [
                          const Color(0xFF00D4FF).withOpacity(0.18),
                          const Color(0xFF0099FF).withOpacity(0.05),
                          Colors.transparent,
                        ],
                        stops: const [0.0, 0.6, 1.0],
                      ),
                    ),
                  ),
                ),
              ),
            ),
            // Centered title + clock
            Center(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24.0),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    // Title
                    AnimatedBuilder(
                      animation: Listenable.merge([
                        _fadeAnimation,
                        _slideAnimation,
                        _scaleAnimation,
                      ]),
                      builder: (context, _) {
                        return Opacity(
                          opacity: _fadeAnimation.value,
                          child: SlideTransition(
                            position: _slideAnimation,
                            child: ScaleTransition(
                              scale: _scaleAnimation,
                              child: _GradientTitle(
                                text: title,
                                fontSize: _titleFontSize(mediaQuery.size.width),
                              ),
                            ),
                          ),
                        );
                      },
                    ),
                    const SizedBox(height: 24),
                    // Date
                    FadeTransition(
                      opacity: _fadeAnimation,
                      child: Text(
                        _formatDhakaDate(),
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: _dateFontSize(mediaQuery.size.width),
                          color: Colors.white.withOpacity(0.85),
                          fontWeight: FontWeight.w400,
                          letterSpacing: 1.2,
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    // Live clock
                    FadeTransition(
                      opacity: _fadeAnimation,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 24,
                          vertical: 12,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.08),
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(
                            color: Colors.white.withOpacity(0.25),
                            width: 1,
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: const Color(0xFF00D4FF).withOpacity(0.25),
                              blurRadius: 30,
                              spreadRadius: 2,
                            ),
                          ],
                        ),
                        child: Text(
                          _formatDhakaTime12h(),
                          style: TextStyle(
                            fontSize: _clockFontSize(mediaQuery.size.width),
                            color: Colors.white,
                            fontWeight: FontWeight.w600,
                            fontFamily: 'Courier',
                            letterSpacing: 4,
                            fontFeatures: const [FontFeature.tabularFigures()],
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            // Footer
            Positioned(
              left: 0,
              right: 0,
              bottom: 16,
              child: FadeTransition(
                opacity: _fadeAnimation,
                child: Center(
                  child: Text(
                    'Powered by NSU IT',
                    style: TextStyle(
                      color: Colors.white.withOpacity(0.55),
                      fontFamily: 'Monospace',
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                      letterSpacing: 2,
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  double _titleFontSize(double width) {
    if (width >= 1400) return 120;
    if (width >= 1000) return 96;
    if (width >= 700) return 76;
    if (width >= 500) return 60;
    return 44;
  }

  double _dateFontSize(double width) {
    if (width >= 1000) return 28;
    if (width >= 700) return 22;
    return 18;
  }

  double _clockFontSize(double width) {
    if (width >= 1000) return 80;
    if (width >= 700) return 64;
    if (width >= 500) return 52;
    return 40;
  }
}

/// Animated gradient title used on the GreetingPage. Renders the text with a
/// shimmering cyan→blue→cyan gradient and a soft cyan glow.
class _GradientTitle extends StatefulWidget {
  final String text;
  final double fontSize;

  const _GradientTitle({required this.text, required this.fontSize});

  @override
  State<_GradientTitle> createState() => _GradientTitleState();
}

class _GradientTitleState extends State<_GradientTitle>
    with SingleTickerProviderStateMixin {
  late final AnimationController _shimmerController;

  @override
  void initState() {
    super.initState();
    _shimmerController = AnimationController(
      duration: const Duration(milliseconds: 3500),
      vsync: this,
    )..repeat();
  }

  @override
  void dispose() {
    _shimmerController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _shimmerController,
      builder: (context, _) {
        return ShaderMask(
          blendMode: BlendMode.srcIn,
          shaderCallback: (bounds) => LinearGradient(
            begin: Alignment(-1.0 + 2.0 * _shimmerController.value, -0.3),
            end: Alignment(1.0 + 2.0 * _shimmerController.value, 0.3),
            colors: const [
              Color(0xFF00D4FF),
              Color(0xFF80E5FF),
              Color(0xFFFFFFFF),
              Color(0xFF80E5FF),
              Color(0xFF00D4FF),
            ],
            stops: const [0.0, 0.35, 0.5, 0.65, 1.0],
          ).createShader(bounds),
          child: Text(
            widget.text,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: widget.fontSize,
              fontWeight: FontWeight.w900,
              color: Colors.white,
              height: 1.05,
              letterSpacing: 1.5,
              shadows: [
                Shadow(
                  color: const Color(0xFF00D4FF).withOpacity(0.55),
                  blurRadius: 30,
                  offset: const Offset(0, 0),
                ),
                Shadow(
                  color: const Color(0xFF0099FF).withOpacity(0.35),
                  blurRadius: 50,
                  offset: const Offset(0, 8),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

