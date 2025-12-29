
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:repo_agent_application/pages/account/account_screen.dart';
import 'package:repo_agent_application/pages/agentSearchedData/agent_search_data.dart' show AgentSearchDataScreen;
import 'package:repo_agent_application/pages/dashboard/dashboard_screen.dart';
import 'package:repo_agent_application/pages/home/home_screen.dart';
import 'package:repo_agent_application/pages/matchedCars/matched_cars.dart';
import 'package:repo_agent_application/pages/notifications/notifications_screen.dart';

import 'package:repo_agent_application/pages/splashScreen/splash_screen.dart';
import 'package:repo_agent_application/pages/loginScreen/login_screen.dart';
import 'package:hexcolor/hexcolor.dart';//LoginScreen
import 'package:repo_agent_application/pages/terms/terms_conditions.dart';
import 'package:repo_agent_application/pages/uploadOldCars/upload_old_cars.dart';

import '../../utils/config.dart';
import '../../utils/my_colors.dart';
import '../pages/matchedCars/matched_car_details.dart';
import '../pages/profile/profile_screen.dart';
import '../pages/searchCars/searche_cars.dart';
import '../pages/verifiedCars/verified_cars.dart';


// import 'package:gobuddy/pages/splash/splash_screen.dart';

//EKYCVerificationPage

class MyAppRoute extends StatefulWidget {
  const MyAppRoute({super.key});

  @override
  State<MyAppRoute> createState() => MyAppRouteState();
}

class MyAppRouteState extends State<MyAppRoute> {
  @override
   Widget build(BuildContext context) {



    return MaterialApp(
      debugShowCheckedModeBanner: false,
      // Required for Localization
      localizationsDelegates: context.localizationDelegates,
      supportedLocales: context.supportedLocales,
      locale: context.locale,
      title: Config.appName,
      initialRoute: Config.splashRouteName,
      theme: ThemeData(
        primaryColor: HexColor(MyColors.colorPrimary),
       
        fontFamily: Config.fontFamilyPoppinsRegular,
        appBarTheme: AppBarTheme(
          backgroundColor: HexColor(MyColors.navColor),
        ),
      ),
      
      routes: {
        //OnBoardScreenOne

        Config.splashRouteName: (ctx) => const SplashScreen(),
        Config.loginRouteName: (ctx) => const LoginScreen(),
        Config.homeRegRouteName: (ctx) => const HomeScreen(),
        Config.dashboardRouteName: (ctx) => const DashboardScreen(),
        Config.agentSearchedCarsRouteName: (ctx) => const AgentSearchDataScreen(),
        Config.uploadOldCarsRouteName: (ctx) => const UploadOldCarsScreen(),
        Config.verifiedCarsRouteName: (ctx) => VerifiedCarsScreen(),
        Config.matchedCarsRouteName: (ctx) => MatchedCarsScreen(),
        Config.searchCarsRouteName: (ctx) => SearchCarsScreen(),
        Config.accountRouteName: (ctx) => AccountScreen(),
        Config.profileRouteName: (ctx) => ProfileScreen(),
        Config.termsRouteName: (ctx) => TermsAndConditionsScreen(),
        Config.notificationsRouteName: (ctx) => NotificationsScreen(),
      //  Config.matchedCarDetailsRouteName: (ctx) => MatchedCarDetailsScreen(),


     

  
        //Config.myOrdersRouteName: (ctx) =>  MyOrdersScreen(),

      },
      // onGenerateRoute: (settings) {
      //   return MaterialPageRoute(
      //     builder: (_) => const SplashScreen(),
      //   );
      // },
      onGenerateRoute: (settings) {
        if (settings.name == Config.matchedCarDetailsRouteName) {
          final args = settings.arguments as Map<String, dynamic>;

          return MaterialPageRoute(
            builder: (_) => MatchedCarDetailsScreen(
              regNo: args['regNo'] ?? '',
            ),
          );
        }
        //
        // if (settings.name == Config.addServicesToCartRouteName) {
        //   final args = settings.arguments as Map<String, dynamic>;
        //
        //   // return MaterialPageRoute(
        //   //   builder: (_) => AddServicesScreen(
        //   //     serviceType: args['serviceType'] ?? '',
        //   //     serviceTitle: args['serviceTitle'] ?? '',
        //   //     //userid:args['user_id'] ?? '4361',
        //   //   ),
        //   // );
        // }
        // if (settings.name == Config.selectProviderVisitDateRouteName) {
        //   final args = settings.arguments as Map<String, dynamic>;
        //
        //   return MaterialPageRoute(
        //     builder: (_) => ScheduleVisitDateScreen(
        //       serviceType: args['serviceType'] ?? '',
        //       serviceTitle: args['serviceTitle'] ?? '',
        //       services: (args['services'] as List<dynamic>).cast<Map<String, dynamic>>(),
        //
        //       // This is the corrected line
        //       //userid:args['user_id'] ?? '4361',
        //     ),
        //   );
        // }

        





        // default
        return MaterialPageRoute(builder: (_) => const SplashScreen());
      },

      onUnknownRoute: (settings) {
        return MaterialPageRoute(
          builder: (_) => const SplashScreen(),
        );
      },
    );
  }
}

