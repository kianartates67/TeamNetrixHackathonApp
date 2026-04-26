import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'firebase_options.dart';
import 'models/room.dart';
import 'models/subject.dart';
import 'models/teacher.dart';
import 'models/user.dart';
import 'models/section.dart';
import 'models/history_log.dart';
import 'models/scheduled_class.dart';
import 'services/scheduler_service.dart';
import 'services/history_service.dart';
import 'services/auth_service.dart';
import 'features/ai_suggestions/ai_suggestions_card.dart';
import 'dart:async';

/// RoomSync (Hackathon App)
///
/// This file wires together:
/// - Firebase initialization (with a non-blocking bootstrap wrapper)
/// - Theme state (light/dark)
/// - Authentication gateway (admin/teacher login)
/// - Main dashboard shell + feature modules (via `part` files)
///
/// The feature modules are implemented as extensions on `_DashboardScreenState`
/// to keep the hackathon prototype in one cohesive place.
part 'features/modules/history_logs_module.dart';
part 'features/modules/weekly_calendar_module.dart';
part 'features/modules/dashboard_module.dart';
part 'features/modules/manage_subjects_module.dart';
part 'features/modules/manual_assignment_module.dart';
part 'features/modules/manage_rooms_module.dart';
part 'features/modules/manage_sections_module.dart';
part 'features/modules/schedule_management_module.dart';
part 'features/modules/room_availability_module.dart';
part 'features/modules/reports_module.dart';
part 'features/modules/settings_module.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const FirebaseBootstrapApp());
}

/// Wraps Firebase initialization so the UI can show a banner and still render.
class FirebaseBootstrapApp extends StatefulWidget {
  const FirebaseBootstrapApp({super.key});

  @override
  State<FirebaseBootstrapApp> createState() => _FirebaseBootstrapAppState();
}

class _FirebaseBootstrapAppState extends State<FirebaseBootstrapApp> {
  bool _isDarkMode = false;

  /// Toggle app theme mode between light and dark.
  void _toggleTheme(bool value) {
    setState(() {
      _isDarkMode = value;
    });
  }

  Future<Object?> _initFirebase() async {
    try {
      await Firebase.initializeApp(
        options: DefaultFirebaseOptions.currentPlatform,
      );
      return null;
    } catch (e) {
      return e;
    }
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<Object?>(
      future: _initFirebase(),
      builder: (context, snapshot) {
        return RoomSyncApp(
          isDarkMode: _isDarkMode,
          onThemeChanged: _toggleTheme,
          firebaseError: snapshot.data,
          isFirebaseInit: snapshot.connectionState == ConnectionState.done,
        );
      },
    );
  }
}

/// Small status banner shown at the top while Firebase is initializing or failed.
class _TopStatusBanner extends StatelessWidget {
  final Color color;
  final String text;

  const _TopStatusBanner({
    required this.color,
    required this.text,
  });

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Align(
        alignment: Alignment.topCenter,
        child: Material(
          color: color,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            child: DefaultTextStyle(
              style: const TextStyle(color: Colors.white, fontSize: 12),
              child: Text(text, textAlign: TextAlign.center),
            ),
          ),
        ),
      ),
    );
  }
}

/// Root `MaterialApp` with theme wiring and a `SessionShell` home.
class RoomSyncApp extends StatelessWidget {
  final bool isDarkMode;
  final Function(bool) onThemeChanged;
  final Object? firebaseError;
  final bool isFirebaseInit;

  const RoomSyncApp({
    super.key,
    required this.isDarkMode,
    required this.onThemeChanged,
    this.firebaseError,
    required this.isFirebaseInit,
  });

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'RoomSync',
      debugShowCheckedModeBanner: false,
      themeMode: isDarkMode ? ThemeMode.dark : ThemeMode.light,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: Colors.blueGrey,
          brightness: Brightness.light,
          surface: Colors.grey[50],
        ),
        useMaterial3: true,
      ),
      darkTheme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: Colors.blueGrey,
          brightness: Brightness.dark,
          surface: const Color(0xFF1E1E1E),
          onSurface: Colors.grey[300],
        ),
        scaffoldBackgroundColor: const Color(0xFF121212),
        cardTheme: const CardThemeData(
          color: Color(0xFF2C2C2C),
          elevation: 2,
        ),
        useMaterial3: true,
      ),
      home: Directionality(
        textDirection: TextDirection.ltr,
        child: Stack(
          children: [
            SessionShell(
              isDarkMode: isDarkMode,
              onThemeChanged: onThemeChanged,
            ),
            if (!isFirebaseInit)
              const _TopStatusBanner(
                color: Colors.blueGrey,
                text: 'Initializing Firebase…',
              )
            else if (firebaseError != null)
              _TopStatusBanner(
                color: Colors.red,
                text: 'Firebase not configured.\nError: $firebaseError',
              ),
          ],
        ),
      ),
    );
  }
}

