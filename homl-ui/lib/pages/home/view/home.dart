import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:flutter/material.dart';
import 'package:homl/l10n/app_localizations.dart';
import 'package:homl/data/repositories/categories.repository.dart';
import 'package:homl/data/repositories/events.repository.dart';

import 'package:homl/data/repositories/settings.repository.dart';
import 'package:homl/data/repositories/tags.repository.dart';
import 'package:homl/helpers/colors.dart';
import 'package:homl/pages/settings/view/settings.dart';
import 'package:homl/pages/categories/categories.dart';
import 'package:homl/pages/home/bloc/home_bloc.dart';
import 'package:homl/pages/insert/insert.dart';
import 'package:homl/pages/list/bloc/list_bloc.dart';
import 'package:homl/pages/list/list.dart';
import 'package:homl/pages/account/view/account.dart';

class HomePage extends StatelessWidget {
  final String username;

  HomePage({super.key, required this.username});

  static Route<void> route(String username) {
    return MaterialPageRoute<void>(
        builder: (_) => HomePage(username: username));
  }

  final EventsRepository _eventsRepository = EventsRepository();
  final CategoriesRepository _categoriesRepository = CategoriesRepository();
  final TagsRepository _tagsRepository = TagsRepository();

  @override
  Widget build(BuildContext context) {
    var localization = AppLocalizations.of(context)!;
    return MultiRepositoryProvider(
        providers: [
          RepositoryProvider<EventsRepository>.value(value: _eventsRepository),
          RepositoryProvider<CategoriesRepository>.value(
              value: _categoriesRepository),
          RepositoryProvider<TagsRepository>.value(value: _tagsRepository),
        ],
        child: MultiBlocProvider(
            providers: [
              BlocProvider(
                  create: (BuildContext context) => HomeBloc(
                      localization,
                      context.read<SettingsRepository>(),
                      _eventsRepository,
                      _categoriesRepository,
                      _tagsRepository,
                      username)),
              BlocProvider(
                  create: (BuildContext context) =>
                      ListBloc(localization, _eventsRepository)),
            ],
            child: BlocBuilder<HomeBloc, HomeState>(builder: (context, state) {
              return HomeView(
                  context.read<HomeBloc>().state.settings.defaultScreen);
            })));
  }
}

class HomeView extends StatefulWidget {
  final bool defaultView;

  const HomeView(this.defaultView, {super.key});

  @override
  State<HomeView> createState() => _HomeViewState();
}

class _HomeViewState extends State<HomeView>
    with SingleTickerProviderStateMixin {
  late int _currentIndex;
  final PageController _pageController = PageController();

  @override
  void initState() {
    super.initState();
    _currentIndex = widget.defaultView ? 1 : 0;
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    var localization = AppLocalizations.of(context)!;

    final drawerItems = ListView(
      children: [
        SizedBox(
          height: 80.0,
          child: DrawerHeader(
            padding: const EdgeInsets.only(left: 20, right: 20),
            decoration: const BoxDecoration(
              color: primary,
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'HOML',
                  style: TextStyle(
                    fontSize: 20,
                  ),
                ),
                IconButton(
                    iconSize: 18,
                    icon: const FaIcon(FontAwesomeIcons.arrowRightFromBracket),
                    padding: const EdgeInsets.only(right: 10, left: 30),
                    onPressed: () {
                      Navigator.pop(context);
                    }),
              ],
            ),
          ),
        ),
        _DrawerListTile(
          title: localization.account,
          icon: const FaIcon(FontAwesomeIcons.user),
          onTap: () {
            Navigator.of(context)
                .push(AccountPage.route(context.read<HomeBloc>()));
          },
        ),
        _DrawerListTile(
          title: localization.settings,
          icon: const Icon(Icons.settings),
          onTap: () {
            Navigator.of(context).push(SettingsPage.route());
            // Navigator.push(context, LanguageDialog.simpleDialogDemoRoute(context));
          },
        ),
      ],
    );

    return Scaffold(
      appBar: AppBar(
        title: const Text("Homl"),
      ),
      body: PageView(
        controller: _pageController,
        children: [
          const CategoriesPage(),
          ListPage(),
          const InsertPage(),
        ],
        onPageChanged: (index) {
          setState(() {
            _currentIndex = index;
          });
        },
      ),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _currentIndex,
        onTap: (index) {
          setState(() {
            _currentIndex = index;
            _pageController.animateToPage(index,
                duration: const Duration(milliseconds: 500),
                curve: Curves.ease);
          });
        },
        items: [
          BottomNavigationBarItem(
              icon: const Icon(Icons.format_list_bulleted_add),
              label: localization.nav_categories),
          BottomNavigationBarItem(
              icon: const Icon(Icons.search), label: localization.nav_search),
          BottomNavigationBarItem(
              icon: const Icon(Icons.add), label: localization.nav_add),
        ],
        selectedItemColor: Colors.amber[800],
      ),
      drawer: Drawer(child: drawerItems),
    );
  }
}

class _DrawerListTile extends StatelessWidget {
  const _DrawerListTile(
      {required this.title, required this.icon, required this.onTap});

  final String title;
  final Widget icon;
  final void Function() onTap;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      contentPadding: const EdgeInsets.only(left: 25),
      minLeadingWidth: 30,
      title: Text(title),
      leading: icon,
      onTap: () {
        onTap();
      },
    );
  }
}
