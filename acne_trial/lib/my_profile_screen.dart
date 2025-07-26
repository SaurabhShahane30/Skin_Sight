import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:country_picker/country_picker.dart';

class MyProfileScreen extends StatefulWidget {
  const MyProfileScreen({super.key});

  @override
  State<MyProfileScreen> createState() => _MyProfileScreenState();
}

class _MyProfileScreenState extends State<MyProfileScreen> {
  final supabase = Supabase.instance.client;
  final _formKey = GlobalKey<FormState>();

  Map<String, dynamic> profile = {};
  bool isLoading = true;
  String? profilePictureUrl;


  final TextEditingController nameController = TextEditingController();
  final TextEditingController ageController = TextEditingController();
  final TextEditingController genderController = TextEditingController();
  final TextEditingController phoneController = TextEditingController();
  final TextEditingController skinTypeController = TextEditingController();
  final TextEditingController concernsController = TextEditingController();

  final List<String> genderOptions = ['Male', 'Female', 'Other', 'Prefer not to say'];
  final List<String> skinTypes = ['Normal', 'Oily', 'Dry', 'Combination', 'Sensitive'];
  final List<String> concerns = ['acne', 'wrinkle', 'dark spots', 'moisture'];
  final List<String> ageOptions = List.generate(91, (index) => (10 + index).toString());

  Country selectedCountry = Country(
    phoneCode: '91',
    countryCode: 'IN',
    e164Sc: 0,
    geographic: true,
    level: 1,
    name: 'India',
    example: '9123456789',
    displayName: 'India',
    displayNameNoCountryCode: 'India',
    e164Key: '',
  );

  @override
  void initState() {
    super.initState();
    fetchProfile();
  }

  Future<void> fetchProfile() async {
    final user = supabase.auth.currentUser;
    if (user == null) return;

    try {
      final response = await supabase
          .from('profiles')
          .select()
          .eq('id', user.id)
          .maybeSingle(); // ⚠️ maybeSingle to allow null if no row exists

      setState(() {
        // Use profile if it exists
        profile = response ?? {};

        // Fallbacks
        nameController.text = profile['name'] ??
            user.userMetadata?['full_name'] ??
            'User';

        ageController.text = profile['age']?.toString() ?? '';
        genderController.text = profile['gender'] ?? '';
        phoneController.text = profile['phone'] ?? '';
        skinTypeController.text = profile['skin_type'] ?? '';
        concernsController.text = profile['primary_concerns'] ?? '';

        // Load avatar URL (optional: can be used in your UI elsewhere)
        profilePictureUrl = profile['photo_url'] ?? user.userMetadata?['avatar_url'];

        isLoading = false;
      });
    } catch (e) {
      debugPrint('Error fetching profile: $e');
      setState(() {
        isLoading = false;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to load profile: $e')),
      );
    }
  }



  Future<void> updateProfile() async {
    final user = supabase.auth.currentUser;
    if (user == null) return;

    await supabase.from('profiles').upsert({
      'id': user.id,
      'name': nameController.text.trim(),
      'age': int.tryParse(ageController.text.trim()),
      'gender': genderController.text.trim(),
      'phone': phoneController.text.trim(),
      'skin_type': skinTypeController.text.trim(),
      'primary_concerns': concernsController.text.trim(),
    });

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Profile updated')),
    );
  }