class SessionShell extends StatefulWidget {
  final bool isDarkMode;
  final Function(bool) onThemeChanged;

  const SessionShell({
    super.key,
    required this.isDarkMode,
    required this.onThemeChanged,
  });

  @override
  State<SessionShell> createState() => _SessionShellState();
}

/// Owns the current app session (`User?`) and chooses between:
/// - auth gateway (not signed in)
/// - dashboard (signed in)
class _SessionShellState extends State<SessionShell> {
  final AuthService _authService = AuthService();
  User? _currentUser;
  bool _restoringSession = true;

  @override
  void initState() {
    super.initState();
    _restoreSession();
  }

  Future<void> _restoreSession() async {
    final restored = await _authService.restoreSession();
    if (!mounted) return;
    setState(() {
      _currentUser = restored;
      _restoringSession = false;
    });
  }

  /// Called when a user successfully authenticates.
  void _signInAs(User user) {
    setState(() => _currentUser = user);
  }

  /// Clear session and return to the auth gateway.
  Future<void> _signOut() async {
    await _authService.signOut();
    if (!mounted) return;
    setState(() => _currentUser = null);
  }

  @override
  Widget build(BuildContext context) {
    if (_restoringSession) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    if (_currentUser == null) {
      return AuthGatewayScreen(
        authService: _authService,
        onSelectUser: _signInAs,
      );
    }

    return DashboardScreen(
      currentUser: _currentUser!,
      isDarkMode: widget.isDarkMode,
      onThemeChanged: widget.onThemeChanged,
      onSignOut: _signOut,
    );
  }
}

/// Role selection + navigation to the actual login/sign-up screens.
class AuthGatewayScreen extends StatefulWidget {
  final AuthService authService;
  final ValueChanged<User> onSelectUser;

  const AuthGatewayScreen({
    super.key,
    required this.authService,
    required this.onSelectUser,
  });

  @override
  State<AuthGatewayScreen> createState() => _AuthGatewayScreenState();
}

class _AuthGatewayScreenState extends State<AuthGatewayScreen> {
  /// Open teacher login/sign-up screen.
  void _openTeacherAuth({required bool login}) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => TeacherAuthScreen(
          authService: widget.authService,
          loginMode: login,
          onAuthSuccess: widget.onSelectUser,
        ),
      ),
    );
  }

  /// Open admin login screen.
  void _openAdminLogin() {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => AdminLoginScreen(
          authService: widget.authService,
          onAuthSuccess: widget.onSelectUser,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    return Scaffold(
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 560),
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.account_circle,
                    size: 64, color: Colors.blueGrey),
                const SizedBox(height: 12),
                Text('Sign in to RoomSync', style: textTheme.headlineSmall),
                const SizedBox(height: 8),
                Text(
                  'Choose a role to continue.',
                  style: textTheme.bodyMedium,
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 20),
                _roleCard(
                  context: context,
                  title: 'Admin Login',
                  subtitle: 'Manage scheduling, rooms, sections, and reports',
                  icon: Icons.admin_panel_settings,
                  onTap: _openAdminLogin,
                ),
                const SizedBox(height: 12),
                _roleCard(
                  context: context,
                  title: 'Teacher Login',
                  subtitle: 'Sign in to view your schedule and weekly calendar',
                  icon: Icons.school,
                  onTap: () => _openTeacherAuth(login: true),
                ),
                TextButton.icon(
                  onPressed: () => _openTeacherAuth(login: false),
                  icon: const Icon(Icons.person_add_alt_1),
                  label: const Text('Teacher Sign Up'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _roleCard({
    required BuildContext context,
    required String title,
    required String subtitle,
    required IconData icon,
    required VoidCallback onTap,
  }) {
    return Card(
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: Theme.of(context).colorScheme.primaryContainer,
          child: Icon(icon),
        ),
        title: Text(title, style: const TextStyle(fontWeight: FontWeight.bold)),
        subtitle: Text(subtitle),
        trailing: const Icon(Icons.arrow_forward_ios, size: 16),
        onTap: onTap,
      ),
    );
  }
}

