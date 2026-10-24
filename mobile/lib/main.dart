import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'dart:io';
import 'dart:math' as math;
import 'dart:typed_data';
import 'api_service.dart';
import 'package:geocoding/geocoding.dart';
import 'package:geolocator/geolocator.dart';
import 'package:url_launcher/url_launcher.dart';

void main() {
  runApp(const SahaySetuApp());
}

// ==========================================
// APP THEME CONTROLLER & NOTIFIER
// ==========================================
class AppThemeNotifier extends ChangeNotifier {
  bool isDarkMode = false;
  Color primaryColor = const Color(0xFF2563EB);

  void toggleTheme(bool dark) {
    isDarkMode = dark;
    notifyListeners();
  }

  void setPrimaryColor(Color color) {
    primaryColor = color;
    notifyListeners();
  }
}

final AppThemeNotifier appTheme = AppThemeNotifier();

// ==========================================
// DATA MODELS & DATABASES
// ==========================================
class UserProfile {
  final String fullName;
  final String email;
  final String password;
  final String mobile;
  final String role;
  final String? accessToken;
  String? profileImagePath;

  UserProfile({
    required this.fullName,
    required this.email,
    required this.password,
    required this.mobile,
    this.role = 'CITIZEN',
    this.accessToken,
    this.profileImagePath,
  });
}

class WorkerProfile {
  final String workerId;
  final String fullName;
  final String department;
  final String wardZone;
  final String officialEmail;
  final String mobile;
  final String designation;
  int bonusPoints;

  WorkerProfile({
    required this.workerId,
    required this.fullName,
    required this.department,
    required this.wardZone,
    required this.officialEmail,
    required this.mobile,
    required this.designation,
    this.bonusPoints = 120,
  });
}

class Complaint {
  final String id;
  final String category;
  final String description;
  final String severity;
  final String location;
  String
  status; // Pending, In Progress, Resolved / Awaiting Verification, Closed
  final String citizenEmail;
  String? assignedWorker;
  String? completionNote;
  String? completionPhotoPath;
  int? citizenRating;
  String? citizenFeedback;
  bool isFusedIncident;
  final DateTime submissionTime;

  Complaint({
    required this.id,
    required this.category,
    required this.description,
    required this.severity,
    required this.location,
    required this.status,
    required this.citizenEmail,
    this.assignedWorker,
    this.completionNote,
    this.completionPhotoPath,
    this.citizenRating,
    this.citizenFeedback,
    this.isFusedIncident = false,
    DateTime? submissionTime,
  }) : submissionTime = submissionTime ?? DateTime.now();

  factory Complaint.fromApi(
    Map<String, dynamic> data, {
    required String citizenEmail,
  }) {
    final complaintId = data['complaint_id']?.toString();
    final status = data['status']?.toString();
    final createdAt = data['created_at']?.toString();
    final latitude = data['latitude'];
    final longitude = data['longitude'];

    if (complaintId == null ||
        complaintId.isEmpty ||
        status == null ||
        createdAt == null ||
        latitude is! num ||
        longitude is! num) {
      throw const FormatException('Complaint response is missing required data');
    }

    return Complaint(
      id: complaintId,
      category: data['category']?.toString() ?? 'Category not recorded',
      description: data['description']?.toString() ?? '',
      severity: data['severity']?.toString() ?? '',
      location: '$latitude, $longitude',
      status: status,
      citizenEmail: citizenEmail,
      submissionTime: DateTime.parse(createdAt),
    );
  }
}

class AppDatabase {
  static List<UserProfile> registeredUsers = [
    UserProfile(
      fullName: 'Jagriti Singhal',
      email: 'citizen@gmail.com',
      password: 'Password@123',
      mobile: '9876543210',
    ),
  ];

  static List<WorkerProfile> workerProfiles = [
    WorkerProfile(
      workerId: 'rajesh@sahaysetu',
      fullName: 'Rajesh Kumar',
      department: 'Pothole & Road Damage',
      wardZone: 'Ward 42 (Connaught Zone)',
      officialEmail: 'rajesh.k@muncipal.gov.in',
      mobile: '9811223344',
      designation: 'Senior Road Inspector',
      bonusPoints: 150,
    ),
    WorkerProfile(
      workerId: 'ramu@sahaysetu',
      fullName: 'Ramu Sharma',
      department: 'Broken Streetlight',
      wardZone: 'Ward 15 (Nehru Place Zone)',
      officialEmail: 'ramu.s@muncipal.gov.in',
      mobile: '9977665544',
      designation: 'Electrical Maintenance Crew Lead',
      bonusPoints: 95,
    ),
  ];

  static List<Complaint> complaints = [
    Complaint(
      id: 'SS-1024',
      category: 'Pothole & Road Damage',
      description: 'Deep pothole near main gate causing traffic slowdown.',
      severity: 'High',
      location: 'Sector 62, Main Road',
      status: 'In Progress',
      citizenEmail: 'citizen@gmail.com',
      assignedWorker: 'rajesh@sahaysetu',
      isFusedIncident: true,
    ),
    Complaint(
      id: 'SS-1025',
      category: 'Broken Streetlight',
      description:
          'Streetlight pole #42 is flickering and completely dark at night.',
      severity: 'Medium',
      location: 'Nehru Place, Delhi',
      status: 'Pending',
      citizenEmail: 'citizen@gmail.com',
      assignedWorker: 'ramu@sahaysetu',
    ),
  ];
}

// ==========================================
// APP ROOT
// ==========================================
class SahaySetuApp extends StatelessWidget {
  const SahaySetuApp({super.key});

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: appTheme,
      builder: (context, _) {
        return MaterialApp(
          title: 'SahaySetu',
          debugShowCheckedModeBanner: false,
          themeMode: appTheme.isDarkMode ? ThemeMode.dark : ThemeMode.light,
          theme: ThemeData(
            primarySwatch: Colors.blue,
            primaryColor: appTheme.primaryColor,
            scaffoldBackgroundColor: const Color(0xFFF8FAFC),
            appBarTheme: AppBarTheme(
              backgroundColor: appTheme.primaryColor,
              foregroundColor: Colors.white,
              elevation: 0,
            ),
            elevatedButtonTheme: ElevatedButtonThemeData(
              style: ElevatedButton.styleFrom(
                backgroundColor: appTheme.primaryColor,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
                padding: const EdgeInsets.symmetric(
                  vertical: 14,
                  horizontal: 16,
                ),
              ),
            ),
          ),
          darkTheme: ThemeData(
            brightness: Brightness.dark,
            primaryColor: appTheme.primaryColor,
            scaffoldBackgroundColor: const Color(0xFF0F172A),
            appBarTheme: const AppBarTheme(
              backgroundColor: Color(0xFF1E293B),
              foregroundColor: Colors.white,
              elevation: 0,
            ),
            elevatedButtonTheme: ElevatedButtonThemeData(
              style: ElevatedButton.styleFrom(
                backgroundColor: appTheme.primaryColor,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
                padding: const EdgeInsets.symmetric(
                  vertical: 14,
                  horizontal: 16,
                ),
              ),
            ),
          ),
          home: const RoleSelectionScreen(),
        );
      },
    );
  }
}

