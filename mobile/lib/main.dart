import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'dart:io';
import 'api_service.dart';
import 'package:geolocator/geolocator.dart';

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
  final String? accessToken;
  String? profileImagePath;

  UserProfile({
    required this.fullName,
    required this.email,
    required this.password,
    required this.mobile,
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
  final TextEditingController _mobileController = TextEditingController();

  void _clearFields() {
    _emailController.clear();
    _passwordController.clear();
    _confirmPasswordController.clear();
    _fullNameController.clear();
    _mobileController.clear();
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

        if (!mounted) return;

        final email = _emailController.text.trim();

        final loggedInUser = UserProfile(
          fullName: email.split('@').first,
          email: email,
          password: '',
          mobile: '',
          accessToken: data['access_token'] as String?,
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
      _showOtpVerificationDialog(
        onVerified: () async {
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
        },
      );
    }
  }

  void _showOtpVerificationDialog({required VoidCallback onVerified}) {
    final TextEditingController otpController = TextEditingController();
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        title: const Text('OTP Verification'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'An OTP has been sent to ${_mobileController.text}. (Enter any 4 digits like 1234)',
            ),
            const SizedBox(height: 12),
            TextField(
              controller: otpController,
              keyboardType: TextInputType.number,
              maxLength: 4,
              decoration: const InputDecoration(
                labelText: 'Enter 4-digit OTP',
                border: OutlineInputBorder(),
              ),
            ),
          ],
        ),
        actions: [
          ElevatedButton(
            onPressed: () {
              if (otpController.text.length == 4) {
                Navigator.pop(context);
                onVerified();
              } else {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Please enter a valid 4-digit OTP'),
                  ),
                );
              }
            },
            child: const Text('Verify & Complete'),
          ),
        ],
      ),
    );
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
                const SizedBox(height: 16),
                TextFormField(
                  controller: _mobileController,
                  keyboardType: TextInputType.phone,
                  maxLength: 10,
                  decoration: const InputDecoration(
                    labelText: 'Mobile Number',
                    border: OutlineInputBorder(),
                  ),
                  validator: (val) => val == null || val.length != 10
                      ? 'Enter a valid 10-digit mobile number'
                      : null,
                ),
                const SizedBox(height: 16),
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
class ForgotPasswordScreen extends StatefulWidget {
  const ForgotPasswordScreen({super.key});

  @override
  State<ForgotPasswordScreen> createState() => _ForgotPasswordScreenState();
}

class _ForgotPasswordScreenState extends State<ForgotPasswordScreen> {
  final TextEditingController _mobileController = TextEditingController();
  bool otpSent = false;
  bool _obscureNewPass = true;
  final TextEditingController _otpController = TextEditingController();
  final TextEditingController _newPasswordController = TextEditingController();

