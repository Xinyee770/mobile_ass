import 'package:flutter/material.dart';
import 'profile.dart';
import 'booking.dart';
import 'payment.dart';
import 'admin.dart';
import 'classes.dart';
//Testing

class Home extends StatelessWidget {
  const Home ({super.key});

  // This widget is the root of your application.
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Flutter Demo',
      theme: ThemeData(
        colorScheme: .fromSeed(seedColor: Colors.deepPurple),
      ),
      home: const MyHomePage(title: 'ABC APP'),
    );
  }
}

class MyHomePage extends StatefulWidget {
  const MyHomePage({super.key, required this.title});
  final String title;
  @override
  State<MyHomePage> createState() => _MyHomePageState();
}

class _MyHomePageState extends State<MyHomePage> {
  //int _counter = 0;

  //void _incrementCounter() {
   // setState(() {

      //_counter++;
    //});
  //}

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
        title: Text(widget.title),
      ),
      body: Center(
        child: Column(
          mainAxisAlignment: .center,
          // Inside your _MyHomePageState build method, replace the Column children:
          children: [
            const Text('Dashboard Menu', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
            const SizedBox(height: 20), // Spacing

            // 1. User Profile Button
            ElevatedButton.icon(
              onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (context) => const Profile())),
              icon: const Icon(Icons.person),
              label: const Text('User Profile'),
            ),

            // 2. Calendar Button
            ElevatedButton.icon(
              onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (context) => const BookingPage())),
              icon: const Icon(Icons.calendar_month),
              label: const Text('Calendar'),
            ),

            // 3. Payment Button
            ElevatedButton.icon(
              onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (context) => const Payment())),
              icon: const Icon(Icons.payment),
              label: const Text('Payment'),
            ),

            // 4. Admin Button
            ElevatedButton.icon(
              onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (context) => const Admin())),
              icon: const Icon(Icons.admin_panel_settings),
              label: const Text('Admin'),
            ),

            // 5. Classes
            ElevatedButton.icon(
              onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (context) => const Classes())),
              icon: const Icon(Icons.settings),
              label: const Text('Classes'),
            ),
          ],
        ),
      ),
      //floatingActionButton: FloatingActionButton(
        //onPressed: _incrementCounter,
        //tooltip: 'Increment',
        //child: const Icon(Icons.add),
      //),
    );
  }
}
