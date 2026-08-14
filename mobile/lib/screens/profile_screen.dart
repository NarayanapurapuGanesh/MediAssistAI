import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/auth_provider.dart';
import '../services/api_service.dart';
import '../providers/theme_provider.dart';
import 'routine_screen.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  final _ageController = TextEditingController();
  final _heightController = TextEditingController();
  final _weightController = TextEditingController();
  final ApiService _apiService = ApiService();
  bool _isLoading = false;
  String? _selectedGender;

  @override
  void initState() {
    super.initState();
    final user = Provider.of<AuthProvider>(context, listen: false).user;
    if (user != null) {
      _nameController.text = user.name ?? '';
      _emailController.text = user.email;
      if (user.age != null) _ageController.text = user.age.toString();
      if (user.height != null) _heightController.text = user.height.toString();
      if (user.weight != null) _weightController.text = user.weight.toString();
      _selectedGender = user.gender;
    }
  }

  void _submit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _isLoading = true);

    try {
      final data = <String, dynamic>{
        'name': _nameController.text,
        'email': _emailController.text,
      };
      if (_ageController.text.isNotEmpty) data['age'] = int.parse(_ageController.text);
      if (_selectedGender != null) data['gender'] = _selectedGender;
      if (_heightController.text.isNotEmpty) data['height'] = double.parse(_heightController.text);
      if (_weightController.text.isNotEmpty) data['weight'] = double.parse(_weightController.text);

      final success = await _apiService.updateProfile(data);
      if (success && mounted) {
        await Provider.of<AuthProvider>(context, listen: false).checkAuth();
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Profile updated!'), backgroundColor: Color(0xFF10B981)),
          );
          Navigator.pop(context);
        }
      } else if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Failed to update profile.')));
      }
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Network error.')));
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Provider.of<ThemeProvider>(context).isDarkMode;
    final bgColor = isDark ? const Color(0xFF0F172A) : const Color(0xFFF1F5F9);
    final textColor = isDark ? Colors.white : const Color(0xFF1E293B);
    final subTextColor = isDark ? Colors.grey.shade400 : Colors.grey.shade600;
    final cardColor = isDark ? const Color(0xFF1E293B).withValues(alpha: 0.6) : Colors.white.withValues(alpha: 0.9);

    return Scaffold(
      backgroundColor: bgColor,
      appBar: AppBar(
        title: Text('Profile', style: TextStyle(color: textColor, fontWeight: FontWeight.bold)),
        backgroundColor: Colors.transparent,
        elevation: 0,
        iconTheme: IconThemeData(color: textColor),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24.0),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              CircleAvatar(
                radius: 50,
                backgroundColor: const Color(0xFF6366F1).withValues(alpha: 0.2),
                child: const Icon(Icons.person, size: 60, color: Color(0xFF6366F1)),
              ),
              const SizedBox(height: 32),

              _buildField(_nameController, 'Full Name', Icons.badge, textColor),
              const SizedBox(height: 16),
              _buildField(_emailController, 'Email Address', Icons.email, textColor),
              const SizedBox(height: 16),

              // Age + Gender row
              Row(children: [
                Expanded(child: _buildField(_ageController, 'Age', Icons.cake, textColor, isNumber: true)),
                const SizedBox(width: 16),
                Expanded(
                  child: DropdownButtonFormField<String>(
                    initialValue: _selectedGender,
                    dropdownColor: isDark ? const Color(0xFF1E293B) : Colors.white,
                    style: TextStyle(color: textColor),
                    decoration: InputDecoration(
                      labelText: 'Gender',
                      labelStyle: TextStyle(color: Colors.grey.shade500),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                      prefixIcon: const Icon(Icons.people),
                    ),
                    items: ['Male', 'Female', 'Other'].map((g) =>
                      DropdownMenuItem(value: g, child: Text(g, style: TextStyle(color: textColor)))).toList(),
                    onChanged: (val) => setState(() => _selectedGender = val),
                  ),
                ),
              ]),
              const SizedBox(height: 16),

              // Height + Weight row
              Row(children: [
                Expanded(child: _buildField(_heightController, 'Height (cm)', Icons.height, textColor, isNumber: true)),
                const SizedBox(width: 16),
                Expanded(child: _buildField(_weightController, 'Weight (kg)', Icons.fitness_center, textColor, isNumber: true)),
              ]),
              const SizedBox(height: 32),

              ElevatedButton(
                onPressed: _isLoading ? null : _submit,
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  backgroundColor: const Color(0xFF6366F1),
                  foregroundColor: Colors.white,
                ),
                child: _isLoading
                    ? const CircularProgressIndicator(color: Colors.white)
                    : const Text('Save Profile', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
              ),

              const SizedBox(height: 24),

              // Daily Routine link
              ListTile(
                leading: Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: const Color(0xFF10B981).withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(Icons.schedule, color: Color(0xFF10B981)),
                ),
                title: Text('Daily Routine', style: TextStyle(color: textColor, fontWeight: FontWeight.w500)),
                subtitle: Text('Configure wake, meals & sleep times', style: TextStyle(color: subTextColor, fontSize: 12)),
                trailing: Icon(Icons.chevron_right, color: subTextColor),
                onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const RoutineScreen())),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                tileColor: cardColor,
              ),

              const SizedBox(height: 40),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildField(TextEditingController controller, String label, IconData icon, Color textColor, {bool isNumber = false}) {
    return TextFormField(
      controller: controller,
      style: TextStyle(color: textColor),
      keyboardType: isNumber ? const TextInputType.numberWithOptions(decimal: true) : TextInputType.text,
      decoration: InputDecoration(
        labelText: label,
        labelStyle: TextStyle(color: Colors.grey.shade500),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
        prefixIcon: Icon(icon),
      ),
      validator: label.contains('Name') || label.contains('Email')
          ? (val) => val == null || val.isEmpty ? 'Required' : null
          : null,
    );
  }
}
