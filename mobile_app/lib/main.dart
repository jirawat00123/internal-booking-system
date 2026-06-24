import 'package:flutter/material.dart';
import 'Select.dart';

void main() {
  runApp(const WelcomeApp());
}

class WelcomeApp extends StatelessWidget {
  const WelcomeApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      
      title: 'Menam Mechanika',
      theme: ThemeData(
        primarySwatch: Colors.blue,
      ),
      builder: (context, child) {
        return Scaffold(
          backgroundColor: Colors.grey[900], 
          body: Center(
            child: Container(
              width: 400, 
              height: 800, 
              clipBehavior: Clip.antiAlias,
              decoration: BoxDecoration(
                color: Colors.black,
                borderRadius: BorderRadius.circular(30), 
                boxShadow: const [
                  BoxShadow(
                    color: Colors.black54,
                    blurRadius: 20,
                    spreadRadius: 5,
                  ),
                ],
              ),
              child: child, 
            ),
          ),
        );
      },
      home: const WelcomeScreen(),
    );
  }
}

class WelcomeScreen extends StatefulWidget {
  const WelcomeScreen({super.key});

  @override
  State<WelcomeScreen> createState() => _WelcomeScreenState();
}

class _WelcomeScreenState extends State<WelcomeScreen> with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _fadeAnimation;
  late Animation<Offset> _slideAnimation;

  @override
  void initState() {
    super.initState();
    // 1. Setup Animation Controller
    _controller = AnimationController(
      duration: const Duration(milliseconds: 1500), // ความยาว Animation ทั้งหมด 1.5 วินาที
      vsync: this,
    );

    // 2. Fade Animation (สำหรับค่อยๆ ปรากฏขึ้น)
    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _controller,
        curve: const Interval(0.2, 1.0, curve: Curves.easeIn), // เริ่มโชว์หลังจากผ่านไป 20% ของเวลา
      ),
    );

    // 3. Slide Animation (สำหรับการเลื่อนขึ้นจากด้านล่าง)
    _slideAnimation = Tween<Offset>(begin: const Offset(0, 0.2), end: Offset.zero).animate(
      CurvedAnimation(
        parent: _controller,
        curve: const Interval(0.0, 0.8, curve: Curves.easeOutBack), 
      ),
    );

   
    _controller.forward();
  }

  @override
  void dispose() {
    _controller.dispose(); 
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () {
        
        Navigator.push(
          context,
          PageRouteBuilder(
            pageBuilder: (context, animation, secondaryAnimation) => const LoginSelectionPage(),
            transitionsBuilder: (context, animation, secondaryAnimation, child) {
              return FadeTransition(opacity: animation, child: child);
            },
          ),
        );
      },
      child: Scaffold(
        body: Container(
          width: double.infinity,
          height: double.infinity,
          decoration: const BoxDecoration(
            image: DecorationImage(
              image: AssetImage('assets/bg.png'), 
              fit: BoxFit.cover,
            ),
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Spacer(flex: 2), 
              
             
              SlideTransition(
                position: _slideAnimation,
                child: FadeTransition(
                  opacity: _fadeAnimation,
                  child: Column(
                    children: [
                      Image.asset(
                        'assets/MMK-logo-03.1.png', 
                        width: 396, 
                      ),
                      const SizedBox(height: 70),
                      Container(
                        width: 280, 
                        height: 2,  
                        color: Colors.white,
                      ),
                      const SizedBox(height: 15), 
                      const Text(
                        'MENAM MECHANIKA © 2026',
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 0.5, 
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              
              
              const Spacer(flex: 3), 
              
              FadeTransition(
                opacity: _fadeAnimation,
                child: TweenAnimationBuilder<double>(
                  tween: Tween(begin: 0.3, end: 1.0),
                  duration: const Duration(seconds: 1),
                  curve: Curves.easeInOut,
                  builder: (context, value, child) {
                     return Opacity(
                       opacity: value,
                       child: const Text(
                         'Tap anywhere to continue',
                         style: TextStyle(
                           color: Colors.white70,
                           fontSize: 14,
                           fontWeight: FontWeight.w300,
                           letterSpacing: 1.2
                         ),
                       ),
                     );
                  },
                  onEnd: () {

                  },
                ),
              ),

              const Spacer(flex: 1), 
            ],
          ),
        ),
      ),
    );
  }
}