// ==========================================
// ROLE SELECTION SCREEN
// ==========================================
class RoleSelectionScreen extends StatelessWidget {
  const RoleSelectionScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [Color(0xFF0F172A), Color(0xFF1E293B)],
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
          ),
        ),
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(
                  Icons.shield_rounded,
                  size: 80,
                  color: Color(0xFF38BDF8),
                ),
                const SizedBox(height: 16),
                const Text(
                  'SahaySetu',
                  style: TextStyle(
                    fontSize: 32,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                    letterSpacing: 1.2,
                  ),
                ),
                const SizedBox(height: 8),
                const Text(
                  'Intelligent Civic Infrastructure Management',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 14, color: Colors.white70),
                ),
                const SizedBox(height: 48),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => const CitizenAuthScreen(),
                        ),
                      );
                    },
                    icon: const Icon(Icons.person),
                    label: const Text(
                      'Citizen Portal',
                      style: TextStyle(fontSize: 16),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton.icon(
                    onPressed: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => const WorkerLoginScreen(),
                        ),
                      );
                    },
                    style: OutlinedButton.styleFrom(
                      side: const BorderSide(color: Color(0xFF38BDF8)),
                      foregroundColor: const Color(0xFF38BDF8),
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                    icon: const Icon(Icons.engineering),
                    label: const Text(
                      'Field Worker Portal',
                      style: TextStyle(fontSize: 16),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ==========================================
// CITIZEN AUTHENTICATION
// ==========================================
class CitizenAuthScreen extends StatefulWidget {
  const CitizenAuthScreen({super.key});

  @override
  State<CitizenAuthScreen> createState() => _CitizenAuthScreenState();
}

class _CitizenAuthScreenState extends State<CitizenAuthScreen> {
  bool isLoginMode = true;
  bool _obscurePassword = true;
  bool _obscureConfirmPassword = true;
  final _formKey = GlobalKey<FormState>();

  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  final TextEditingController _confirmPasswordController =
      TextEditingController();
  final TextEditingController _fullNameController = TextEditingController();

  void _clearFields() {
    _emailController.clear();
    _passwordController.clear();
    _confirmPasswordController.clear();
    _fullNameController.clear();
  }

  void _toggleAuthMode() {
    setState(() {
      isLoginMode = !isLoginMode;
      _clearFields();
    });
  }

  void _handleAuthSubmit() async {
    if (!_formKey.currentState!.validate()) return;

    if (isLoginMode) {
      try {
        final data = await ApiService.login(
          email: _emailController.text.trim(),
          password: _passwordController.text,
        );

        if (data['role'] != 'CITIZEN') {
          throw Exception('This account is not a citizen account.');
        }

        final token = data['access_token'] as String;
        final authenticatedUser = await ApiService.getCurrentUser(
          token: token,
        );
        if (authenticatedUser['role'] != 'CITIZEN') {
          throw Exception('This account is not a citizen account.');
        }

        if (!mounted) return;

        final email = _emailController.text.trim();

        final loggedInUser = UserProfile(
          fullName: email.split('@').first,
          email: email,
          password: '',
          mobile: '',
          role: authenticatedUser['role'] as String,
          accessToken: token,
        );

        _clearFields();

        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (context) =>
                CitizenDashboardScreen(currentUser: loggedInUser),
          ),
        );
      } catch (e) {
        if (!mounted) return;

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Login failed: ${e.toString()}')),
        );
      }
    } else {
      try {
        await ApiService.register(
          name: _fullNameController.text.trim(),
          email: _emailController.text.trim(),
          password: _passwordController.text,
        );

        if (!mounted) return;

        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Account created successfully! Please sign in.'),
          ),
        );

        _toggleAuthMode();
      } catch (e) {
        if (!mounted) return;

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Registration failed: ${e.toString()}')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(isLoginMode ? 'Citizen Sign In' : 'Citizen Sign Up'),
      ),
      body: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Form(
          key: _formKey,
          child: ListView(
            children: [
              const SizedBox(height: 10),
              Text(
                isLoginMode ? 'Welcome Back!' : 'Create New Account',
                style: const TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 6),
              const Text(
                'Use your Gmail ID to access civic services.',
                style: TextStyle(color: Colors.grey),
              ),
              const SizedBox(height: 24),
              if (!isLoginMode) ...[
                TextFormField(
                  controller: _fullNameController,
                  decoration: const InputDecoration(
                    labelText: 'Full Name',
                    border: OutlineInputBorder(),
                  ),
                  validator: (val) => val == null || val.trim().isEmpty
                      ? 'Enter your full name'
                      : null,
                ),
              ],
              TextFormField(
                controller: _emailController,
                keyboardType: TextInputType.emailAddress,
                decoration: const InputDecoration(
                  labelText: 'Gmail ID',
                  hintText: 'example@gmail.com',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.email),
                ),
                validator: (val) {
                  if (val == null || !val.trim().endsWith('@gmail.com')) {
                    return 'Please enter a valid @gmail.com address';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _passwordController,
                obscureText: _obscurePassword,
                decoration: InputDecoration(
                  labelText: 'Password',
                  border: const OutlineInputBorder(),
                  helperText: 'Min 8 chars: include uppercase, number & symbol',
                  helperMaxLines: 2,
                  suffixIcon: IconButton(
                    icon: Icon(
                      _obscurePassword
                          ? Icons.visibility_off
                          : Icons.visibility,
                    ),
                    onPressed: () =>
                        setState(() => _obscurePassword = !_obscurePassword),
                  ),
                ),
                validator: (val) {
                  if (val == null || val.length < 8) {
                    return 'Password must be at least 8 characters long';
                  }
                  if (!RegExp(r'[A-Z]').hasMatch(val) ||
                      !RegExp(r'[0-9]').hasMatch(val) ||
                      !RegExp(r'[!@#$%^&*(),.?":{}|<>]').hasMatch(val)) {
                    return 'Must include letters, numbers & symbols';
                  }
                  return null;
                },
              ),
              if (!isLoginMode) ...[
                const SizedBox(height: 16),
                TextFormField(
                  controller: _confirmPasswordController,
                  obscureText: _obscureConfirmPassword,
                  decoration: InputDecoration(
                    labelText: 'Confirm Password',
                    border: const OutlineInputBorder(),
                    suffixIcon: IconButton(
                      icon: Icon(
                        _obscureConfirmPassword
                            ? Icons.visibility_off
                            : Icons.visibility,
                      ),
                      onPressed: () => setState(
                        () =>
                            _obscureConfirmPassword = !_obscureConfirmPassword,
                      ),
                    ),
                  ),
                  validator: (val) {
                    if (val != _passwordController.text) {
                      return 'Passwords do not match';
                    }
                    return null;
                  },
                ),
              ],
              if (isLoginMode) ...[
                Align(
                  alignment: Alignment.centerRight,
                  child: TextButton(
                    onPressed: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => const ForgotPasswordScreen(),
                        ),
                      );
                    },
                    child: const Text('Forgot Password?'),
                  ),
                ),
              ],
              const SizedBox(height: 16),
              ElevatedButton(
                onPressed: _handleAuthSubmit,
                child: Text(
                  isLoginMode ? 'Sign In' : 'Generate OTP & Register',
                ),
              ),
              TextButton(
                onPressed: _toggleAuthMode,
                child: Text(
                  isLoginMode
                      ? 'Don\'t have an account? Sign Up'
                      : 'Already have an account? Sign In',
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ==========================================
// FORGOT PASSWORD SCREEN
// ==========================================
class ForgotPasswordScreen extends StatelessWidget {
  const ForgotPasswordScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Forgot Password')),
      body: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Password recovery is not available yet. No verification code '
              'will be sent and your password cannot be changed here.',
              style: TextStyle(fontSize: 15, color: Colors.grey),
            ),
            const SizedBox(height: 20),
            ElevatedButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Return to sign in'),
            ),
          ],
        ),
      ),
    );
  }
}

// ==========================================
// CITIZEN DASHBOARD & SIDE MENU (DRAWER)
// ==========================================
class CitizenDashboardScreen extends StatefulWidget {
  final UserProfile currentUser;
  const CitizenDashboardScreen({super.key, required this.currentUser});

  @override
  State<CitizenDashboardScreen> createState() => _CitizenDashboardScreenState();
}

class _CitizenDashboardScreenState extends State<CitizenDashboardScreen> {
  List<Complaint> _complaints = [];
  bool _isLoadingComplaints = true;
  String? _complaintLoadError;

  @override
  void initState() {
    super.initState();
    _loadComplaints();
  }

  Future<void> _loadComplaints() async {
    final token = widget.currentUser.accessToken;
    if (token == null || token.isEmpty) {
      setState(() {
        _isLoadingComplaints = false;
        _complaintLoadError = 'Please sign in again to load your complaints.';
      });
      return;
    }

    setState(() {
      _isLoadingComplaints = true;
      _complaintLoadError = null;
    });

    try {
      final records = await ApiService.getMyComplaints(token: token);
      final complaints = records
          .map(
            (record) => Complaint.fromApi(
              record,
              citizenEmail: widget.currentUser.email,
            ),
          )
          .toList(growable: false);
      if (!mounted) return;
      setState(() => _complaints = complaints);
    } catch (error) {
      if (!mounted) return;
      setState(() => _complaintLoadError = _apiErrorMessage(error));
    } finally {
      if (mounted) {
        setState(() => _isLoadingComplaints = false);
      }
    }
  }

  Future<void> _openComplaintDetails(String complaintId) async {
    final verificationSaved = await Navigator.push<bool>(
      context,
      MaterialPageRoute(
        builder: (context) => CitizenComplaintDetailScreen(
          accessToken: widget.currentUser.accessToken,
          complaintId: complaintId,
        ),
      ),
    );
    if (verificationSaved == true) {
      await _loadComplaints();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Your verification response was saved.')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Citizen Dashboard')),
      drawer: Drawer(
        child: ListView(
          padding: EdgeInsets.zero,
          children: [
            UserAccountsDrawerHeader(
              accountName: Text(
                widget.currentUser.fullName,
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                ),
              ),
              accountEmail: Text(widget.currentUser.email),
              currentAccountPicture: CircleAvatar(
                backgroundColor: Colors.white,
                backgroundImage: widget.currentUser.profileImagePath != null
                    ? FileImage(File(widget.currentUser.profileImagePath!))
                    : null,
                child: widget.currentUser.profileImagePath == null
                    ? const Icon(
                        Icons.person,
                        size: 40,
                        color: Color(0xFF2563EB),
                      )
                    : null,
              ),
              decoration: BoxDecoration(color: appTheme.primaryColor),
            ),
            ListTile(
              leading: const Icon(Icons.dashboard),
              title: const Text('Dashboard'),
              onTap: () => Navigator.pop(context),
            ),
            ListTile(
              leading: const Icon(Icons.person),
              title: const Text('Profile Details'),
              onTap: () async {
                Navigator.pop(context);
                await Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) =>
                        ProfileScreen(user: widget.currentUser),
                  ),
                );
                setState(() {});
              },
            ),
            ListTile(
              leading: const Icon(Icons.history),
              title: const Text('Previous Records & Complaints'),
              onTap: () {
                Navigator.pop(context);
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => PreviousComplaintsScreen(
                      accessToken: widget.currentUser.accessToken,
                    ),
                  ),
                );
              },
            ),
            ListTile(
              leading: const Icon(Icons.map),
              title: const Text('City Infrastructure Heatmap'),
              onTap: () {
                Navigator.pop(context);
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => const HeatmapScreen(),
                  ),
                );
              },
            ),
            ListTile(
              leading: const Icon(Icons.settings),
              title: const Text('Settings'),
              onTap: () {
                Navigator.pop(context);
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => const SettingsScreen(),
                  ),
                );
              },
            ),
            const Divider(),
            ListTile(
              leading: const Icon(Icons.logout, color: Colors.red),
              title: const Text('Logout', style: TextStyle(color: Colors.red)),
              onTap: () {
                Navigator.pushAndRemoveUntil(
                  context,
                  MaterialPageRoute(
                    builder: (context) => const RoleSelectionScreen(),
                  ),
                  (route) => false,
                );
              },
            ),
          ],
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          const Row(
            children: [
              Icon(Icons.location_city, size: 20, color: Colors.grey),
              SizedBox(width: 8),
              Text(
                'Assigned Zone: Ward 42 (Connaught Zone)',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  color: Colors.grey,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  appTheme.primaryColor,
                  appTheme.primaryColor.withValues(alpha: 0.8),
                ],
              ),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Row(
                  children: [
                    Icon(Icons.insights, color: Colors.white),
                    SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'City Health Score: 84 / 100',
                        style: TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                const Text(
                  'Civic Incident Fusion active. 2 related complaints grouped into probable municipal incidents.',
                  style: TextStyle(color: Colors.white70, fontSize: 13),
                ),
                const SizedBox(height: 12),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.white,
                    foregroundColor: appTheme.primaryColor,
                  ),
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => const HeatmapScreen(),
                      ),
                    );
                  },
                  child: const Text('View City Heatmap & Incidents'),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),
          Row(
            children: [
              const Expanded(
                child: Text(
                  'My Complaints',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              const SizedBox(width: 8),
              ElevatedButton.icon(
                onPressed: () async {
                  await Navigator.push<Complaint>(
                    context,
                    MaterialPageRoute(
                      builder: (context) => CreateComplaintScreen(
                        userEmail: widget.currentUser.email,
                        accessToken: widget.currentUser.accessToken,
                      ),
                    ),
                  );
                  await _loadComplaints();
                },
                icon: const Icon(Icons.add, size: 16),
                label: const Text('New Complaint'),
              ),
              IconButton(
                tooltip: 'Refresh complaints',
                onPressed: _isLoadingComplaints ? null : _loadComplaints,
                icon: const Icon(Icons.refresh),
              ),
            ],
          ),
          const SizedBox(height: 12),
          if (_isLoadingComplaints)
            const Padding(
              padding: EdgeInsets.all(24),
              child: Center(child: CircularProgressIndicator()),
            )
          else if (_complaintLoadError != null)
            Column(
              children: [
                Text(
                  'Unable to load your complaints: $_complaintLoadError',
                  style: const TextStyle(color: Colors.redAccent),
                ),
                TextButton(
                  onPressed: _loadComplaints,
                  child: const Text('Try again'),
                ),
              ],
            )
          else if (_complaints.isEmpty)
            const Padding(
              padding: EdgeInsets.only(top: 40),
              child: Center(
                child: Text(
                  'No server-recorded complaints yet. Tap "New Complaint" to report an issue.',
                  style: TextStyle(color: Colors.grey),
                ),
              ),
            )
          else
            ListView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: _complaints.length,
              itemBuilder: (context, index) {
                final complaint = _complaints[index];
                return Card(
                  margin: const EdgeInsets.only(bottom: 12),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Expanded(
                              child: Text(
                                complaint.id,
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  color: appTheme.primaryColor,
                                ),
                              ),
                            ),
                            Chip(
                              label: Text(
                                complaint.status,
                                style: const TextStyle(
                                  fontSize: 11,
                                  color: Colors.white,
                                ),
                              ),
                              backgroundColor: _getStatusColor(complaint.status),
                            ),
                          ],
                        ),
                        const SizedBox(height: 4),
                        Text(
                          complaint.category,
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(complaint.description),
                        const SizedBox(height: 8),
                        Text('Coordinates: ${complaint.location}'),
                        Text(
                          'Submitted: ${_formatComplaintDate(complaint.submissionTime)}',
                          style: const TextStyle(
                            fontSize: 12,
                            color: Colors.grey,
                          ),
                        ),
                        Align(
                          alignment: Alignment.centerLeft,
                          child: TextButton.icon(
                            onPressed: () => _openComplaintDetails(complaint.id),
                            icon: const Icon(Icons.timeline, size: 18),
                            label: const Text('View progress and verify'),
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
        ],
      ),
    );
  }

  Color _getStatusColor(String status) {
    switch (status) {
      case 'Pending':
        return Colors.orange;
      case 'In Progress':
        return Colors.blue;
      case 'Resolved / Awaiting Verification':
        return Colors.purple;
      case 'Closed':
        return Colors.green;
      case 'SUBMITTED':
        return Colors.orange;
      case 'ASSIGNED':
        return Colors.blue;
      case 'IN_PROGRESS':
        return Colors.purple;
      case 'COMPLETED':
        return Colors.green;
      default:
        return Colors.grey;
    }

  }
}

