import 'package:flutter/material.dart';
import '../../../../shared/widgets/app_button.dart';
import '../widgets/auth_textfield.dart';

class RegisterPage extends StatelessWidget {
  const RegisterPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        elevation: 0,
        backgroundColor: Colors.transparent,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.black),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            children: [
              const Text(
                "Register",
                style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 30),
              const AuthTextField(
                label: "First Name",
                hint: "",
              ),
              const SizedBox(height: 16),
              const AuthTextField(
                label: "Last Name",
                hint: "Enter your last name",
              ),
              const SizedBox(height: 16),
              const AuthTextField(
                label: "Email",
                hint: "Enter your email",
                keyboardType: TextInputType.emailAddress,
              ),
              const SizedBox(height: 16),
              const AuthTextField(
                label: "Password",
                hint: "Enter your password",
                isObscure: true,
              ),
              const SizedBox(height: 16),
              const AuthTextField(
                label: "Confirm Password",
                hint: "Confirm Password",
                isObscure: true,
              ),
              const SizedBox(height: 30),
              AppButton(
                text: "Submit", // Screenshot says "Summit", corrected to "Submit"
                onPressed: () {
                  // TODO: Call Register Logic
                },
              ),
              const SizedBox(height: 20),
              GestureDetector(
                onTap: () => Navigator.pop(context),
                child: const Text(
                  "Have an account ?",
                  style: TextStyle(
                    color: Color(0xFF9C27B0),
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              const SizedBox(height: 20),
            ],
          ),
        ),
      ),
    );
  }
}