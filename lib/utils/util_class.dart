// ignore_for_file: unnecessary_null_comparison, avoid_print

import 'dart:developer';
import 'dart:io';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:dio/dio.dart';
// import 'package:flutter/cupertino.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_svprogresshud/flutter_svprogresshud.dart';

import 'package:hexcolor/hexcolor.dart';

import 'config.dart';
import 'my_colors.dart';

class UtilClass {
  static Widget getSizedBox(var valueHeight, valueWidth) {
    return SizedBox(height: valueHeight, width: valueWidth);
  }

  static writeLog({
    required Response<dynamic> response,
    required FormData? formValues,
  }) {
    if (kDebugMode) {
      if (formValues != null) {
        log(
          "\n"
          'Response:  ${response.data}',
          name: response.realUri.toString(),
        );
        log("parameteres${formValues.fields}");
      } else {
        log(
          "\n"
          'Response:  ${response.data}',
          name: response.realUri.toString(),
        );
      }
    }
  }


  static Future SuccessfulDialog({
    required BuildContext context,
    required String msg,
    required String buttonTitle,
    required Function()? onOk,
  }) {
    return showDialog(
      barrierDismissible: false,
      context: context,
      builder: (BuildContext context) {
        double width = MediaQuery.of(context).size.width * 0.7;
        double height = MediaQuery.of(context).size.height * 0.32;
        return AlertDialog(
          backgroundColor: Colors.white,
          shape: const RoundedRectangleBorder(
            borderRadius: BorderRadius.all(Radius.circular(18.0)),
          ),
          contentPadding: EdgeInsets.zero,
          content: Container(
            width: width,
            height: height,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              mainAxisAlignment: MainAxisAlignment.center,
              children: <Widget>[
                // Dual Circle Green Tick
                Stack(
                  alignment: Alignment.center,
                  children: [
                    Container(
                      width: width * 0.34,
                      height: width * 0.34,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: Colors.green.withOpacity(0.34),
                      ),
                    ),
                    Container(
                      width: width * 0.26,
                      height: width * 0.26,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: MyColors.appThemeLight.withOpacity(0.56),
                      ),
                    ),
                    Icon(
                      Icons.check,
                      color: Colors.white,
                      size: width * 0.14,
                    ),
                  ],
                ),
                SizedBox(height: height * 0.07),
                Text(
                  msg,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontWeight: FontWeight.w600,
                    color: Colors.black87,
                    fontSize: width * 0.06,
                  ),
                ),
                SizedBox(height: height * 0.10),
                SizedBox(
                  width: width * 0.74,
                  height: height * 0.22,
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: MyColors.appThemeLight,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                      elevation: 0,
                    ),
                    onPressed: () async {
                      if (onOk != null) {
                        await onOk();
                      }
                      Navigator.of(context).pop();
                    },
                    child: Text(
                      buttonTitle,
                      style: TextStyle(
                        fontWeight: FontWeight.w600,
                        fontSize: width * 0.068,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  //below method check only internet not wifi
  // static Future<bool> checkInternet() async {
  //   final Connectivity connectivity = Connectivity();
  //   List<ConnectivityResult> result;
  //   try {
  //     result = await connectivity.checkConnectivity();
  //     return true;
  //   } on PlatformException {
  //     return false;
  //   }
  // }

  //Check both  (WiFi + Internet)
  static Future<bool> checkInternet() async {
    final connectivity = Connectivity();
    final result = await connectivity.checkConnectivity();

    if (result == ConnectivityResult.none) return false;

    try {
      final lookup = await InternetAddress.lookup('google.com');
      return lookup.isNotEmpty;
    } catch (_) {
      return false;
    }
  }



  static showProgress({required BuildContext context}) {
    if (Platform.isAndroid || Platform.isIOS) {
      SVProgressHUD.setDefaultMaskType(SVProgressHUDMaskType.black);
      SVProgressHUD.show(status: Config.pleaseWait);
    } else {
      // Optional: log for desktop
      if (kDebugMode) {
        debugPrint('Progress HUD skipped (Desktop platform)');
      }
    }
  }


  static hideProgress({BuildContext? context}) {
    if (Platform.isAndroid || Platform.isIOS) {
      SVProgressHUD.dismiss();
    } else {
      // Optional: log for desktop
      if (kDebugMode) {
        debugPrint('Progress HUD dismiss skipped (Desktop platform)');
      }
    }
  }


  static showAlertDialog({
    required BuildContext context,
    required String? message,
    Function()? onOkClick,
  }) {
    UtilClass.hideProgress(context: context);
    Dialog alertDialog = Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12.0)),
      backgroundColor: Colors.white,
      child: SizedBox(
        width: 300,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 10),
              decoration: BoxDecoration(
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(12.0),
                  topRight: Radius.circular(12.0),
                ),
                color: MyColors.appThemeDark,
              ),
              alignment: Alignment.center,
              child: Text(
                Config.appName,
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 16.0,
                  color: Colors.white,
                  fontFamily: Config.fontFamilyPoppinsBold,
                ),
              ),
            ),
            Container(
              width: double.infinity,
              margin: const EdgeInsets.symmetric(horizontal: 10, vertical: 20),
              alignment: Alignment.center,
              child: Text(
                message ?? 'empty message',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 16.0,
                  color: HexColor(MyColors.colorBlack),
                  fontFamily: Config.fontFamilyPoppinsMedium,
                ),
              ),
            ),
            TextButton(
              onPressed: () async {
                Navigator.of(context).pop();
                if (onOkClick != null) {
                  await onOkClick();
                }
              },
              child: Container(
                width: double.infinity,
                alignment: Alignment.center,
                child: Text(
                  'OK',
                  style: TextStyle(
                    color: HexColor(MyColors.darkIndigo),
                    fontSize: 18.0,
                    fontFamily: Config.fontFamilyPoppinsBold,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return WillPopScope(
          child: alertDialog,
          onWillPop: () async {
            return false;
          },
        );
      },
      barrierDismissible: false,
    );
  }

  static Future dialogueWithProceedCancelButton({
    required BuildContext context,
    required String title,
    required String msg,
    required String positiveBtnTitle,
    required String negativeBtnTitle,
    required Function()? onCancel,
    required Function()? onProceed,
  }) {
    return showDialog(
      barrierDismissible: false,
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          backgroundColor: Colors.white,
          shape: const RoundedRectangleBorder(
            borderRadius: BorderRadius.all(Radius.circular(15.0)),
          ),
          contentPadding: const EdgeInsets.only(top: 10.0),
          content: Column(
            mainAxisAlignment: MainAxisAlignment.start,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                mainAxisSize: MainAxisSize.min,
                children: <Widget>[
                  Text(
                    title.isNotEmpty ? title : Config.appName,
                    style: TextStyle(
                      fontSize: 24.0,
                      color: HexColor(MyColors.colorBlack),
                      fontFamily: Config.fontFamilyPoppinsBold,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 5.0),
              const Divider(color: Colors.grey, height: 4.0),
              const SizedBox(height: 15.0),
              Expanded(
                flex: 0,
                child: Padding(
                  padding: const EdgeInsets.only(left: 30.0, right: 30.0),
                  child: Text(
                    msg,
                    style: TextStyle(
                      fontSize: 16.0,
                      color: HexColor(MyColors.colorBlack),
                      fontFamily: Config.fontFamilyPoppinsMedium,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ),
              ),
              const SizedBox(height: 15.0),
              Padding(
                padding: const EdgeInsets.only(
                  left: 30.0,
                  right: 30.0,
                  top: 10,
                  bottom: 10,
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: <Widget>[
                    TextButton(
                      onPressed: () async {
                        if (onCancel != null) {
                          await onCancel();
                        }
                        Navigator.of(context).pop();
                      },
                      child: Text(
                        negativeBtnTitle.isNotEmpty
                            ? negativeBtnTitle
                            : Config.cancel,
                        style: TextStyle(
                          fontSize: 16.0,
                          color: Colors.grey,
                          fontFamily: Config.fontFamilyPoppinsBold,
                        ),
                      ),
                    ),
                    TextButton(
                      onPressed: () async {
                        if (onProceed != null) {
                          await onProceed();
                        }
                        Navigator.of(context).pop();
                      },
                      child: Text(
                        positiveBtnTitle.isNotEmpty
                            ? positiveBtnTitle
                            : Config.submit,
                        style: TextStyle(
                          fontSize: 16.0,
                          color: HexColor(MyColors.darkIndigo),
                          fontFamily: Config.fontFamilyPoppinsBold,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  static bool isCheckPass(String value) {
    String passwordRegExp =
        r'^.*(?=.{8,})(?=.*\d)(?=.*[a-z])(?=.*[a-z])(^[a-zA-Z0-9@\$=!:.#%]+$)';
    RegExp regExp = RegExp(passwordRegExp);
    bool isPasw = regExp.hasMatch(value);
    return isPasw;
  }

  static bool isCheckEmail(String value) {
    String emailRegExp =
        r'^(([^<>()[\]\\.,;:\s@\"]+(\.[^<>()[\]\\.,;:\s@\"]+)*)|(\".+\"))@((\[[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}\])|(([a-zA-Z\-0-9]+\.)+[a-zA-Z]{2,}))$';
    RegExp regExp = RegExp(emailRegExp);
    bool isEml = regExp.hasMatch(value);
    return isEml;
  }

  static bool isValidateMobile(String value) {
    String pattern = r'(^(?:[+0]9)?[0-9]{10,12}$)';
    RegExp regExp = RegExp(pattern);
    if (value.isEmpty) {
      return false;
    } else if (!regExp.hasMatch(value)) {
      return false;
    }
    return true;
  }

  static hideKeyboard(BuildContext context) {
    FocusScope.of(context).unfocus();
  }

  static printWrapped(String text) {
    final pattern = RegExp('.{1,800}');
    pattern.allMatches(text).forEach((match) => print(match.group(0)));
  }
}