String _formatComplaintDate(DateTime date) {
  final localDate = date.toLocal();
  final month = localDate.month.toString().padLeft(2, '0');
  final day = localDate.day.toString().padLeft(2, '0');
  return '$day/$month/${localDate.year}';
}

String _apiErrorMessage(Object error) {
  if (error is ApiException && error.statusCode == 401) {
    return 'Your session has expired or is no longer valid. Please sign in again.';
  }
  return error.toString();
}

// ==========================================
// CITIZEN FEEDBACK & REVIEW SCREEN
// ==========================================
class CitizenFeedbackReviewScreen extends StatefulWidget {
  final Complaint complaint;
  const CitizenFeedbackReviewScreen({super.key, required this.complaint});

  @override
  State<CitizenFeedbackReviewScreen> createState() =>
      _CitizenFeedbackReviewScreenState();
}

class _CitizenFeedbackReviewScreenState
    extends State<CitizenFeedbackReviewScreen> {
  int _rating = 5;
  final TextEditingController _feedbackController = TextEditingController();

  void _submitCitizenConfirmation(bool workDone) {
    setState(() {
      if (workDone) {
        widget.complaint.status = 'Closed';
        widget.complaint.citizenRating = _rating;
        widget.complaint.citizenFeedback = _feedbackController.text.trim();

        // Credit Bonus points to worker profile
        if (widget.complaint.assignedWorker != null) {
          final worker = AppDatabase.workerProfiles.firstWhere(
            (w) =>
                w.workerId.toLowerCase() ==
                widget.complaint.assignedWorker!.toLowerCase(),
            orElse: () => WorkerProfile(
              workerId: '',
              fullName: '',
              department: '',
              wardZone: '',
              officialEmail: '',
              mobile: '',
              designation: '',
              bonusPoints: 0,
            ),
          );
          if (worker.workerId.isNotEmpty) {
            worker.bonusPoints += 50; // Award bonus points
          }
        }

        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Work verified & marked Closed! Bonus credited to worker.',
            ),
          ),
        );
      } else {
        widget.complaint.status = 'In Progress';
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Marked as incomplete. Sent back to worker for re-evaluation.',
            ),
            backgroundColor: Colors.orange,
          ),
        );
      }
    });
    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Verify Resolution & Feedback')),
      body: Padding(
        padding: const EdgeInsets.all(20.0),
        child: ListView(
          children: [
            const Text(
              'Worker Completion Report',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Ticket ID: ${widget.complaint.id}',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: appTheme.primaryColor,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text('Category: ${widget.complaint.category}'),
                    const SizedBox(height: 6),
                    Text(
                      'Resolution Note: ${widget.complaint.completionNote ?? "No notes provided"}',
                      style: const TextStyle(fontStyle: FontStyle.italic),
                    ),
                    if (widget.complaint.completionPhotoPath != null) ...[
                      const SizedBox(height: 12),
                      const Text(
                        'Completion Photo Proof:',
                        style: TextStyle(fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 8),
                      Container(
                        height: 150,
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(8),
                          image: DecorationImage(
                            image: FileImage(
                              File(widget.complaint.completionPhotoPath!),
                            ),
                            fit: BoxFit.cover,
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
            const SizedBox(height: 20),
            const Text(
              'Rate Worker Performance',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: List.generate(5, (index) {
                return IconButton(
                  icon: Icon(
                    index < _rating
                        ? Icons.star_rounded
                        : Icons.star_border_rounded,
                    color: Colors.amber,
                    size: 36,
                  ),
                  onPressed: () => setState(() => _rating = index + 1),
                );
              }),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _feedbackController,
              maxLines: 2,
              decoration: const InputDecoration(
                labelText: 'Feedback / Comments for Worker',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 24),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    style: OutlinedButton.styleFrom(
                      foregroundColor: Colors.red,
                      side: const BorderSide(color: Colors.red),
                    ),
                    onPressed: () => _submitCitizenConfirmation(false),
                    child: const Text('Work Not Done'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.green,
                    ),
                    onPressed: () => _submitCitizenConfirmation(true),
                    child: const Text('Confirm & Close Task'),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

// ==========================================
// SETTINGS SCREEN
// ==========================================
class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  bool _pushNotifications = true;
  bool _locationTracking = true;
  bool _civicAlerts = true;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('App Settings')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          const Text(
            'Appearance & Theme',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: Colors.blueAccent,
            ),
          ),
          const SizedBox(height: 8),
          SwitchListTile(
            title: const Text('Dark Mode'),
            subtitle: const Text('Enable dark appearance for night usage'),
            value: appTheme.isDarkMode,
            onChanged: (val) {
              setState(() {
                appTheme.toggleTheme(val);
              });
            },
          ),
          const Divider(),
          const Text(
            'Accent Color Theme',
            style: TextStyle(fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 10),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _colorButton(const Color(0xFF2563EB), 'Blue'),
              _colorButton(const Color(0xFF16A34A), 'Green'),
              _colorButton(const Color(0xFF9333EA), 'Purple'),
              _colorButton(const Color(0xFFDC2626), 'Red'),
            ],
          ),
          const Divider(height: 32),
          const Text(
            'Notifications & Privacy',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: Colors.blueAccent,
            ),
          ),
          const SizedBox(height: 8),
          SwitchListTile(
            title: const Text('Push Notifications'),
            subtitle: const Text('Civic SLA & Field Status Updates'),
            value: _pushNotifications,
            onChanged: (val) => setState(() => _pushNotifications = val),
          ),
          SwitchListTile(
            title: const Text('Emergency Civic Alerts'),
            subtitle: const Text(
              'Receive broadcast warnings about municipal hazards',
            ),
            value: _civicAlerts,
            onChanged: (val) => setState(() => _civicAlerts = val),
          ),
          SwitchListTile(
            title: const Text('Precise GPS Location'),
            subtitle: const Text('Allow geotagging for complaint submission'),
            value: _locationTracking,
            onChanged: (val) => setState(() => _locationTracking = val),
          ),
          const Divider(height: 32),
          const Text(
            'Data & Storage',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: Colors.blueAccent,
            ),
          ),
          const SizedBox(height: 8),
          ListTile(
            leading: const Icon(Icons.delete_sweep),
            title: const Text('Clear App Cache'),
            subtitle: const Text(
              'Frees up local storage used for temporary camera evidence',
            ),
            onTap: () {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('App cache cleared successfully!'),
                ),
              );
            },
          ),
          ListTile(
            leading: const Icon(Icons.download),
            title: const Text('Export Complaint Reports (CSV)'),
            subtitle: const Text(
              'Downloads offline CSV record of all reported complaints',
            ),
            onTap: () {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text(
                    'Complaint log exported to device storage (CSV).',
                  ),
                ),
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _colorButton(Color color, String name) {
    bool isSelected = appTheme.primaryColor.toARGB32() == color.toARGB32();
    return GestureDetector(
      onTap: () {
        setState(() {
          appTheme.setPrimaryColor(color);
        });
      },
      child: Container(
        padding: const EdgeInsets.all(4),
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          border: Border.all(
            color: isSelected ? Colors.white : Colors.transparent,
            width: 3,
          ),
        ),
        child: CircleAvatar(
          backgroundColor: color,
          radius: 22,
          child: isSelected
              ? const Icon(Icons.check, color: Colors.white)
              : null,
        ),
      ),
    );
  }
}

// ==========================================
// PREVIOUS COMPLAINTS SCREEN
// ==========================================
class PreviousComplaintsScreen extends StatefulWidget {
  final String? accessToken;
  const PreviousComplaintsScreen({super.key, required this.accessToken});

  @override
  State<PreviousComplaintsScreen> createState() =>
      _PreviousComplaintsScreenState();
}

class _PreviousComplaintsScreenState extends State<PreviousComplaintsScreen> {
  List<Map<String, dynamic>> _complaints = [];
  bool _isLoading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadComplaints();
  }

  Future<void> _loadComplaints() async {
    final token = widget.accessToken;
    if (token == null || token.isEmpty) {
      setState(() {
        _isLoading = false;
        _error = 'Please sign in again to load your complaint history.';
      });
      return;
    }

    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final complaints = await ApiService.getMyComplaints(token: token);
      if (!mounted) return;
      setState(() => _complaints = complaints);
    } catch (error) {
      if (!mounted) return;
      setState(() => _error = _apiErrorMessage(error));
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _openComplaintDetails(String complaintId) async {
    final verificationSaved = await Navigator.push<bool>(
      context,
      MaterialPageRoute(
        builder: (context) => CitizenComplaintDetailScreen(
          accessToken: widget.accessToken,
          complaintId: complaintId,
        ),
      ),
    );
    if (verificationSaved == true) {
      await _loadComplaints();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Your verification response was saved.')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    Widget body;
    if (_isLoading) {
      body = const Center(child: CircularProgressIndicator());
    } else if (_error != null) {
      body = Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'Unable to load complaint history: $_error',
                textAlign: TextAlign.center,
                style: const TextStyle(color: Colors.redAccent),
              ),
              const SizedBox(height: 12),
              ElevatedButton(
                onPressed: _loadComplaints,
                child: const Text('Try again'),
              ),
            ],
          ),
        ),
      );
    } else if (_complaints.isEmpty) {
      body = RefreshIndicator(
        onRefresh: _loadComplaints,
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          children: const [
            SizedBox(height: 180),
            Center(child: Text('No server-recorded complaints yet.')),
          ],
        ),
      );
    } else {
      body = RefreshIndicator(
        onRefresh: _loadComplaints,
        child: ListView.builder(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.all(16),
          itemCount: _complaints.length,
          itemBuilder: (context, index) {
            final complaint = _complaints[index];
            final createdAt = DateTime.tryParse(
              complaint['created_at']?.toString() ?? '',
            );
            return Card(
              margin: const EdgeInsets.only(bottom: 12),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'ID: ${complaint['complaint_id']}',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: appTheme.primaryColor,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Category: ${complaint['category']}',
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                    Text('Status: ${complaint['status']}'),
                    Text(
                      'Coordinates: ${complaint['latitude']}, ${complaint['longitude']}',
                    ),
                    if (createdAt != null)
                      Text('Submitted: ${_formatComplaintDate(createdAt)}'),
                    const SizedBox(height: 4),
                    Text(complaint['description']?.toString() ?? ''),
                    Align(
                      alignment: Alignment.centerLeft,
                      child: TextButton.icon(
                        onPressed: () => _openComplaintDetails(
                          complaint['complaint_id']?.toString() ?? '',
                        ),
                        icon: const Icon(Icons.timeline, size: 18),
                        label: const Text('View progress and verify'),
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Previous Records & Complaints'),
        actions: [
          IconButton(
            tooltip: 'Refresh history',
            onPressed: _isLoading ? null : _loadComplaints,
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
      body: body,
    );
  }
}

class CitizenComplaintDetailScreen extends StatefulWidget {
  final String? accessToken;
  final String complaintId;

  const CitizenComplaintDetailScreen({
    super.key,
    required this.accessToken,
    required this.complaintId,
  });

  @override
  State<CitizenComplaintDetailScreen> createState() =>
      _CitizenComplaintDetailScreenState();
}

class _CitizenComplaintDetailScreenState
    extends State<CitizenComplaintDetailScreen> {
  final TextEditingController _feedbackController = TextEditingController();
  final ImagePicker _imagePicker = ImagePicker();

  Map<String, dynamic>? _detail;
  XFile? _evidencePhoto;
  Uint8List? _evidencePhotoBytes;
  bool _isLoading = true;
  bool _isSavingVerification = false;
  bool _isLookingUpAddress = false;
  bool _showMapPreview = false;
  String? _error;
  String? _address;
  String? _addressError;

  @override
  void initState() {
    super.initState();
    _loadComplaint();
  }

  @override
  void dispose() {
    _feedbackController.dispose();
    super.dispose();
  }

  Future<void> _loadComplaint() async {
    final token = widget.accessToken;
    if (token == null || token.isEmpty) {
      setState(() {
        _isLoading = false;
        _error = 'Please sign in again to view this complaint.';
      });
      return;
    }

    setState(() {
      _isLoading = true;
      _error = null;
    });
    try {
      final detail = await ApiService.getComplaint(
        token: token,
        complaintId: widget.complaintId,
      );
      if (!mounted) return;
      setState(() => _detail = detail);
      await _lookupAddress(detail);
    } catch (error) {
      if (!mounted) return;
      setState(() => _error = _apiErrorMessage(error));
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _lookupAddress(Map<String, dynamic> detail) async {
    final latitude = detail['latitude'];
    final longitude = detail['longitude'];
    if (latitude is! num || longitude is! num) {
      setState(() {
        _address = null;
        _addressError = 'Coordinates are not available for this complaint.';
      });
      return;
    }

    setState(() {
      _isLookingUpAddress = true;
      _addressError = null;
    });
    try {
      final placemarks = await placemarkFromCoordinates(
        latitude.toDouble(),
        longitude.toDouble(),
      );
      if (!mounted) return;
      final placemark = placemarks.isEmpty ? null : placemarks.first;
      final parts = [
        placemark?.name,
        placemark?.street,
        placemark?.subLocality,
        placemark?.locality,
        placemark?.administrativeArea,
        placemark?.postalCode,
      ]
          .whereType<String>()
          .map((part) => part.trim())
          .where((part) => part.isNotEmpty)
          .toSet()
          .toList();
      setState(() {
        _address = parts.isEmpty ? null : parts.join(', ');
        _addressError = parts.isEmpty
            ? 'No address label was returned; coordinates are shown below.'
            : null;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _address = null;
        _addressError =
            'Address lookup is unavailable; coordinates are shown below.';
      });
    } finally {
      if (mounted) setState(() => _isLookingUpAddress = false);
    }
  }

  Future<void> _pickEvidencePhoto(ImageSource source) async {
    try {
      final photo = await _imagePicker.pickImage(
        source: source,
        imageQuality: 80,
      );
      if (photo != null && mounted) {
        final bytes = await photo.readAsBytes();
        if (!mounted) return;
        if (bytes.length > 5 * 1024 * 1024) {
          setState(() {
            _evidencePhoto = null;
            _evidencePhotoBytes = null;
          });
          _showMessage(
            'Evidence photo must be 5 MB or smaller.',
            isError: true,
          );
          return;
        }
        setState(() {
          _evidencePhoto = photo;
          _evidencePhotoBytes = bytes;
        });
      }
    } catch (error) {
      if (mounted) {
        _showMessage('Unable to select a photo: $error', isError: true);
      }
    }
  }

  String? _photoContentType(XFile photo) {
    final mimeType = photo.mimeType?.toLowerCase();
    if (mimeType == 'image/jpeg' ||
        mimeType == 'image/png' ||
        mimeType == 'image/webp') {
      return mimeType;
    }
    final extension = photo.path.split('.').last.toLowerCase();
    return switch (extension) {
      'jpg' || 'jpeg' => 'image/jpeg',
      'png' => 'image/png',
      'webp' => 'image/webp',
      _ => null,
    };
  }

  String _photoFileName(String contentType) {
    final extension = contentType == 'image/jpeg'
        ? 'jpg'
        : contentType.split('/').last;
    return 'verification-evidence.$extension';
  }

  Future<void> _submitVerification(String result) async {
    if (_isSavingVerification || _detail?['verification_eligible'] != true) {
      return;
    }
    final token = widget.accessToken;
    if (token == null || token.isEmpty) {
      _showMessage('Please sign in again before responding.', isError: true);
      return;
    }
    final photo = _evidencePhoto;
    final photoContentType = photo == null ? null : _photoContentType(photo);
    if (photo != null && photoContentType == null) {
      _showMessage(
        'Use a JPEG, PNG, or WebP photo for evidence.',
        isError: true,
      );
      return;
    }

    setState(() => _isSavingVerification = true);
    try {
      await ApiService.submitCitizenVerification(
        token: token,
        complaintId: widget.complaintId,
        result: result,
        feedback: _feedbackController.text,
        photoBytes: _evidencePhotoBytes,
        photoFileName: photo == null || photoContentType == null
            ? null
            : _photoFileName(photoContentType),
        photoContentType: photoContentType,
      );
      if (!mounted) return;
      Navigator.pop(context, true);
    } catch (error) {
      if (mounted) {
        _showMessage(
          'Unable to save your response: ${_apiErrorMessage(error)}',
          isError: true,
        );
      }
    } finally {
      if (mounted) setState(() => _isSavingVerification = false);
    }
  }

  void _showMessage(String message, {bool isError = false}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: isError ? Colors.redAccent : null,
      ),
    );
  }

  Future<void> _openMap(double latitude, double longitude) async {
    final mapUri = Uri.https('www.openstreetmap.org', '/', {
      'mlat': latitude.toString(),
      'mlon': longitude.toString(),
      'zoom': '16',
    });
    try {
      if (!await launchUrl(mapUri, mode: LaunchMode.externalApplication) &&
          mounted) {
        _showMessage('Unable to open the map link.', isError: true);
      }
    } catch (error) {
      if (mounted) {
        _showMessage('Unable to open the map link: $error', isError: true);
      }
    }
  }

  Widget _buildMapPreview(double latitude, double longitude) {
    const zoom = 15;
    const tileSize = 256.0;
    const tileCount = 1 << zoom;
    final safeLatitude = latitude.clamp(-85.05112878, 85.05112878);
    final latitudeRadians = safeLatitude * math.pi / 180;
    final scaledX = (longitude + 180) / 360 * tileCount;
    final scaledY =
        (1 -
            math.log(
                  math.tan(latitudeRadians) + 1 / math.cos(latitudeRadians),
                ) /
                math.pi) /
        2 *
        tileCount;
    final tileX = scaledX.floor().clamp(0, tileCount - 1);
    final tileY = scaledY.floor().clamp(0, tileCount - 1);
    final markerX = (scaledX - tileX) * tileSize;
    final markerY = (scaledY - tileY) * tileSize;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(10),
          child: SizedBox(
            width: tileSize,
            height: tileSize,
            child: Stack(
              children: [
                Image.network(
                  'https://tile.openstreetmap.org/$zoom/$tileX/$tileY.png',
                  width: tileSize,
                  height: tileSize,
                  fit: BoxFit.cover,
                  errorBuilder: (context, error, stackTrace) => const Center(
                    child: Text(
                      'Map preview unavailable. Check your connection.',
                      textAlign: TextAlign.center,
                    ),
                  ),
                ),
                Positioned(
                  left: (markerX - 16).clamp(0, tileSize - 32).toDouble(),
                  top: (markerY - 30).clamp(0, tileSize - 32).toDouble(),
                  child: const Icon(
                    Icons.location_pin,
                    size: 32,
                    color: Colors.red,
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 4),
        const Text(
          'Map tiles © OpenStreetMap contributors',
          style: TextStyle(fontSize: 11, color: Colors.grey),
        ),
      ],
    );
  }

  String _eventTitle(String eventType, String status) {
    return switch (eventType) {
      'SUBMITTED' => 'Complaint submitted',
      'ASSIGNED' => 'Worker assignment recorded',
      'IN_PROGRESS' => 'Worker started work',
      'COMPLETED' => 'Worker marked work complete',
      'CITIZEN_VERIFIED' => 'Citizen confirmed resolution',
      'CITIZEN_DISPUTED' => 'Citizen reported work unresolved',
      _ => status.replaceAll('_', ' '),
    };
  }

  String _statusLabel(String status) {
    return switch (status) {
      'CITIZEN_VERIFIED' => 'Citizen confirmed resolution',
      'CITIZEN_DISPUTED' => 'Citizen reported unresolved work',
      'COMPLETED' => 'Worker marked work complete — your verification is pending',
      _ => status.replaceAll('_', ' '),
    };
  }

  Widget _buildVerificationEvidenceImage(String token) {
    return Image.network(
      ApiService.citizenVerificationEvidenceUri(widget.complaintId).toString(),
      headers: {'Authorization': 'Bearer $token'},
      height: 180,
      width: double.infinity,
      fit: BoxFit.cover,
      loadingBuilder: (context, child, progress) => progress == null
          ? child
          : const SizedBox(
              height: 180,
              child: Center(child: CircularProgressIndicator()),
            ),
      errorBuilder: (context, error, stackTrace) => const Text(
        'Evidence photo is currently unavailable.',
        style: TextStyle(color: Colors.orange),
      ),
    );
  }

  Widget _buildComplaintDetails(Map<String, dynamic> detail) {
    final latitude = detail['latitude'];
    final longitude = detail['longitude'];
    final createdAt = DateTime.tryParse(
      detail['created_at']?.toString() ?? '',
    );
    final history = detail['status_history'] is List
        ? (detail['status_history'] as List).whereType<Map<String, dynamic>>()
        : const <Map<String, dynamic>>[];
    final verification = detail['verification'] is Map<String, dynamic>
        ? detail['verification'] as Map<String, dynamic>
        : null;
    final token = widget.accessToken;

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SelectableText(
                  'Complaint ${detail['complaint_id'] ?? widget.complaintId}',
                  style: const TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  detail['category']?.toString() ?? 'Category not recorded',
                  style: const TextStyle(fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 8),
                Chip(label: Text(_statusLabel(detail['status']?.toString() ?? 'Unknown'))),
                if (createdAt != null)
                  Text('Reported ${_formatComplaintDate(createdAt)}'),
                if (detail['assigned_worker_name'] != null)
                  Text('Assigned worker: ${detail['assigned_worker_name']}'),
                if (detail['assigned_worker_name'] == null &&
                    detail['assigned_worker_id'] != null)
                  Text(
                    'Worker assignment recorded '
                    '(ID ${detail['assigned_worker_id']})',
                  ),
                const SizedBox(height: 8),
                Text(detail['description']?.toString() ?? ''),
                const Divider(height: 24),
                Text(
                  _isLookingUpAddress
                      ? 'Looking up a nearby address…'
                      : _address ?? _addressError ?? 'Address unavailable.',
                  style: TextStyle(
                    color: _address == null ? Colors.grey : null,
                  ),
                ),
                if (latitude is num && longitude is num) ...[
                  const SizedBox(height: 4),
                  SelectableText(
                    'Coordinates: ${latitude.toStringAsFixed(6)}, '
                    '${longitude.toStringAsFixed(6)}',
                  ),
                  TextButton.icon(
                    onPressed: _isLookingUpAddress
                        ? null
                        : () => _lookupAddress(detail),
                    icon: const Icon(Icons.location_searching, size: 18),
                    label: const Text('Retry address lookup'),
                  ),
                  OutlinedButton.icon(
                    onPressed: () => setState(
                      () => _showMapPreview = !_showMapPreview,
                    ),
                    icon: const Icon(Icons.map_outlined),
                    label: Text(
                      _showMapPreview ? 'Hide map preview' : 'Load map preview',
                    ),
                  ),
                  if (_showMapPreview) ...[
                    const SizedBox(height: 8),
                    _buildMapPreview(
                      latitude.toDouble(),
                      longitude.toDouble(),
                    ),
                    const SizedBox(height: 8),
                    TextButton.icon(
                      onPressed: () => _openMap(
                        latitude.toDouble(),
                        longitude.toDouble(),
                      ),
                      icon: const Icon(Icons.open_in_new, size: 18),
                      label: const Text('Open exact location in OpenStreetMap'),
                    ),
                    const Text(
                      'Loading the preview sends tile coordinates to '
                      'OpenStreetMap; opening the full map shares this exact '
                      'location.',
                      style: TextStyle(fontSize: 12, color: Colors.grey),
                    ),
                  ],
                ],
              ],
            ),
          ),
        ),
        const SizedBox(height: 8),
        Text('Progress', style: Theme.of(context).textTheme.titleLarge),
        const SizedBox(height: 4),
        if (history.isEmpty)
          const Card(
            child: Padding(
              padding: EdgeInsets.all(16),
              child: Text(
                'No status-change events are recorded for this complaint yet. '
                'The current status above comes from the server.',
              ),
            ),
          )
        else
          ...history.map((event) {
            final changedAt = DateTime.tryParse(
              event['changed_at']?.toString() ?? '',
            );
            final eventType = event['event_type']?.toString() ?? '';
            final status = event['status']?.toString() ?? '';
            return ListTile(
              contentPadding: const EdgeInsets.symmetric(horizontal: 8),
              leading: const Icon(Icons.check_circle_outline),
              title: Text(_eventTitle(eventType, status)),
              subtitle: Text(
                changedAt == null
                    ? status.replaceAll('_', ' ')
                    : '${status.replaceAll('_', ' ')} · '
                        '${_formatComplaintDate(changedAt)} '
                        '${changedAt.toLocal().hour.toString().padLeft(2, '0')}:'
                        '${changedAt.toLocal().minute.toString().padLeft(2, '0')}',
              ),
            );
          }),
        if (verification != null) ...[
          const SizedBox(height: 8),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    verification['result'] == 'RESOLVED'
                        ? 'You confirmed the resolution'
                        : 'You reported that the work is unresolved',
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                  if (verification['feedback'] != null) ...[
                    const SizedBox(height: 8),
                    Text(verification['feedback'].toString()),
                  ],
                  if (verification['evidence_available'] == true &&
                      token != null)
                    Padding(
                      padding: const EdgeInsets.only(top: 12),
                      child: _buildVerificationEvidenceImage(token),
                    ),
                ],
              ),
            ),
          ),
        ],
        if (detail['status'] == 'COMPLETED' &&
            detail['verification'] == null &&
            detail['verification_eligible'] != true)
          const Card(
            child: Padding(
              padding: EdgeInsets.all(16),
              child: Text(
                'The complaint is marked complete, but the server has no '
                'recorded Worker completion event to verify. Contact the '
                'Authority for review.',
              ),
            ),
          ),
        if (detail['verification_eligible'] == true) ...[
          const SizedBox(height: 8),
          Card(
            color: Theme.of(context).colorScheme.surfaceContainerHighest,
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Has the work resolved the issue?',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  const SizedBox(height: 4),
                  const Text(
                    'The Worker marked this complaint complete. That is not '
                    'the same as your verification. Your response will be '
                    'saved to this complaint and cannot be submitted twice.',
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: _feedbackController,
                    maxLength: 2000,
                    maxLines: 3,
                    decoration: const InputDecoration(
                      labelText: 'Optional feedback',
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 8),
                  if (_evidencePhoto != null) ...[
                    ClipRRect(
                      borderRadius: BorderRadius.circular(8),
                      child: Image.memory(
                        _evidencePhotoBytes!,
                        height: 180,
                        width: double.infinity,
                        fit: BoxFit.cover,
                      ),
                    ),
                    Align(
                      alignment: Alignment.centerRight,
                      child: TextButton(
                        onPressed: _isSavingVerification
                            ? null
                              : () => setState(() {
                                    _evidencePhoto = null;
                                    _evidencePhotoBytes = null;
                                  }),
                        child: const Text('Remove photo'),
                      ),
                    ),
                  ],
                  OutlinedButton.icon(
                    onPressed: _isSavingVerification
                        ? null
                        : () => showModalBottomSheet<void>(
                            context: context,
                            builder: (context) => SafeArea(
                              child: Wrap(
                                children: [
                                  ListTile(
                                    leading: const Icon(Icons.camera_alt),
                                    title: const Text('Take a photo'),
                                    onTap: () {
                                      Navigator.pop(context);
                                      _pickEvidencePhoto(ImageSource.camera);
                                    },
                                  ),
                                  ListTile(
                                    leading: const Icon(Icons.photo_library),
                                    title: const Text('Choose from photos'),
                                    onTap: () {
                                      Navigator.pop(context);
                                      _pickEvidencePhoto(ImageSource.gallery);
                                    },
                                  ),
                                ],
                              ),
                            ),
                          ),
                    icon: const Icon(Icons.add_a_photo),
                    label: Text(
                      _evidencePhoto == null
                          ? 'Attach optional photo evidence'
                          : 'Replace photo evidence',
                    ),
                  ),
                  const SizedBox(height: 12),
                  if (_isSavingVerification)
                    const Center(child: CircularProgressIndicator())
                  else
                    Wrap(
                      spacing: 12,
                      runSpacing: 8,
                      children: [
                        FilledButton.icon(
                          onPressed: () => _submitVerification('RESOLVED'),
                          icon: const Icon(Icons.check),
                          label: const Text('Yes, resolved'),
                        ),
                        OutlinedButton.icon(
                          onPressed: () =>
                              _submitVerification('NOT_RESOLVED'),
                          icon: const Icon(Icons.report_outlined),
                          label: const Text('No, still unresolved'),
                        ),
                      ],
                    ),
                  const SizedBox(height: 8),
                  const Text(
                    'Photos are uploaded with your response and stored '
                    'privately by the service.',
                    style: TextStyle(fontSize: 12, color: Colors.grey),
                  ),
                ],
              ),
            ),
          ),
        ],
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Complaint progress')),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
          ? Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      'Unable to load complaint details: $_error',
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 12),
                    ElevatedButton(
                      onPressed: _loadComplaint,
                      child: const Text('Try again'),
                    ),
                  ],
                ),
              ),
            )
          : _detail == null
          ? const Center(child: Text('Complaint details are unavailable.'))
          : _buildComplaintDetails(_detail!),
    );
  }
}

