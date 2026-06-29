import 'package:flutter/material.dart';

class InsertPage extends StatelessWidget {
  const InsertPage({super.key});

  static Route<void> route() {
    return MaterialPageRoute<void>(builder: (_) => const InsertPage());
  }

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[Text('Insert')],
        ),
      ),
    );
  }
}