/// Simple admin login form.
class AdminLoginScreen extends StatefulWidget {
  final AuthService authService;
  final ValueChanged<User> onAuthSuccess;

  const AdminLoginScreen({
    super.key,
    required this.authService,
    required this.onAuthSuccess,
  });

  @override
  State<AdminLoginScreen> createState() => _AdminLoginScreenState();
}

class _AdminLoginScreenState extends State<AdminLoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailCtrl = TextEditingController(text: 'chair@bsit.edu');
  final _passwordCtrl = TextEditingController();
  bool _loading = false;

  @override
  void dispose() {
    _emailCtrl.dispose();
    _passwordCtrl.dispose();
    super.dispose();
  }

  /// Validate fields, authenticate, and return the logged-in app user.
  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _loading = true);
    final user = await widget.authService.loginAdmin(
      email: _emailCtrl.text,
      password: _passwordCtrl.text,
    );
    if (!mounted) return;
    setState(() => _loading = false);
    if (user == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text('Invalid admin credentials'),
            backgroundColor: Colors.red),
      );
      return;
    }
    widget.onAuthSuccess(user);
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Admin Login')),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 420),
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Form(
              key: _formKey,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextFormField(
                    controller: _emailCtrl,
                    decoration: const InputDecoration(labelText: 'Admin Email'),
                    validator: (v) => (v == null || v.trim().isEmpty)
                        ? 'Email is required'
                        : null,
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: _passwordCtrl,
                    decoration: const InputDecoration(labelText: 'Password'),
                    obscureText: true,
                    validator: (v) => (v == null || v.isEmpty)
                        ? 'Password is required'
                        : null,
                  ),
                  const SizedBox(height: 20),
                  FilledButton.icon(
                    onPressed: _loading ? null : _submit,
                    icon: _loading
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.login),
                    label: const Text('Login as Admin'),
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'Default admin password: admin123',
                    style: TextStyle(fontSize: 12, color: Colors.blueGrey),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Teacher login + sign-up screen (toggle between modes).
class TeacherAuthScreen extends StatefulWidget {
  final AuthService authService;
  final bool loginMode;
  final ValueChanged<User> onAuthSuccess;

  const TeacherAuthScreen({
    super.key,
    required this.authService,
    required this.loginMode,
    required this.onAuthSuccess,
  });

  @override
  State<TeacherAuthScreen> createState() => _TeacherAuthScreenState();
}

class _TeacherAuthScreenState extends State<TeacherAuthScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameCtrl = TextEditingController();
  final _emailCtrl = TextEditingController();
  final _passwordCtrl = TextEditingController();
  final _confirmCtrl = TextEditingController();
  bool _isLogin = true;
  bool _loading = false;

  @override
  void initState() {
    super.initState();
    _isLogin = widget.loginMode;
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _emailCtrl.dispose();
    _passwordCtrl.dispose();
    _confirmCtrl.dispose();
    super.dispose();
  }

  /// Submit either login or sign-up depending on [_isLogin] mode.
  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _loading = true);

    if (_isLogin) {
      final user = await widget.authService.loginTeacher(
        email: _emailCtrl.text,
        password: _passwordCtrl.text,
      );
      if (!mounted) return;
      setState(() => _loading = false);
      if (user == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
              content: Text('Invalid teacher credentials'),
              backgroundColor: Colors.red),
        );
        return;
      }
      widget.onAuthSuccess(user);
      Navigator.of(context).pop();
      return;
    }

    final signUpError = await widget.authService.signUpTeacher(
      name: _nameCtrl.text,
      email: _emailCtrl.text,
      password: _passwordCtrl.text,
      confirmPassword: _confirmCtrl.text,
    );
    if (!mounted) return;
    setState(() => _loading = false);
    if (signUpError != null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(signUpError), backgroundColor: Colors.red),
      );
      return;
    }
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
          content: Text('Teacher account created. Please log in.'),
          backgroundColor: Colors.green),
    );
    setState(() => _isLogin = true);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar:
          AppBar(title: Text(_isLogin ? 'Teacher Login' : 'Teacher Sign Up')),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 460),
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(20),
            child: Form(
              key: _formKey,
              child: Column(
                children: [
                  if (!_isLogin) ...[
                    TextFormField(
                      controller: _nameCtrl,
                      decoration: const InputDecoration(labelText: 'Full Name'),
                      validator: (v) {
                        if (_isLogin) return null;
                        return (v == null || v.trim().isEmpty)
                            ? 'Name is required'
                            : null;
                      },
                    ),
                    const SizedBox(height: 12),
                  ],
                  TextFormField(
                    controller: _emailCtrl,
                    decoration: const InputDecoration(labelText: 'Email'),
                    validator: (v) {
                      if (v == null || v.trim().isEmpty) {
                        return 'Email is required';
                      }
                      if (!v.contains('@')) return 'Enter a valid email';
                      return null;
                    },
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: _passwordCtrl,
                    decoration: const InputDecoration(labelText: 'Password'),
                    obscureText: true,
                    validator: (v) {
                      if (v == null || v.isEmpty) return 'Password is required';
                      if (!_isLogin && v.length < 6) {
                        return 'Use at least 6 characters';
                      }
                      return null;
                    },
                  ),
                  if (!_isLogin) ...[
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: _confirmCtrl,
                      decoration:
                          const InputDecoration(labelText: 'Confirm Password'),
                      obscureText: true,
                      validator: (v) {
                        if (_isLogin) return null;
                        if (v == null || v.isEmpty) {
                          return 'Confirm your password';
                        }
                        if (v != _passwordCtrl.text) {
                          return 'Passwords do not match';
                        }
                        return null;
                      },
                    ),
                  ],
                  const SizedBox(height: 20),
                  FilledButton.icon(
                    onPressed: _loading ? null : _submit,
                    icon: _loading
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : Icon(_isLogin ? Icons.login : Icons.person_add),
                    label: Text(_isLogin ? 'Login' : 'Create Account'),
                  ),
                  TextButton(
                    onPressed: _loading
                        ? null
                        : () => setState(() {
                              _isLogin = !_isLogin;
                            }),
                    child: Text(
                      _isLogin
                          ? "Don't have an account? Sign up"
                          : 'Already have an account? Login',
                    ),
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'Tip: teacher full name should match the name used in admin assignment.',
                    style: TextStyle(fontSize: 12, color: Colors.blueGrey),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Main application shell after sign-in.
///
/// This screen:
/// - loads schedule data (local first, then Firestore)
/// - provides a drawer to navigate feature modules
/// - scopes the visible schedule for teachers
class DashboardScreen extends StatefulWidget {
  final User currentUser;
  final bool isDarkMode;
  final Function(bool) onThemeChanged;
  final VoidCallback onSignOut;

  const DashboardScreen({
    super.key,
    required this.currentUser,
    required this.isDarkMode,
    required this.onThemeChanged,
    required this.onSignOut,
  });

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  final SchedulerService _schedulerService = SchedulerService();
  String _activeModule = 'Dashboard';
  bool _loadedLocalSchedule = false;
  Timer? _clockTimer;
  DateTime _now = DateTime.now();

  // Settings state
  String _institutionName = 'Your Institution';
  bool _notificationsEnabled = true;

  // Manual Assignment State
  String _teacherName = '';
  String _subjectName = '';
  String _roomName = '';
  String _sectionName = '';
  int _dayIndex = 1;
  String _startTime = "10:30 AM";
  String _endTime = "1:00 PM";
  List<TimeSlot> _aiSuggestions = const [];
  String? _aiConflictMessage;

  final List<String> _dayNames = [
    'Monday',
    'Tuesday',
    'Wednesday',
    'Thursday',
    'Friday',
    'Saturday'
  ];
  bool get _isTeacher => widget.currentUser.role == UserRole.teacher;

  List<ScheduledClass> get _visibleSchedule {
    if (!_isTeacher) return _schedulerService.schedule;
    return _schedulerService.schedule
        .where((sc) =>
            sc.teacher.id == widget.currentUser.id ||
            sc.teacher.name == widget.currentUser.name)
        .toList();
  }

  String getDayName(int day) {
    if (day >= 1 && day <= 6) return _dayNames[day - 1];
    return 'Unknown';
  }

  Map<String, int> parseTimeToMinutes(String timeStr) {
    timeStr = timeStr.trim().toUpperCase();
    final regExp = RegExp(r'^(\d{1,2})(?::(\d{2}))?\s*([AP]M)?$');
    final match = regExp.firstMatch(timeStr);

    if (match != null) {
      int hour = int.parse(match.group(1)!);
      int minute = match.group(2) != null ? int.parse(match.group(2)!) : 0;
      String? amPm = match.group(3);

      if (amPm == 'PM' && hour < 12) hour += 12;
      if (amPm == 'AM' && hour == 12) hour = 0;
      if (amPm == null && hour > 0 && hour <= 7) hour += 12;

      return {
        'hour': hour,
        'minute': minute,
        'totalMinutes': (hour * 60) + minute
      };
    }
    return {'hour': 8, 'minute': 0, 'totalMinutes': 480};
  }

  @override
  void initState() {
    super.initState();
    _clockTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!mounted) return;
      setState(() => _now = DateTime.now());
    });
    _schedulerService.loadFromLocal().then((_) {
      if (!mounted) return;
      _schedulerService
          .loadFromFirestore(courseId: widget.currentUser.courseId)
          .whenComplete(() {
        if (!mounted) return;
        setState(() => _loadedLocalSchedule = true);
      });
    }).catchError((_) {
      if (!mounted) return;
      setState(() => _loadedLocalSchedule = true);
    });
  }

  @override
  void dispose() {
    _clockTimer?.cancel();
    super.dispose();
  }

  String _two(int n) => n.toString().padLeft(2, '0');

  String _formatNow(DateTime dt) {
    final hour24 = dt.hour;
    final period = hour24 >= 12 ? 'PM' : 'AM';
    final hour12 = (hour24 % 12) == 0 ? 12 : (hour24 % 12);
    return '${getDayName(dt.weekday)} $hour12:${_two(dt.minute)}:${_two(dt.second)} $period';
  }

  String _formatDateTime(DateTime dt) {
    final hour24 = dt.hour;
    final period = hour24 >= 12 ? 'PM' : 'AM';
    final hour12 = (hour24 % 12) == 0 ? 12 : (hour24 % 12);
    return '${dt.year}-${_two(dt.month)}-${_two(dt.day)} $hour12:${_two(dt.minute)} $period';
  }

  String formatMinutesToTime(int totalMinutes) {
    int hour = totalMinutes ~/ 60;
    int minute = totalMinutes % 60;
    final period = hour >= 12 ? 'PM' : 'AM';
    int h = hour % 12;
    if (h == 0) h = 12;
    final m = minute.toString().padLeft(2, '0');
    return "$h:$m $period";
  }

  String _formatTimeRange(TimeSlot slot) {
    final start = formatMinutesToTime(slot.startHour * 60 + slot.startMinute);
    final end = formatMinutesToTime(slot.endHour * 60 + slot.endMinute);
    return '$start - $end';
  }

  void _applySuggestedSlot(TimeSlot slot) {
    setState(() {
      _startTime = formatMinutesToTime(slot.startHour * 60 + slot.startMinute);
      _endTime = formatMinutesToTime(slot.endHour * 60 + slot.endMinute);
    });
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Suggested time applied to form.'),
        backgroundColor: Colors.blueGrey,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('RoomSync - $_activeModule'),
            Text(
              '${_formatNow(_now)} • ${_isTeacher ? 'Teacher' : 'Admin'}',
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ],
        ),
        backgroundColor: Theme.of(context).colorScheme.primaryContainer,
      ),
      drawer: Drawer(
        child: ListView(
          padding: EdgeInsets.zero,
          children: [
            UserAccountsDrawerHeader(
              decoration:
                  BoxDecoration(color: Theme.of(context).colorScheme.primary),
              accountName: Text(widget.currentUser.name),
              accountEmail: Text(widget.currentUser.email),
              currentAccountPicture: const CircleAvatar(
                  backgroundColor: Colors.white,
                  child: Icon(Icons.person, size: 40)),
            ),
            _buildDrawerItem(Icons.dashboard, 'Dashboard'),
            _buildDrawerItem(Icons.calendar_view_week, 'Weekly Calendar'),
            const Divider(),
            if (!_isTeacher) ...[
              _buildDrawerItem(Icons.book, 'Manage Subjects'),
              _buildDrawerItem(Icons.assignment_ind, 'Teacher Assignments'),
              _buildDrawerItem(Icons.meeting_room, 'Manage Rooms'),
              _buildDrawerItem(Icons.groups, 'Manage Sections'),
              _buildDrawerItem(Icons.event_available, 'Room Availability'),
              _buildDrawerItem(Icons.assessment, 'Reports'),
            ],
            _buildDrawerItem(Icons.add_task,
                _isTeacher ? 'My Schedule' : 'Schedule Management'),
            const Divider(),
            if (!_isTeacher) _buildDrawerItem(Icons.history, 'History Logs'),
            _buildDrawerItem(Icons.settings, 'Settings'),
            ListTile(
              leading: const Icon(Icons.logout),
              title: const Text('Sign Out'),
              onTap: () {
                Navigator.pop(context);
                widget.onSignOut();
              },
            ),
          ],
        ),
      ),
      body: !_loadedLocalSchedule
          ? const Center(child: CircularProgressIndicator())
          : _buildActiveModule(),
    );
  }

  Widget _buildDrawerItem(IconData icon, String title) {
    bool isSelected = _activeModule == title;
    return ListTile(
      leading: Icon(icon,
          color: isSelected ? Theme.of(context).colorScheme.primary : null),
      title: Text(title,
          style: TextStyle(fontWeight: isSelected ? FontWeight.bold : null)),
      selected: isSelected,
      onTap: () {
        setState(() => _activeModule = title);
        Navigator.pop(context);
      },
    );
  }

  Widget _buildActiveModule() {
    switch (_activeModule) {
      case 'Weekly Calendar':
        return _buildWeeklyCalendar();
      case 'History Logs':
        return _buildHistoryLogs();
      case 'Manage Subjects':
        return _buildManageSubjects();
      case 'Teacher Assignments':
        return _buildManualAssignment();
      case 'Manage Rooms':
        return _buildManageRooms();
      case 'Manage Sections':
        return _buildManageSections();
      case 'My Schedule':
        return _buildScheduleManagement();
      case 'Schedule Management':
        return _buildScheduleManagement();
      case 'Room Availability':
        return _buildRoomAvailability();
      case 'Reports':
        return _buildReports();
      case 'Settings':
        return _buildSettings();
      case 'Dashboard':
      default:
        return _buildDashboard();
    }
  }

  Widget _buildHistoryLogs() => buildHistoryLogsModule();

  Widget _buildWeeklyCalendar() => buildWeeklyCalendarModule();

  Widget _buildDashboard() => buildDashboardModule();

  Widget _buildManageSubjects() => buildManageSubjectsModule();

  Widget _buildManualAssignment() => buildManualAssignmentModule();

  Widget _buildManageRooms() => buildManageRoomsModule();

  Widget _buildManageSections() => buildManageSectionsModule();

  Widget _buildScheduleManagement() => buildScheduleManagementModule();

  Widget _buildRoomAvailability() => buildRoomAvailabilityModule();

  Widget _buildReports() => buildReportsModule();

  Widget _buildSettings() => buildSettingsModule();

  void _showEditSettingDialog(
      String title, String currentVal, Function(String) onSave) {
    final controller = TextEditingController(text: currentVal);
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Edit $title'),
        content: TextField(
            controller: controller,
            decoration: InputDecoration(labelText: title)),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          ElevatedButton(
              onPressed: () {
                onSave(controller.text);
                Navigator.pop(ctx);
              },
              child: const Text('Save')),
        ],
      ),
    );
  }

  Widget _statCard(String label, String val, Color col, IconData icon) {
    return Expanded(
      child: Card(
        color: col.withOpacity(0.05),
        child: Padding(
          padding: const EdgeInsets.all(12.0),
          child: Column(
            children: [
              Icon(icon, color: col),
              const SizedBox(height: 4),
              Text(val,
                  style: const TextStyle(
                      fontSize: 18, fontWeight: FontWeight.bold)),
              Text(label, style: const TextStyle(fontSize: 10)),
            ],
          ),
        ),
      ),
    );
  }
}