// ==========================================
// CITY HEATMAP SCREEN
// ==========================================
class HeatmapScreen extends StatelessWidget {
  const HeatmapScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('City Infrastructure Heatmap')),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Probable Civic Incident Clusters',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            const Text(
              'Spatial and temporal analysis showing high-density problem areas across the municipality.',
              style: TextStyle(color: Colors.grey),
            ),
            const SizedBox(height: 20),
            Expanded(
              child: Container(
                decoration: BoxDecoration(
                  color: Colors.blueGrey.shade50,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.blueGrey.shade200),
                ),
                child: const Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.map_rounded,
                        size: 80,
                        color: Colors.blueAccent,
                      ),
                      SizedBox(height: 12),
                      Text(
                        'Connaught Place Hotspot: 12 Pothole Reports Fused',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          color: Colors.black87,
                        ),
                      ),
                      SizedBox(height: 4),
                      Text(
                        'Nehru Place Cluster: Streetlight Outage & Drainage Warning',
                        style: TextStyle(color: Colors.grey),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ==========================================
// PROFILE SCREEN (CITIZEN USER CARD LAYOUT)
// ==========================================
class ProfileScreen extends StatefulWidget {
  final UserProfile user;
  const ProfileScreen({super.key, required this.user});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  final ImagePicker _picker = ImagePicker();

  Future<void> _pickProfilePhoto(ImageSource source) async {
    try {
      final XFile? pickedFile = await _picker.pickImage(
        source: source,
        imageQuality: 70,
      );
      if (pickedFile != null) {
        setState(() {
          widget.user.profileImagePath = pickedFile.path;
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error updating photo: $e')));
      }
    }
  }

  void _showImagePickerModal() {
    showModalBottomSheet(
      context: context,
      builder: (context) => SafeArea(
        child: Wrap(
          children: [
            ListTile(
              leading: const Icon(Icons.camera_alt),
              title: const Text('Capture with Camera'),
              onTap: () {
                Navigator.pop(context);
                _pickProfilePhoto(ImageSource.camera);
              },
            ),
            ListTile(
              leading: const Icon(Icons.photo_library),
              title: const Text('Select from Gallery'),
              onTap: () {
                Navigator.pop(context);
                _pickProfilePhoto(ImageSource.gallery);
              },
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('User Profile Details')),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: ListView(
          children: [
            const SizedBox(height: 12),
            Center(
              child: Stack(
                children: [
                  CircleAvatar(
                    radius: 50,
                    backgroundColor: appTheme.primaryColor,
                    backgroundImage: widget.user.profileImagePath != null
                        ? FileImage(File(widget.user.profileImagePath!))
                        : null,
                    child: widget.user.profileImagePath == null
                        ? const Icon(
                            Icons.person,
                            size: 60,
                            color: Colors.white,
                          )
                        : null,
                  ),
                  Positioned(
                    bottom: 0,
                    right: 0,
                    child: CircleAvatar(
                      backgroundColor: Colors.white,
                      radius: 18,
                      child: IconButton(
                        icon: const Icon(
                          Icons.edit,
                          size: 18,
                          color: Colors.blue,
                        ),
                        onPressed: _showImagePickerModal,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),
            _buildProfileCard(Icons.person, 'Full Name', widget.user.fullName),
            _buildProfileCard(Icons.email, 'Gmail ID', widget.user.email),
            _buildProfileCard(Icons.phone, 'Mobile Number', widget.user.mobile),
            _buildProfileCard(
              Icons.verified_user,
              'Account Type',
              'Citizen Registered Account',
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildProfileCard(IconData icon, String label, String value) {
    return Card(
      elevation: 2,
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: appTheme.primaryColor.withValues(alpha: 0.1),
          child: Icon(icon, color: appTheme.primaryColor),
        ),
        title: Text(
          label,
          style: const TextStyle(
            fontSize: 12,
            color: Colors.grey,
            fontWeight: FontWeight.bold,
          ),
        ),
        subtitle: Text(
          value,
          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
        ),
      ),
    );
  }
}

// ==========================================
// CREATE COMPLAINT SCREEN
// ==========================================
class CreateComplaintScreen extends StatefulWidget {
  final String userEmail;
  final String? accessToken;

  const CreateComplaintScreen({
    super.key,
    required this.userEmail,
    this.accessToken,
  });

  @override
  State<CreateComplaintScreen> createState() => _CreateComplaintScreenState();
}

class _CreateComplaintScreenState extends State<CreateComplaintScreen> {
  final _formKey = GlobalKey<FormState>();
  bool _isSubmitting = false;
  String _category = 'Pothole & Road Damage';
  String _severity = 'Medium';
  final TextEditingController _descController = TextEditingController();
  final TextEditingController _locationController = TextEditingController();
  File? _imageFile;
  final ImagePicker _picker = ImagePicker();
  double? _latitude;
  double? _longitude;

  @override
  void dispose() {
    _descController.dispose();
    _locationController.dispose();
    super.dispose();
  }

  Future<void> _getCurrentLocation() async {
    try {
      final bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        throw Exception('Please enable your phone location.');
      }

      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }

      if (permission == LocationPermission.denied ||
          permission == LocationPermission.deniedForever) {
        throw Exception('Location permission is required.');
      }

      final Position position = await Geolocator.getCurrentPosition();

      if (!mounted) return;

      setState(() {
        _latitude = position.latitude;
        _longitude = position.longitude;
        _locationController.text =
            '${position.latitude}, ${position.longitude}';
      });

      _showSuccess('Location captured successfully!');
    } catch (e) {
      if (!mounted) return;
      _showError('Location error: $e');
    }
  }

  void _showSuccess(String message) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  void _promptCameraPermissionAndCapture() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Allow Camera Access'),
        content: const Text(
          'Take an optional photo for a preview on this device. The prototype does not upload or save captured photos.',
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              _takeLivePhoto();
            },
            child: const Text('Allow Only While Using App'),
          ),
        ],
      ),
    );
  }

  void _promptGpsPermission() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Allow Location Access'),
        content: const Text(
          'Allow SahaySetu to access this device\'s location to tag exact geo-coordinates?',
        ),
        actions: [
          TextButton(
            onPressed: () async {
              Navigator.pop(context);
              await _getCurrentLocation();
            },

            child: const Text('While Using App'),
          ),
        ],
      ),
    );
  }

  Future<void> _takeLivePhoto() async {
    try {
      final XFile? pickedFile = await _picker.pickImage(
        source: ImageSource.camera,
        imageQuality: 70,
      );
      if (pickedFile != null) {
        setState(() => _imageFile = File(pickedFile.path));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Camera error: $e')));
      }
    }
  }

  Future<void> _submit() async {
    if (_isSubmitting) return;
    if (!_formKey.currentState!.validate()) return;

    if (_latitude == null || _longitude == null) {
      _showError('Please capture your current location first.');
      return;
    }

    final String? token = widget.accessToken;
    if (token == null || token.isEmpty) {
      _showError('Please log in again before submitting.');
      return;
    }

    final String description = _descController.text.trim();

    setState(() => _isSubmitting = true);
    try {
      final Map<String, dynamic> result = await ApiService.createComplaint(
        token: token,
        description: description,
        category: _category,
        severity: _severity,
        latitude: _latitude!,
        longitude: _longitude!,
      );

      if (!mounted) return;

      final Complaint newComplaint = Complaint.fromApi(
        result,
        citizenEmail: widget.userEmail,
      );

      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (context) =>
              SubmissionFeedbackScreen(complaint: newComplaint),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      _showError('Complaint submission failed: $e');
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), backgroundColor: Colors.redAccent),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Report New Complaint')),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Form(
          key: _formKey,
          child: ListView(
            children: [
              DropdownButtonFormField<String>(
                initialValue: _category,
                items:
                    [
                          'Pothole & Road Damage',
                          'Broken Streetlight',
                          'Garbage Accumulation',
                          'Water Leakage',
                          'Blocked Drainage',
                        ]
                        .map((c) => DropdownMenuItem(value: c, child: Text(c)))
                        .toList(),
                onChanged: (val) => setState(() => _category = val!),
                decoration: const InputDecoration(
                  labelText: 'Category *',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 16),
              DropdownButtonFormField<String>(
                initialValue: _severity,
                items: ['Low', 'Medium', 'High', 'Critical']
                    .map((s) => DropdownMenuItem(value: s, child: Text(s)))
                    .toList(),
                onChanged: (val) => setState(() => _severity = val!),
                decoration: const InputDecoration(
                  labelText: 'Severity Level *',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _descController,
                maxLines: 3,
                decoration: const InputDecoration(
                  labelText: 'Description *',
                  border: OutlineInputBorder(),
                ),
                validator: (val) => val == null || val.trim().length < 10
                    ? 'Enter min 10 characters'
                    : null,
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _locationController,
                decoration: InputDecoration(
                  labelText: 'Captured GPS coordinates *',
                  border: const OutlineInputBorder(),
                  suffixIcon: IconButton(
                    icon: const Icon(Icons.my_location, color: Colors.blue),
                    onPressed: _promptGpsPermission,
                  ),
                ),
                readOnly: true,
                validator: (_) =>
                    _latitude == null || _longitude == null
                        ? 'Capture your location'
                        : null,
              ),
              const SizedBox(height: 20),
              const Text(
                'Photo evidence is optional. A selected photo stays on this device; this prototype does not upload or save it.',
                style: TextStyle(color: Colors.orangeAccent),
              ),
              const SizedBox(height: 8),
              OutlinedButton.icon(
                onPressed: _promptCameraPermissionAndCapture,
                icon: const Icon(Icons.camera_alt),
                label: const Text('Capture Live Photo'),
              ),
              if (_imageFile != null) ...[
                const SizedBox(height: 12),
                Container(
                  height: 140,
                  decoration: BoxDecoration(
                    image: DecorationImage(
                      image: FileImage(_imageFile!),
                      fit: BoxFit.cover,
                    ),
                  ),
                ),
              ],
              const SizedBox(height: 24),
              ElevatedButton(
                onPressed: _isSubmitting ? null : _submit,
                child: _isSubmitting
                    ? const SizedBox(
                        height: 20,
                        width: 20,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Text('Submit Complaint'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ==========================================
// SUBMISSION CONFIRMATION
// ==========================================
class SubmissionFeedbackScreen extends StatelessWidget {
  final Complaint complaint;
  const SubmissionFeedbackScreen({super.key, required this.complaint});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Submission Confirmed')),
      body: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(
              Icons.check_circle_rounded,
              size: 80,
              color: Colors.green,
            ),
            const SizedBox(height: 12),
            const Text(
              'Complaint submitted successfully',
              style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            Text(
              'Complaint ID: ${complaint.id}',
              textAlign: TextAlign.center,
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Text('Current status: ${complaint.status}'),
            const SizedBox(height: 8),
            const Text(
              'Your complaint has been saved to the server.',
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            ElevatedButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Return to Dashboard'),
            ),
          ],
        ),
      ),
    );
  }
}

// ==========================================
// FIELD WORKER MODULE
// ==========================================
class WorkerLoginScreen extends StatefulWidget {
  const WorkerLoginScreen({super.key});

  @override
  State<WorkerLoginScreen> createState() => _WorkerLoginScreenState();
}

class _WorkerLoginScreenState extends State<WorkerLoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final bool _obscureWorkerPass = true;
  final TextEditingController _usernameController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();

  Future<void> _loginWorker() async {
    if (!_formKey.currentState!.validate()) return;

    try {
      final data = await ApiService.login(
        email: _usernameController.text.trim(),
        password: _passwordController.text,
      );

      if (data['role'] != 'WORKER') {
        throw Exception('This account is not a worker account.');
      }

      final token = data['access_token'] as String;
      final authenticatedUser = await ApiService.getCurrentUser(
        token: token,
      );
      if (authenticatedUser['role'] != 'WORKER') {
        throw Exception('This account is not a worker account.');
      }

      if (!mounted) return;

      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (context) => WorkerDashboardScreen(
            workerId: authenticatedUser['user_id']?.toString() ?? '',
            workerName: authenticatedUser['name']?.toString() ?? '',
            workerEmail: authenticatedUser['email']?.toString() ?? '',
            workerCategory:
                authenticatedUser['worker_category']?.toString() ?? '',
            role: authenticatedUser['role'] as String,
            accessToken: token,
          ),
        ),
      );
    } catch (e) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Worker login failed: ${e.toString()}')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Field Worker Portal')),
      body: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Form(
          key: _formKey,
          child: ListView(
            children: [
              const SizedBox(height: 20),
              const Icon(Icons.engineering, size: 70, color: Color(0xFF0F172A)),
              const SizedBox(height: 16),
              const Text(
                'Worker Authentication',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 32),
              TextFormField(
                controller: _usernameController,
                decoration: const InputDecoration(
                  labelText: 'Worker email',
                  border: OutlineInputBorder(),
                ),
                validator: (val) => val == null || !val.contains('@')
                    ? 'Enter a valid worker email'
                    : null,
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _passwordController,
                obscureText: _obscureWorkerPass,
                decoration: const InputDecoration(
                  labelText: 'Password',
                  border: OutlineInputBorder(),
                ),
                validator: (val) =>
                    val == null || val.isEmpty ? 'Enter password' : null,
              ),
              const SizedBox(height: 24),
              ElevatedButton(
                onPressed: _loginWorker,
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF0F172A),
                ),
                child: const Text('Worker Sign In'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class WorkerDashboardScreen extends StatefulWidget {
  final String workerId;
  final String workerName;
  final String workerEmail;
  final String workerCategory;
  final String role;
  final String accessToken;

  const WorkerDashboardScreen({
    super.key,
    required this.workerId,
    required this.workerName,
    required this.workerEmail,
    required this.workerCategory,
    required this.role,
    required this.accessToken,
  });

  @override
  State<WorkerDashboardScreen> createState() => _WorkerDashboardScreenState();
}

class _WorkerDashboardScreenState extends State<WorkerDashboardScreen> {
  List<Complaint> _tasks = [];
  bool _isLoading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadTasks();
  }

  Future<void> _loadTasks() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });
    try {
      final records = await ApiService.getWorkerComplaints(
        token: widget.accessToken,
      );
      final tasks = records
          .map((record) => Complaint.fromApi(record, citizenEmail: ''))
          .toList(growable: false);
      if (!mounted) return;
      setState(() => _tasks = tasks);
    } catch (error) {
      if (!mounted) return;
      setState(() => _error = _apiErrorMessage(error));
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final workerInfo = WorkerProfile(
      workerId: widget.workerId,
      fullName: widget.workerName,
      department: widget.workerCategory.isEmpty
          ? 'Category not assigned'
          : widget.workerCategory,
      wardZone: 'Not provided',
      officialEmail: widget.workerEmail,
      mobile: 'Not provided',
      designation: 'Worker account',
    );

    return Scaffold(
      appBar: AppBar(
        backgroundColor: const Color(0xFF0F172A),
        title: Text('Worker: ${widget.workerId}'),
      ),
      drawer: Drawer(
        child: ListView(
          padding: EdgeInsets.zero,
          children: [
            UserAccountsDrawerHeader(
              accountName: Text(
                workerInfo.fullName,
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
              accountEmail: Text(
                '${workerInfo.designation}\n${workerInfo.department}',
              ),
              currentAccountPicture: const CircleAvatar(
                backgroundColor: Colors.white,
                child: Icon(
                  Icons.engineering,
                  size: 40,
                  color: Color(0xFF0F172A),
                ),
              ),
              decoration: const BoxDecoration(color: Color(0xFF0F172A)),
            ),
            ListTile(
              leading: const Icon(Icons.assignment),
              title: const Text('Department Tasks'),
              onTap: () => Navigator.pop(context),
            ),
            ListTile(
              leading: const Icon(Icons.badge),
              title: const Text('Worker Profile Details'),
              onTap: () {
                Navigator.pop(context);
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) =>
                        WorkerProfileDetailScreen(worker: workerInfo),
                  ),
                );
              },
            ),
            ListTile(
              leading: const Icon(Icons.check_circle_outline),
              title: const Text('Resolved Complaints History'),
              onTap: () {
                Navigator.pop(context);
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) =>
                        WorkerResolvedHistoryScreen(
                          accessToken: widget.accessToken,
                        ),
                  ),
                );
              },
            ),
            ListTile(
              leading: const Icon(Icons.settings),
              title: const Text('Settings'),
              onTap: () {
                Navigator.pop(context);
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => const SettingsScreen(),
                  ),
                );
              },
            ),
            const Divider(),
            ListTile(
              leading: const Icon(Icons.logout, color: Colors.red),
              title: const Text('Logout', style: TextStyle(color: Colors.red)),
              onTap: () {
                Navigator.pushAndRemoveUntil(
                  context,
                  MaterialPageRoute(
                    builder: (context) => const RoleSelectionScreen(),
                  ),
                  (route) => false,
                );
              },
            ),
          ],
        ),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
          ? Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      _error!,
                      textAlign: TextAlign.center,
                      style: const TextStyle(color: Colors.redAccent),
                    ),
                    const SizedBox(height: 12),
                    ElevatedButton(
                      onPressed: _loadTasks,
                      child: const Text('Try again'),
                    ),
                    if (_error!.contains('sign in again'))
                      TextButton(
                        onPressed: _logout,
                        child: const Text('Return to sign in'),
                      ),
                  ],
                ),
              ),
            )
          : _tasks.isEmpty
          ? RefreshIndicator(
              onRefresh: _loadTasks,
              child: ListView(
                physics: const AlwaysScrollableScrollPhysics(),
                children: const [
                  SizedBox(height: 180),
                  Center(child: Text('No complaints are assigned to you.')),
                ],
              ),
            )
          : RefreshIndicator(
              onRefresh: _loadTasks,
              child: ListView.builder(
                padding: const EdgeInsets.all(16),
                itemCount: _tasks.length,
                itemBuilder: (context, index) {
                  final complaint = _tasks[index];
                  return Card(
                    margin: const EdgeInsets.only(bottom: 12),
                    child: ListTile(
              title: Text(
                complaint.id,
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF0F172A),
                ),
              ),
              subtitle: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const SizedBox(height: 4),
                  Text(
                    complaint.category,
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                  Text(complaint.location),
                  const SizedBox(height: 4),
                  Text(
                    'Status: ${complaint.status}',
                    style: TextStyle(
                      color: _getStatusColor(complaint.status),
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
              trailing: const Icon(Icons.arrow_forward_ios, size: 16),
              onTap: () async {
                await Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => WorkerTaskDetailScreen(
                      complaint: complaint,
                      workerId: widget.workerId,
                      accessToken: widget.accessToken,
                    ),
                  ),
                );
                await _loadTasks();
              },
            ),
                  );
                },
              ),
            ),
    );
  }

  void _logout() {
    Navigator.pushAndRemoveUntil(
      context,
      MaterialPageRoute(builder: (context) => const RoleSelectionScreen()),
      (route) => false,
    );
  }

  Color _getStatusColor(String status) {
    switch (status) {
      case 'Pending':
      case 'SUBMITTED':
      case 'ASSIGNED':
        return Colors.orange;
      case 'In Progress':
      case 'IN_PROGRESS':
        return Colors.blue;
      case 'Resolved / Awaiting Verification':
      case 'COMPLETED':
        return Colors.purple;
      case 'Closed':
        return Colors.green;
      default:
        return Colors.grey;
    }
  }
}

