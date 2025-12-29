import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:repo_agent_application/utils/my_colors.dart';

import '../../data/prefernces.dart';
import '../../helpers/device_utils.dart';
import '../../services/end_points.dart';
import '../../services/repository.dart';
import '../../utils/config.dart';
import '../../utils/util_class.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final TextEditingController emailController = TextEditingController();
  final TextEditingController passwordController = TextEditingController();


  bool _isLoggingIn = false;


  String? emailError;
  String? passwordError;

  bool obscurePass = true;

  @override
  void initState() {
    super.initState();

  }




  // Email / Mobile Validation
  bool isValidEmailOrMobile(String input) {
    final emailReg = RegExp(r'^[\w\.-]+@[\w\.-]+\.\w+$');
    final mobileReg = RegExp(r'^[0-9]{10}$');
    return emailReg.hasMatch(input) || mobileReg.hasMatch(input);
  }

  // Password Validation
  bool isValidPassword(String input) {
    return input.length >= 6;
  }

  void validateEmail(String value) {
    if (value.isEmpty) {
      emailError = "Please enter email or mobile number";
    } else if (!isValidEmailOrMobile(value)) {
      emailError = "Enter valid email or 10-digit mobile";
    } else {
      emailError = null;
    }
    setState(() {});
  }

  void validatePassword(String value) {
    if (value.isEmpty) {
      passwordError = "Please enter password";
    } else if (!isValidPassword(value)) {
      passwordError = "Password must be at least 6 characters";
    } else {
      passwordError = null;
    }
    setState(() {});
  }


  Future<void> callLoginAPI() async {
    if (_isLoggingIn) return; // 🔒 block double tap

    final password = passwordController.text.trim();
    final email = emailController.text.trim();

    setState(() {
      _isLoggingIn = true;
    });

    final internet = await UtilClass.checkInternet();
    final deviceId = await Preferences.getDeviceId();

    if (!internet) {
      setState(() {
        _isLoggingIn = false;
      });
      UtilClass.showAlertDialog(
        context: context,
        message: Config.kNoInternet,
      );
      return;
    }

    print("LoginBody${email} ${password} ${deviceId}");
    try {
      final value = await Repository.postApiRawService(
        EndPoints.loginApi,
        {
          "email": email,
          "password": password,
          "device_token": deviceId,
        },
      );

      print("lgRes $value");
      // Handle different response formats
      dynamic parsed;
      if (value is String) {
        parsed = json.decode(value);
      } else {
        parsed = value;
      }

      if (parsed["status"] == true) {
        final fullDataJson = jsonEncode(parsed["data"]);
        await Preferences.setUserDetails(fullDataJson);

        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text("Login Successfully!"),
            backgroundColor: Colors.green,
            duration: Duration(seconds: 2),
          ),
        );

        await Future.delayed(const Duration(seconds: 2));

        if (!mounted) return;
        Navigator.pushNamed(context, Config.homeRegRouteName);
      } else {
        //message:"Login failed.Try again",
        // message: value["message"] ?? "Login failed",
        UtilClass.showAlertDialog(
          context: context,
          message: value["message"] ?? "Login failed",
        );
      }
    } catch (e) {
      UtilClass.showAlertDialog(
        context: context,
        message: e.toString(),
      );
    } finally {
      if (mounted) {
        setState(() {
          _isLoggingIn = false; // 🔓 unlock button
        });
      }
    }
  }


  // void handleLogin() {
  //   validateEmail(emailController.text.trim());
  //   validatePassword(passwordController.text.trim());
  //
  //   if (emailError == null && passwordError == null) {
  //     // All validations passed — proceed with API call or navigation
  //     print("Login block");
  //     callLoginAPI();
  //     // Navigator.pushNamed(
  //     //   context,
  //     //   Config. homeRegRouteName, // Navigate to the OnBoardScreen sk//onBoardRouteName
  //     // );
  //   }else{
  //     print("Login not block");
  //   }
  // }

  void handleLogin() {
    validateEmail(emailController.text.trim());
    validatePassword(passwordController.text.trim());

    if (emailError == null && passwordError == null) {
      if (!_isLoggingIn) {
        callLoginAPI();
      }
    }
  }


  @override
  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    final h = size.height;
    final w = size.width;

    bool desktop = w >= 1024;

    double cardWidth = desktop ? 420 : w * 0.9;
    double titleSize = desktop ? 28 : 22;
    double subTitleSize = desktop ? 14 : 13;
    double buttonHeight = desktop ? 50 : h * 0.065;

    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [
              MyColors.appThemeDark,
              MyColors.appThemeLight1,
            ],
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
          ),
        ),
        child: Center(
          child: SingleChildScrollView(
            child: Container(
              width: cardWidth,
              padding: const EdgeInsets.symmetric(
                horizontal: 24,
                vertical: 32,
              ),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(26),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.15),
                    blurRadius: 20,
                    offset: const Offset(0, 6),
                  ),
                ],
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    "REPO MASTER",
                    style: TextStyle(
                      fontSize: titleSize,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    "Sign in to start your session",
                    style: TextStyle(
                      fontSize: subTitleSize,
                      color: Colors.grey.shade600,
                    ),
                  ),

                  const SizedBox(height: 30),

                  // Email
                  _inputBox(
                    controller: emailController,
                    hint: "Email / Mobile Number",
                    icon: Icons.email_outlined,
                    onChanged: validateEmail,
                  ),
                  if (emailError != null) _errorText(emailError!),

                  const SizedBox(height: 16),

                  // Password
                  _inputBox(
                    controller: passwordController,
                    hint: "Password",
                    obscure: obscurePass,
                    suffix: IconButton(
                      icon: Icon(
                        obscurePass
                            ? Icons.visibility_off_outlined
                            : Icons.visibility_outlined,
                      ),
                      onPressed: () {
                        setState(() => obscurePass = !obscurePass);
                      },
                    ),
                    onChanged: validatePassword,
                  ),
                  if (passwordError != null) _errorText(passwordError!),

                  const SizedBox(height: 30),

                  SizedBox(
                    width: double.infinity,
                    height: buttonHeight,
                    child: DecoratedBox(
                      decoration: const BoxDecoration(
                        gradient: LinearGradient(
                          colors: [
                            MyColors.appThemeDark,
                            MyColors.appThemeLight1,
                          ],
                        ),
                        borderRadius: BorderRadius.all(Radius.circular(22)),
                      ),
                      child: ElevatedButton(
                        onPressed: _isLoggingIn ? null : handleLogin,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.transparent, // 👈 IMPORTANT
                          shadowColor: Colors.transparent,     // 👈 IMPORTANT
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(22),
                          ),
                        ),
                        child: _isLoggingIn
                            ? const SizedBox(
                          width: 22,
                          height: 22,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                            : const Text(
                          "Sign In",
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        ),
                      ),
                    ),
                  ),

                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _inputBox({
    required TextEditingController controller,
    required String hint,
    bool obscure = false,
    Widget? suffix,
    required Function(String) onChanged,
    IconData? icon,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      decoration: BoxDecoration(
        color: Colors.grey.shade200,
        borderRadius: BorderRadius.circular(14),
      ),
      child: TextField(
        controller: controller,
        obscureText: obscure,
        onChanged: onChanged,
        decoration: InputDecoration(
          border: InputBorder.none,
          hintText: hint,
          suffixIcon: suffix ?? (icon != null ? Icon(icon) : null),
        ),
      ),
    );
  }

  Widget _errorText(String msg) {
    return Padding(
      padding: const EdgeInsets.only(top: 6),
      child: Align(
        alignment: Alignment.centerLeft,
        child: Text(
          msg,
          style: const TextStyle(color: Colors.red, fontSize: 12),
        ),
      ),
    );
  }


}
