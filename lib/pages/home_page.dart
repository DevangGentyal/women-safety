import 'dart:io';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import 'package:flutter_sound/flutter_sound.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:mailer/mailer.dart';
import 'package:mailer/smtp_server.dart';
import 'package:geolocator/geolocator.dart';
import 'package:intl/intl.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart'; // For formatting time

class EmailService {
  static Future<bool> sendEmergencyEmail(
      Map<String, dynamic> userData, String? audioFilePath) async {
    await dotenv.load(fileName: ".env");

    final String senderEmail = dotenv.env['GMAIL_ID'] ?? '';
    final String senderPassword = dotenv.env['GMAIL_PASS'] ?? '';
    final smtpServer = gmail(senderEmail, senderPassword);

    try {
      // Retrieve guardian emails from userData
      final List<dynamic> guardians = userData['trustedGuardians'] ?? [];
      final List<String> guardianEmails = guardians
          .map((guardian) => guardian['email'] as String)
          .where((email) => _isValidEmail(email))
          .toList();

      if (guardianEmails.isEmpty) {
        print("No valid guardian email addresses found.");
        return false;
      }

      // Fetch current location
      Position position = await Geolocator.getCurrentPosition(
          desiredAccuracy: LocationAccuracy.high);
      String location = "${position.latitude},${position.longitude}";

      // Get current time
      String currentTime = DateFormat('HH:mm:ss').format(DateTime.now());

      final message = Message()
        ..from = Address(senderEmail, "Emergency Alert")
        ..recipients.addAll(guardianEmails)
        ..subject = "🚨 Emergency Alert - Immediate Attention Needed!"
        ..text = """
Hello,

An emergency alert has been triggered. 

User Details:
Name: ${userData['name'] ?? "Unknown"}
Email: ${userData['email'] ?? "Not provided"}
Age: ${userData['age'] ?? "Not provided"}
Gender: ${userData['gender'] ?? "Not provided"}
Blood Group: ${userData['bloodGroup'] ?? "Not provided"}
Location: $location
Time: $currentTime

Please check on them immediately.

Regards,
Emergency Alert System
        """;

      if (audioFilePath != null && audioFilePath.isNotEmpty) {
        message.attachments.add(FileAttachment(File(audioFilePath))
          ..location = Location.attachment);
      }

      print("Attempting to send email to guardians...");
      final sendReport = await send(message, smtpServer);
      print("Email sent successfully to guardians: $sendReport");
      return true;
    } catch (e) {
      print("Error sending email: $e");
      return false;
    }
  }

  static bool _isValidEmail(String email) {
    final RegExp emailRegex =
        RegExp(r'^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}$');
    return emailRegex.hasMatch(email);
  }
}

class HomePage extends StatefulWidget {
  const HomePage({Key? key}) : super(key: key);

  @override
  _HomePageState createState() => _HomePageState();
}