  void _sendOtp() {
    if (_mobileController.text.length == 10) {
      setState(() => otpSent = true);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('OTP sent successfully to your mobile number!'),
        ),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please enter a valid 10-digit mobile number'),
        ),
      );
    }
  }

  void _resetPassword() {
    if (_otpController.text.length == 4 &&
        _newPasswordController.text.length >= 8) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Password reset successfully! Please sign in with your new credentials.',
          ),
        ),
      );
      Navigator.pop(context);
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Enter valid 4-digit OTP and secure password (min 8 chars).',
          ),
        ),
      );
    }
  }

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
              'Retrieve your account or reset password using your registered mobile number.',
              style: TextStyle(fontSize: 15, color: Colors.grey),
            ),
            const SizedBox(height: 20),
            TextField(
              controller: _mobileController,
              keyboardType: TextInputType.phone,
              maxLength: 10,
              decoration: const InputDecoration(
                labelText: 'Registered Mobile Number',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 10),
            if (!otpSent)
              ElevatedButton(onPressed: _sendOtp, child: const Text('Send OTP'))
            else ...[
              TextField(
                controller: _otpController,
                maxLength: 4,
                decoration: const InputDecoration(
                  labelText: 'Enter 4-digit OTP',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _newPasswordController,
                obscureText: _obscureNewPass,
                decoration: InputDecoration(
                  labelText: 'New Password',
                  border: const OutlineInputBorder(),
                  suffixIcon: IconButton(
                    icon: Icon(
                      _obscureNewPass ? Icons.visibility_off : Icons.visibility,
                    ),
                    onPressed: () =>
                        setState(() => _obscureNewPass = !_obscureNewPass),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              ElevatedButton(
                onPressed: _resetPassword,
                child: const Text('Update Password'),
              ),
            ],
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
  @override
  Widget build(BuildContext context) {
    final userComplaints = AppDatabase.complaints
        .where(
          (c) =>
              c.citizenEmail.trim().toLowerCase() ==
              widget.currentUser.email.trim().toLowerCase(),
        )
        .toList();

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
                      userEmail: widget.currentUser.email,
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
                  'Active Complaints',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              const SizedBox(width: 8),
              ElevatedButton.icon(
                onPressed: () async {
                  await Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => CreateComplaintScreen(
                        userEmail: widget.currentUser.email,
                        accessToken: widget.currentUser.accessToken,
                      ),
                    ),
                  );
                  setState(() {});
                },
                icon: const Icon(Icons.add, size: 16),
                label: const Text(
                  'New Complaint',
                  style: TextStyle(fontSize: 13),
                ),
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 10,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          userComplaints.isEmpty
              ? const Padding(
                  padding: EdgeInsets.only(top: 40),
                  child: Center(
                    child: Text(
                      'No complaints filed yet. Tap "New Complaint" to report an issue.',
                      style: TextStyle(color: Colors.grey),
                    ),
                  ),
                )
              : ListView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: userComplaints.length,
                  itemBuilder: (context, index) {
                    final complaint = userComplaints[index];
                    bool isAwaitingVerification =
                        complaint.status == 'Resolved / Awaiting Verification';

                    return Card(
                      margin: const EdgeInsets.only(bottom: 12),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Padding(
                        padding: const EdgeInsets.all(16.0),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text(
                                  complaint.id,
                                  style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    color: appTheme.primaryColor,
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
                                  backgroundColor: _getStatusColor(
                                    complaint.status,
                                  ),
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
                            Text(
                              complaint.description,
                              style: const TextStyle(color: Colors.white70),
                            ),
                            const SizedBox(height: 8),
                            Row(
                              children: [
                                const Icon(
                                  Icons.location_on,
                                  size: 14,
                                  color: Colors.grey,
                                ),
                                const SizedBox(width: 4),
                                Expanded(
                                  child: Text(
                                    complaint.location,
                                    style: const TextStyle(
                                      fontSize: 12,
                                      color: Colors.grey,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            if (complaint.completionNote != null) ...[
                              const Divider(height: 16),
                              Text(
                                'Worker Note: ${complaint.completionNote}',
                                style: const TextStyle(
                                  fontStyle: FontStyle.italic,
                                  fontSize: 13,
                                ),
                              ),
                            ],
                            if (isAwaitingVerification) ...[
                              const SizedBox(height: 12),
                              SizedBox(
                                width: double.infinity,
                                child: ElevatedButton.icon(
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: Colors.purple,
                                    foregroundColor: Colors.white,
                                  ),
                                  onPressed: () async {
                                    await Navigator.push(
                                      context,
                                      MaterialPageRoute(
                                        builder: (context) =>
                                            CitizenFeedbackReviewScreen(
                                              complaint: complaint,
                                            ),
                                      ),
                                    );
                                    setState(() {});
                                  },
                                  icon: const Icon(Icons.rate_review),
                                  label: const Text(
                                    'Review Work & Give Feedback',
                                  ),
                                ),
                              ),
                            ],
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
      default:
        return Colors.grey;
    }
  }
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
class PreviousComplaintsScreen extends StatelessWidget {
  final String userEmail;
  const PreviousComplaintsScreen({super.key, required this.userEmail});

  @override
  Widget build(BuildContext context) {
    final pastComplaints = AppDatabase.complaints
        .where(
          (c) =>
              c.citizenEmail.trim().toLowerCase() ==
              userEmail.trim().toLowerCase(),
        )
        .toList();

    return Scaffold(
      appBar: AppBar(title: const Text('Previous Records & Complaints')),
      body: pastComplaints.isEmpty
          ? const Center(child: Text('No previous complaints recorded.'))
          : ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: pastComplaints.length,
              itemBuilder: (context, index) {
                final c = pastComplaints[index];
                return Card(
                  margin: const EdgeInsets.only(bottom: 12),
                  child: Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'ID: ${c.id}',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            color: appTheme.primaryColor,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Category: ${c.category}',
                          style: const TextStyle(fontWeight: FontWeight.bold),
                        ),
                        Text('Status: ${c.status}'),
                        Text('Location: ${c.location}'),
                        if (c.completionNote != null) ...[
                          const SizedBox(height: 6),
                          Text(
                            'Resolution Note: ${c.completionNote}',
                            style: const TextStyle(fontStyle: FontStyle.italic),
                          ),
                        ],
                        if (c.citizenRating != null) ...[
                          const SizedBox(height: 4),
                          Row(
                            children: [
                              const Text(
                                'Rating Given: ',
                                style: TextStyle(fontWeight: FontWeight.bold),
                              ),
                              Text(
                                '${c.citizenRating} / 5 ⭐',
                                style: const TextStyle(color: Colors.amber),
                              ),
                            ],
                          ),
                        ],
                      ],
                    ),
                  ),
                );
              },
            ),
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
  String _category = 'Pothole & Road Damage';
  String _severity = 'Medium';
  final TextEditingController _descController = TextEditingController();
  final TextEditingController _locationController = TextEditingController();
  File? _imageFile;
  final ImagePicker _picker = ImagePicker();
  double? _latitude;
  double? _longitude;

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
          'SahaySetu requires access to your camera to capture live photographic evidence of infrastructure issues.',
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
    if (!_formKey.currentState!.validate()) return;

    if (_imageFile == null) {
      _showError('Live photo mandatory!');
      return;
    }

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

      final Complaint newComplaint = Complaint(
        id:
            result['complaint_id']?.toString() ??
            'SS-${1026 + AppDatabase.complaints.length}',
        category: _category,
        description: description,
        severity: _severity,
        location: _locationController.text.trim(),
        status: result['status']?.toString() ?? 'SUBMITTED',
        citizenEmail: widget.userEmail,
      );

      AppDatabase.complaints.add(newComplaint);

      Navigator.pushReplacement(
        context,
        MaterialPageRoute<void>(
          builder: (context) =>
              SubmissionFeedbackScreen(complaint: newComplaint),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      _showError('Complaint submission failed: $e');
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
                  labelText: 'Location / Landmark Address *',
                  border: const OutlineInputBorder(),
                  suffixIcon: IconButton(
                    icon: const Icon(Icons.my_location, color: Colors.blue),
                    onPressed: _promptGpsPermission,
                  ),
                ),
                validator: (val) => val == null || val.trim().isEmpty
                    ? 'Address mandatory'
                    : null,
              ),
              const SizedBox(height: 20),
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
                onPressed: _submit,
                child: const Text('Submit Complaint'),
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
              'Complaint Filed Successfully!',
              style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
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
  bool _obscureWorkerPass = true;
  final TextEditingController _usernameController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();

  void _loginWorker() {
    if (_formKey.currentState!.validate()) {
      String username = _usernameController.text.trim().toLowerCase();
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (context) => WorkerDashboardScreen(workerId: username),
        ),
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
                  labelText: 'Worker Username (e.g. rajesh@sahaysetu)',
                  border: OutlineInputBorder(),
                ),
                validator: (val) => val == null || !val.endsWith('@sahaysetu')
                    ? 'Must end with @sahaysetu'
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
  const WorkerDashboardScreen({super.key, required this.workerId});

  @override
  State<WorkerDashboardScreen> createState() => _WorkerDashboardScreenState();
}

class _WorkerDashboardScreenState extends State<WorkerDashboardScreen> {
  @override
  Widget build(BuildContext context) {
    final workerInfo = AppDatabase.workerProfiles.firstWhere(
      (w) => w.workerId.toLowerCase() == widget.workerId.toLowerCase(),
      orElse: () => WorkerProfile(
        workerId: widget.workerId,
        fullName: 'Field Worker',
        department: 'Pothole & Road Damage',
        wardZone: 'Municipal Ward',
        officialEmail: widget.workerId,
        mobile: '1800-MUN-HELP',
        designation: 'Municipal Field Staff',
        bonusPoints: 100,
      ),
    );

    final departmentComplaints = AppDatabase.complaints
        .where(
          (c) =>
              c.category.toLowerCase() == workerInfo.department.toLowerCase(),
        )
        .toList();

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
                '${workerInfo.fullName} (Bonus: ⭐ ${workerInfo.bonusPoints})',
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
              accountEmail: Text(
                '${workerInfo.designation}\n${workerInfo.department}',
              ),
              currentAccountPicture: const CircleAvatar(
                backgroundColor: Colors.white,
                child: Icon(
                  Icons.verified_user,
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
                        WorkerResolvedHistoryScreen(workerId: widget.workerId),
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
      body: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: departmentComplaints.length,
        itemBuilder: (context, index) {
          final complaint = departmentComplaints[index];
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
                    ),
                  ),
                );
                setState(() {});
              },
            ),
          );
        },
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
                  Positioned(
                    bottom: 0,
                    right: 0,
                    child: CircleAvatar(
                      backgroundColor: Colors.green,
                      radius: 14,
                      child: Icon(Icons.check, size: 16, color: Colors.white),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            const Text(
              'Government Verified Worker Profile',
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
              Icons.star,
              'Bonus Points Earned',
              '${worker.bonusPoints} pts',
            ),
            _buildWorkerCard(
              Icons.badge_outlined,
              'Official ID',
              worker.workerId,
            ),
            _buildWorkerCard(Icons.email, 'Govt Email', worker.officialEmail),
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
  const WorkerTaskDetailScreen({
    super.key,
    required this.complaint,
    required this.workerId,
  });

  @override
  State<WorkerTaskDetailScreen> createState() => _WorkerTaskDetailScreenState();
}

class _WorkerTaskDetailScreenState extends State<WorkerTaskDetailScreen> {
  File? _completionPhoto;
  final ImagePicker _picker = ImagePicker();
  double? _latitude;
  double? _longitude;

  final TextEditingController _noteController = TextEditingController();

  @override
  void initState() {
    super.initState();
    if (widget.complaint.completionNote != null) {
      _noteController.text = widget.complaint.completionNote!;
    }
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

  void _submitWorkCompletion() {
    if (_completionPhoto == null &&
        widget.complaint.completionPhotoPath == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Completion photo proof is required!'),
          backgroundColor: Colors.redAccent,
        ),
      );
      return;
    }

    setState(() {
      widget.complaint.status = 'Resolved / Awaiting Verification';
      widget.complaint.assignedWorker = widget.workerId;
      widget.complaint.completionNote = _noteController.text.trim();
      if (_completionPhoto != null) {
        widget.complaint.completionPhotoPath = _completionPhoto!.path;
      }
    });

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text(
          'Work submitted! Sent to citizen for review and verification.',
        ),
      ),
    );
    Navigator.pop(context);
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
                labelText: 'Resolution / Work Note *',
                hintText: 'Describe work completed...',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 20),
            const Text(
              'Completion Photo Proof *',
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
            ElevatedButton(
              onPressed: _submitWorkCompletion,
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF0F172A),
              ),
              child: const Text(
                'Submit for Citizen Verification',
                style: TextStyle(fontSize: 16),
              ),
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
class WorkerResolvedHistoryScreen extends StatelessWidget {
  final String workerId;
  const WorkerResolvedHistoryScreen({super.key, required this.workerId});

  @override
  Widget build(BuildContext context) {
    final resolvedTasks = AppDatabase.complaints
        .where(
          (c) =>
              c.assignedWorker == workerId &&
              (c.status.contains('Awaiting') || c.status == 'Closed'),
        )
        .toList();

    return Scaffold(
      appBar: AppBar(
        backgroundColor: const Color(0xFF0F172A),
        title: const Text('Resolved Complaints History'),
      ),
      body: resolvedTasks.isEmpty
          ? const Center(child: Text('No resolved tasks in your history yet.'))
          : ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: resolvedTasks.length,
              itemBuilder: (context, index) {
                final task = resolvedTasks[index];
                return Card(
                  margin: const EdgeInsets.only(bottom: 12),
                  child: Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          task.id,
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF0F172A),
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Category: ${task.category}',
                          style: const TextStyle(fontWeight: FontWeight.bold),
                        ),
                        Text('Location: ${task.location}'),
                        Text('Note: ${task.completionNote ?? "N/A"}'),
                        Text(
                          'Status: ${task.status}',
                          style: const TextStyle(
                            color: Colors.green,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        if (task.citizenRating != null) ...[
                          const SizedBox(height: 6),
                          Text(
                            'Citizen Rating: ${task.citizenRating} / 5 ⭐',
                            style: const TextStyle(
                              color: Colors.amber,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                );
              },
            ),
    );
  }
}
