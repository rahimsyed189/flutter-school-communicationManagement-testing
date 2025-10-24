import 'package:flutter/material.dart';
import 'school_registration_wizard_page.dart';

/// Page for configuring a new Firebase project (dedicated database)
/// Navigates to the existing Firebase configuration wizard
class SchoolRegistrationFirebaseConfig extends StatelessWidget {
  const SchoolRegistrationFirebaseConfig({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    // Navigate to existing wizard immediately
    WidgetsBinding.instance.addPostFrameCallback((_) {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (context) => const SchoolRegistrationWizardPage(),
        ),
      );
    });

    return const Scaffold(
      body: Center(
        child: CircularProgressIndicator(),
      ),
    );
  }
}