// ==========================================
// WORKER PROFILE DETAILS (CARD LAYOUT)
// ==========================================
class WorkerProfileDetailScreen extends StatelessWidget {
  final WorkerProfile worker;
  const WorkerProfileDetailScreen({super.key, required this.worker});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: const Color(0xFF0F172A),
        title: const Text('Worker Profile Details'),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: ListView(
          children: [
            const SizedBox(height: 12),
            const Center(
              child: Stack(
                children: [
                  CircleAvatar(
                    radius: 50,
                    backgroundColor: Color(0xFF0F172A),
                    child: Icon(Icons.badge, size: 55, color: Colors.white),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            const Text(
              'Worker account profile',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 13,
                color: Colors.grey,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 20),
            _buildWorkerCard(Icons.person, 'Full Name', worker.fullName),
            _buildWorkerCard(Icons.work, 'Designation', worker.designation),
            _buildWorkerCard(Icons.category, 'Department', worker.department),
            _buildWorkerCard(Icons.map, 'Assigned Zone', worker.wardZone),
            _buildWorkerCard(
              Icons.badge_outlined,
              'Account ID',
              worker.workerId,
            ),
            _buildWorkerCard(Icons.email, 'Account Email', worker.officialEmail),
            _buildWorkerCard(Icons.phone, 'Contact Number', worker.mobile),
          ],
        ),
      ),
    );
  }

  Widget _buildWorkerCard(IconData icon, String label, String value) {
    return Card(
      elevation: 2,
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: const Color(0xFF0F172A).withValues(alpha: 0.1),
          child: Icon(icon, color: const Color(0xFF0F172A)),
        ),
        title: Text(
          label,
          style: const TextStyle(
            fontSize: 12,
            color: Colors.grey,
            fontWeight: FontWeight.bold,
          ),
        ),
        subtitle: Text(
          value,
          style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
        ),
      ),
    );
  }
}