  void _confirmLogout() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Confirm Logout'),
        content: const Text('Are you sure you want to log out?'),
        actions: [
          TextButton(child: const Text('Cancel'), onPressed: () => Navigator.pop(context, false)),
          TextButton(child: const Text('Logout'), onPressed: () => Navigator.pop(context, true)),
        ],
      ),
    );

    if (confirm == true) {
      await supabase.auth.signOut();
      if (mounted) {
        Navigator.pushReplacementNamed(context, '/login');
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = supabase.auth.currentUser;

    return Scaffold(
      backgroundColor: const Color(0xFFFFF3DA),
      body: isLoading
          ? const Center(child: CircularProgressIndicator())
          : SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Form(
            key: _formKey,
            child: Column(
              children: [
                // Centered Profile Picture & Name
                Column(
                  children: [
                    CircleAvatar(
                      radius: 65,
                      backgroundColor: Colors.pink.shade200,
                      backgroundImage: (profilePictureUrl != null && profilePictureUrl!.isNotEmpty)
                          ? NetworkImage(profilePictureUrl!)
                          : null,
                      child: (profilePictureUrl == null || profilePictureUrl!.isEmpty)
                          ? const Icon(Icons.person, size: 60, color: Colors.white)
                          : null,
                    ),

                    const SizedBox(height: 14),
                    Text(
                      nameController.text = (profile['name'] != null && profile['name'].toString().isNotEmpty)
                          ? profile['name']
                          : (user?.userMetadata?['full_name'] ?? 'User'),

                      style: const TextStyle(
                        fontSize: 26,
                        fontWeight: FontWeight.bold,
                        color: Colors.pink,
                      ),
                    ),

                  ],
                ),
                const SizedBox(height: 30),

                profileCard(
                  title: 'User Info',
                  children: [
                    formField('Name', nameController),
                    Row(
                      children: [
                        Expanded(child: dropdownField('Age', ageController, ageOptions)),
                        const SizedBox(width: 10),
                        Expanded(child: dropdownField('Gender', genderController, genderOptions)),
                      ],
                    ),
                    phoneField(),
                    const SizedBox(height: 10),
                    const Text("Mail ID", style: TextStyle(color: Colors.grey)),
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            user?.email ?? '',
                            style: const TextStyle(fontWeight: FontWeight.bold),
                          ),
                        ),
                        const Icon(Icons.lock_outline, size: 16, color: Colors.grey),
                      ],
                    ),
                  ],
                ),

                profileCard(
                  title: 'Skin Details',
                  children: [
                    dropdownField('Skin Type', skinTypeController, skinTypes),
                    dropdownField('Primary Concerns', concernsController, concerns),
                  ],
                ),

                const SizedBox(height: 20),

                Material(
                  color: Colors.transparent,
                  child: InkWell(
                    borderRadius: BorderRadius.circular(30),
                    onTap: updateProfile,
                    child: Container(
                      width: 250,
                      height: 48,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(30),
                        gradient: const LinearGradient(
                          colors: [Color(0xFFB56CC0), Color(0xFFE1709A)],
                          begin: Alignment.centerLeft,
                          end: Alignment.centerRight,
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.15),
                            offset: const Offset(0, 4),
                            blurRadius: 8,
                          ),
                        ],
                      ),
                      child: Center(
                        child:Text(
                          'Save Changes',
                          style: TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 30),

                // Logout Button
                TextButton.icon(
                  icon: const Icon(Icons.logout, color: Colors.red),
                  label: const Text("Logout", style: TextStyle(color: Colors.red)),
                  onPressed: _confirmLogout,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget profileCard({required String title, required List<Widget> children}) {
    return Container(
      padding: const EdgeInsets.all(16),
      margin: const EdgeInsets.only(bottom: 20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.pink.shade100),
        boxShadow: const [BoxShadow(color: Colors.black12, blurRadius: 4)],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Center(
            child: Text(
              title,
              style: const TextStyle(
                fontWeight: FontWeight.bold,
                color: Colors.pink,
                fontSize: 16,
              ),
            ),
          ),
          const SizedBox(height: 20),
          ...children,
        ],
      ),
    );
  }

  Widget formField(String label, TextEditingController controller) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: const TextStyle(color: Colors.grey)),
          TextFormField(
            controller: controller,
            decoration: const InputDecoration(
              isDense: true,
              contentPadding: EdgeInsets.symmetric(vertical: 6),
              border: UnderlineInputBorder(),
            ),
          ),
        ],
      ),
    );
  }

  Widget dropdownField(String label, TextEditingController controller, List<String> items) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: const TextStyle(color: Colors.grey)),
          DropdownButtonFormField<String>(
            value: items.contains(controller.text) ? controller.text : null,
            items: items.map((item) {
              return DropdownMenuItem(value: item, child: Text(item));
            }).toList(),
            onChanged: (val) {
              setState(() {
                controller.text = val!;
              });
            },
            decoration: const InputDecoration(
              isDense: true,
              contentPadding: EdgeInsets.symmetric(vertical: 6),
              border: UnderlineInputBorder(),
            ),
          ),
        ],
      ),
    );
  }

  Widget phoneField() {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text("Mobile", style: TextStyle(color: Colors.grey)),
          Row(
            children: [
              GestureDetector(
                onTap: () {
                  showCountryPicker(
                    context: context,
                    showPhoneCode: true,
                    onSelect: (Country country) {
                      setState(() {
                        selectedCountry = country;
                      });
                    },
                  );
                },
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 12),
                  decoration: BoxDecoration(
                    border: Border(bottom: BorderSide(color: Colors.grey.shade400)),
                  ),
                  child: Text("+${selectedCountry.phoneCode}"),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: TextFormField(
                  controller: phoneController,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(
                    isDense: true,
                    contentPadding: EdgeInsets.symmetric(vertical: 6),
                    border: UnderlineInputBorder(),
                    hintText: "Phone number",
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