class _HomePageState extends State<HomePage>
    with SingleTickerProviderStateMixin {
  final FlutterSoundRecorder _recorder = FlutterSoundRecorder();
  final FlutterSoundPlayer _player = FlutterSoundPlayer();
  bool _isRecording = false;
  String? _audioFilePath;
  bool _isEmailSending = false;
  late AnimationController _animationController;

  @override
  void initState() {
    super.initState();
    _initializeRecorder();
    _initializePlayer();
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 500),
      vsync: this,
    );
    _animationController.forward();
  }

  Future<void> _initializeRecorder() async {
    await _recorder.openRecorder();
    await _recorder.setSubscriptionDuration(const Duration(milliseconds: 500));
  }

  Future<void> _initializePlayer() async {
    await _player.openPlayer();
  }

  Future<void> _startRecording() async {
    if (await Permission.microphone.request().isGranted) {
      final directory = await getApplicationDocumentsDirectory();
      _audioFilePath = '${directory.path}/recorded_audio.aac';
      await _recorder.startRecorder(toFile: _audioFilePath);
      setState(() {
        _isRecording = true;
      });
    } else {
      print('Microphone permission denied');
    }
  }

  Future<void> _stopRecording() async {
    await _recorder.stopRecorder();
    setState(() {
      _isRecording = false;
    });
  }

  Future<Map<String, dynamic>> _getUserData() async {
    try {
      final directory = await getApplicationDocumentsDirectory();
      final registerFilePath = '${directory.path}/register_data.json';
      final aboutUserFilePath = '${directory.path}/about_user_data.json';
      final guardiansFilePath = '${directory.path}/guardians_data.json';

      final registerFile = File(registerFilePath);
      final aboutUserFile = File(aboutUserFilePath);
      final guardiansFile = File(guardiansFilePath);

      Map<String, dynamic> userData = {};

      if (await registerFile.exists()) {
        final registerContents = await registerFile.readAsString();
        userData.addAll(json.decode(registerContents));
      }

      if (await aboutUserFile.exists()) {
        final aboutUserContents = await aboutUserFile.readAsString();
        userData.addAll(json.decode(aboutUserContents));
      }

      if (await guardiansFile.exists()) {
        final guardiansContents = await guardiansFile.readAsString();
        userData.addAll(json.decode(guardiansContents));
      }

      return userData;
    } catch (e) {
      print('Error reading user data: $e');
      return {};
    }
  }

  void _showUserDataPopup(BuildContext context) async {
    setState(() {
      _isEmailSending = true;
    });

    final userData = await _getUserData();
    final emailSent =
        await EmailService.sendEmergencyEmail(userData, _audioFilePath);

    setState(() {
      _isEmailSending = false;
    });

    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: Text(emailSent ? 'Emergency Alert Sent' : 'Alert Failed'),
          content: Text(emailSent
              ? 'Your emergency alert email has been successfully sent to your trusted contacts.'
              : 'Failed to send the emergency email. Please check your internet connection and email settings.'),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: Text('OK'),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              const Color.fromARGB(181, 255, 255, 255),
              const Color.fromARGB(255, 254, 255, 246),
              Colors.purple[100]!
            ],
          ),
        ),
        child: SafeArea(
          child: Stack(
            children: [
              FutureBuilder<Map<String, dynamic>>(
                future: _getUserData(),
                builder: (context, snapshot) {
                  String userName = 'User';
                  if (snapshot.connectionState == ConnectionState.done) {
                    userName = snapshot.data?['name'] ?? 'User';
                  }
                  return Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _buildHeader(userName),
                        const SizedBox(height: 16),
                        _buildSafetyTip(),
                        const SizedBox(height: 32),
                        _buildSOSButton(context),
                        const SizedBox(height: 32),
                        _buildActionButtons(context),
                      ],
                    ),
                  );
                },
              ),
              if (_isEmailSending)
                Container(
                  color: Colors.black54,
                  child: const Center(
                    child: CircularProgressIndicator(),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHeader(String userName) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Hi $userName,',
          style: const TextStyle(
            fontSize: 24,
            fontWeight: FontWeight.bold,
            color: Colors.black87,
          ),
        ),
        const Text(
          'Stay Safe!',
          style: TextStyle(
            fontSize: 18,
            color: Colors.black54,
          ),
        ),
      ],
    );
  }

  Widget _buildSafetyTip() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.yellow[100],
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.yellow.withOpacity(0.3),
            spreadRadius: 5,
            blurRadius: 10,
          ),
        ],
      ),
      child: Row(
        children: [
          Icon(Icons.lightbulb_outline, color: Colors.orange[700]),
          const SizedBox(width: 12),
          Expanded(
            child: const Text(
              'Share your location with trusted contacts when traveling alone.',
              style: TextStyle(fontSize: 14, color: Colors.black87),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSOSButton(BuildContext context) {
    return Center(
      child: GestureDetector(
        onLongPressStart: (_) async {
          await _startRecording();
        },
        onLongPressEnd: (_) async {
          await _stopRecording();
          _showUserDataPopup(context);
        },
        child: Container(
          margin: EdgeInsets.only(bottom: 20),
          width: 140,
          height: 140,
          decoration: BoxDecoration(
            color: Colors.red,
            shape: BoxShape.circle,
            boxShadow: [
              BoxShadow(
                color: Colors.red.withOpacity(0.3),
                spreadRadius: 5,
                blurRadius: 10,
              ),
            ],
          ),
          child: const Center(
            child: Text(
              'SOS',
              style: TextStyle(
                color: Colors.white,
                fontSize: 28,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildActionButtons(BuildContext context) {
    return Column(
      children: [
        _buildAnimatedActionButton(
          icon: Icons.shield,
          title: 'Nearest Safe Zone',
          color: Colors.blue,
          onTap: () {
            Navigator.pushNamed(context, '/safeZones');
          },
        ),
        const SizedBox(height: 20),
        _buildAnimatedActionButton(
          icon: Icons.map,
          title: 'WayFinder',
          color: Colors.blue,
          onTap: () {
            Navigator.pushNamed(context, '/kidsNavi');
          },
        ),
        const SizedBox(height: 20),
        _buildAnimatedActionButton(
          icon: Icons.warning,
          title: 'Risky Zones',
          color: Colors.red,
          onTap: () {
            Navigator.pushNamed(context, '/dangerZones');
          },
        ),
      ],
    );
  }

  Widget _buildAnimatedActionButton({
    required IconData icon,
    required String title,
    required Color color,
    VoidCallback? onTap,
  }) {
    return SlideTransition(
      position: Tween<Offset>(
        begin: const Offset(-1, 0),
        end: Offset.zero,
      ).animate(CurvedAnimation(
        parent: _animationController,
        curve: Curves.easeInOut,
      )),
      child: GestureDetector(
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 500),
          width: double.infinity,
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.9),
            borderRadius: BorderRadius.circular(12),
            boxShadow: [
              BoxShadow(
                color: Colors.grey.withOpacity(0.3),
                spreadRadius: 3,
                blurRadius: 10,
                offset: Offset(0, 3),
              ),
            ],
          ),
          child: Row(
            children: [
              Icon(icon, color: color, size: 40),
              const SizedBox(width: 16),
              Expanded(
                child: Text(
                  title,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
              const Icon(Icons.arrow_forward_ios, size: 16, color: Colors.grey),
            ],
          ),
        ),
      ),
    );
  }

  @override
  void dispose() {
    _recorder.closeRecorder();
    _player.closePlayer();
    _animationController.dispose();
    super.dispose();
  }
}