// ==========================================
// PROFESSIONAL WORKER TASK DETAIL PAGE
// ==========================================
class WorkerTaskDetailScreen extends StatefulWidget {
  final Complaint complaint;
  final String workerId;
  final String accessToken;
  const WorkerTaskDetailScreen({
    super.key,
    required this.complaint,
    required this.workerId,
    required this.accessToken,
  });

  @override
  State<WorkerTaskDetailScreen> createState() => _WorkerTaskDetailScreenState();
}

class _WorkerTaskDetailScreenState extends State<WorkerTaskDetailScreen> {
  File? _completionPhoto;
  final ImagePicker _picker = ImagePicker();
  bool _isUpdating = false;
  final TextEditingController _noteController = TextEditingController();

  @override
  void dispose() {
    _noteController.dispose();
    super.dispose();
  }

  Future<void> _captureCompletionPhoto() async {
    try {
      final XFile? pickedFile = await _picker.pickImage(
        source: ImageSource.camera,
        imageQuality: 70,
      );
      if (pickedFile != null) {
        setState(() => _completionPhoto = File(pickedFile.path));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Camera error: $e')));
      }
    }
  }

  Future<void> _updateStatus(String status) async {
    if (_isUpdating) return;
    setState(() => _isUpdating = true);
    try {
      final result = await ApiService.updateWorkerComplaintStatus(
        token: widget.accessToken,
        complaintId: widget.complaint.id,
        status: status,
      );
      final savedStatus = result['status']?.toString();
      if (savedStatus == null || savedStatus.isEmpty) {
        throw const FormatException(
          'The server did not return the updated complaint status.',
        );
      }
      if (!mounted) return;
      setState(() {
        widget.complaint.status = savedStatus;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Task status saved on the server: ${widget.complaint.status}.'),
        ),
      );
      Navigator.pop(context, true);
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(_apiErrorMessage(error)),
          backgroundColor: Colors.redAccent,
        ),
      );
    } finally {
      if (mounted) setState(() => _isUpdating = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: const Color(0xFF0F172A),
        title: Text(widget.complaint.id),
      ),
      body: Padding(
        padding: const EdgeInsets.all(20.0),
        child: ListView(
          children: [
            Text(
              widget.complaint.category,
              style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 4),
            Row(
              children: [
                const Icon(Icons.location_on, size: 16, color: Colors.grey),
                const SizedBox(width: 4),
                Text(
                  widget.complaint.location,
                  style: const TextStyle(fontSize: 15, color: Colors.grey),
                ),
              ],
            ),
            const Divider(height: 32),
            TextField(
              controller: _noteController,
              maxLines: 3,
              decoration: const InputDecoration(
                labelText: 'Work note (demo only; not saved)',
                hintText: 'Local note for this screen only',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 20),
            const Text(
              'Optional photo preview (local only; not uploaded or saved)',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            OutlinedButton.icon(
              onPressed: _captureCompletionPhoto,
              icon: const Icon(Icons.camera_alt),
              label: const Text('Capture Completion Photo'),
            ),
            if (_completionPhoto != null ||
                widget.complaint.completionPhotoPath != null) ...[
              const SizedBox(height: 12),
              Container(
                height: 140,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(8),
                  image: DecorationImage(
                    image: FileImage(
                      File(
                        _completionPhoto?.path ??
                            widget.complaint.completionPhotoPath!,
                      ),
                    ),
                    fit: BoxFit.cover,
                  ),
                ),
              ),
            ],
            const SizedBox(height: 28),
            if (widget.complaint.status == 'ASSIGNED')
              ElevatedButton(
                onPressed:
                    _isUpdating ? null : () => _updateStatus('IN_PROGRESS'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF0F172A),
                ),
                child: const Text('Start Work'),
              ),
            if (widget.complaint.status == 'IN_PROGRESS')
              ElevatedButton(
                onPressed:
                    _isUpdating ? null : () => _updateStatus('COMPLETED'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF0F172A),
                ),
                child: _isUpdating
                    ? const SizedBox(
                        height: 20,
                        width: 20,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Text('Mark Work Completed'),
              ),
            if (_isUpdating && widget.complaint.status == 'ASSIGNED')
              const Center(child: CircularProgressIndicator()),
            if (widget.complaint.status == 'COMPLETED')
              const Text(
                'The backend has recorded this task as completed. Resolution notes, photos and Citizen verification are not persisted by this workflow.',
                style: TextStyle(color: Colors.orangeAccent),
              ),
          ],
        ),
      ),
    );
  }
}

