import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:homl/pages/home/bloc/home_bloc.dart';

class CategoriesPage extends StatelessWidget {
  const CategoriesPage({super.key});

  static Route<void> route() {
    return MaterialPageRoute<void>(builder: (_) => const CategoriesPage());
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            const Text('Categories'),
            BlocBuilder<HomeBloc, HomeState>(builder: (context, state) {
              return Text(
                  context.read<HomeBloc>().state.settings.language.name);
            })
          ],
        ),
      ),
    );
  }
}
