import 'package:flutter/material.dart';
import 'Select.dart'; // เชื่อมไปหาหน้า LoginSelectionPage

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

// แยกหน้าจอ Welcome ออกมาเพื่อให้โค้ดดูเป็นระเบียบ
class WelcomeScreen extends StatelessWidget {
  const WelcomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    // 💡 ครอบ Scaffold ทั้งหมดด้วย GestureDetector เพื่อตรวจจับการแตะทั่วทั้งหน้าจอ
    return GestureDetector(
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(builder: (context) => const LoginSelectionPage()),
        );
      },
      child: Scaffold(
        body: Container(
          width: double.infinity,
          height: double.infinity,
          decoration: const BoxDecoration(
            image: DecorationImage(
              image: AssetImage('assets/images/bgmmk.png'), 
              fit: BoxFit.cover,
            ),
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Spacer(flex: 2), 
              
              Image.asset(
                'assets/images/MMK_logofull.png', 
                width: 396, 
              ),
              
              const Spacer(flex: 1),
              
              const SizedBox(height: 10),
              
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
              
              const Spacer(flex: 4), 
            ],
          ),
        ),
      ),
    );
  }
}