// ==========================================
// WORKER RESOLVED HISTORY SCREEN
// ==========================================
class WorkerResolvedHistoryScreen extends StatefulWidget {
  final String accessToken;
  const WorkerResolvedHistoryScreen({super.key, required this.accessToken});

  @override
  State<WorkerResolvedHistoryScreen> createState() =>
      _WorkerResolvedHistoryScreenState();
}

class _WorkerResolvedHistoryScreenState
    extends State<WorkerResolvedHistoryScreen> {
  List<Complaint> _completedTasks = [];
  bool _isLoading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadHistory();
  }

  Future<void> _loadHistory() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });
    try {
      final records = await ApiService.getWorkerComplaints(
        token: widget.accessToken,
      );
      final tasks = records
          .where((record) => record['status'] == 'COMPLETED')
          .map((record) => Complaint.fromApi(record, citizenEmail: ''))
          .toList(growable: false);
      if (!mounted) return;
      setState(() => _completedTasks = tasks);
    } catch (error) {
      if (!mounted) return;
      setState(() => _error = _apiErrorMessage(error));
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    Widget body;
    if (_isLoading) {
      body = const Center(child: CircularProgressIndicator());
    } else if (_error != null) {
      body = Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(_error!, textAlign: TextAlign.center),
              const SizedBox(height: 12),
              ElevatedButton(
                onPressed: _loadHistory,
                child: const Text('Try again'),
              ),
            ],
          ),
        ),
      );
    } else if (_completedTasks.isEmpty) {
      body = RefreshIndicator(
        onRefresh: _loadHistory,
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          children: const [
            SizedBox(height: 180),
            Center(child: Text('No completed assigned tasks yet.')),
          ],
        ),
      );
    } else {
      body = RefreshIndicator(
        onRefresh: _loadHistory,
        child: ListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: _completedTasks.length,
          itemBuilder: (context, index) {
            final task = _completedTasks[index];
            return Card(
              margin: const EdgeInsets.only(bottom: 12),
              child: ListTile(
                title: Text(
                  task.id,
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
                subtitle: Text('${task.category}\n${task.location}'),
                trailing: const Text(
                  'COMPLETED',
                  style: TextStyle(
                    color: Colors.green,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            );
          },
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(
        backgroundColor: const Color(0xFF0F172A),
        title: const Text('Resolved Complaints History'),
      ),
      body: body,
    );
  }
}
