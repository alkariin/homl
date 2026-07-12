import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:flutter/material.dart';
import 'package:homl/l10n/app_localizations.dart';
import 'package:homl/data/repositories/categories.repository.dart';
import 'package:homl/data/repositories/events.repository.dart';

import 'package:homl/components/logo.dart';
import 'package:homl/data/repositories/settings.repository.dart';
import 'package:homl/data/repositories/tags.repository.dart';
import 'package:homl/helpers/app_message.dart';
import 'package:homl/helpers/colors.dart';
import 'package:homl/pages/settings/view/settings.dart';
import 'package:homl/pages/categories/categories.dart';
import 'package:homl/pages/home/bloc/home_cubit.dart';
import 'package:homl/pages/insert/insert.dart';
import 'package:homl/pages/list/bloc/list_cubit.dart';
import 'package:homl/pages/list/list.dart';
import 'package:homl/pages/account/view/account.dart';

class HomePage extends StatefulWidget {
  final String username;

  const HomePage({super.key, required this.username});

  static Route<void> route(String username) {
    return MaterialPageRoute<void>(
        builder: (_) => HomePage(username: username));
  }

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  // Created once for the lifetime of the page, not on every build.
  final EventsRepository _eventsRepository = EventsRepository();
  final CategoriesRepository _categoriesRepository = CategoriesRepository();
  final TagsRepository _tagsRepository = TagsRepository();

  @override
  void dispose() {
    _eventsRepository.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
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
                  create: (BuildContext context) => HomeCubit(
                      context.read<SettingsRepository>(),
                      _eventsRepository,
                      _categoriesRepository,
                      _tagsRepository,
                      widget.username)),
              BlocProvider(
                  create: (BuildContext context) =>
                      ListCubit(_eventsRepository)),
            ],
            child: BlocBuilder<HomeCubit, HomeState>(builder: (context, state) {
              return HomeView(state.settings.defaultScreen);
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
  late final PageController _pageController;

  /// True once the user changed the tab himself: the async-loaded
  /// defaultScreen setting must not override an explicit navigation.
  bool _userNavigated = false;

  @override
  void initState() {
    super.initState();
    // defaultScreen setting: false opens on Search, true on Add.
    _currentIndex = widget.defaultView ? 2 : 1;
    // The controller must start on the same page as the selected tab,
    // otherwise the PageView shows page 0 while the nav bar says otherwise.
    _pageController = PageController(initialPage: _currentIndex);
  }

  @override
  void didUpdateWidget(covariant HomeView oldWidget) {
    super.didUpdateWidget(oldWidget);
    // The settings arrive asynchronously: apply the new default tab as long
    // as the user has not navigated on his own yet.
    if (widget.defaultView != oldWidget.defaultView && !_userNavigated) {
      setState(() {
        _currentIndex = widget.defaultView ? 2 : 1;
      });
      if (_pageController.hasClients) {
        _pageController.jumpToPage(_currentIndex);
      }
    }
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  /// From the Categories tab: adds the tapped tag as a search filter and
  /// jumps to the Search tab.
  void _searchByTag(BuildContext context, TagView tag) {
    context.read<ListCubit>().addFilterTag(tag.tagName);
    setState(() {
      _userNavigated = true;
      _currentIndex = 1;
      _pageController.animateToPage(1,
          duration: const Duration(milliseconds: 500), curve: Curves.ease);
    });
  }

  @override
  Widget build(BuildContext context) {
    var localization = AppLocalizations.of(context)!;

    final tabTitles = [
      localization.nav_categories,
      localization.nav_search,
      localization.nav_add,
    ];

    final drawerItems = ListView(
      children: [
        SizedBox(
          height: 90.0,
          child: DrawerHeader(
            padding: const EdgeInsets.only(left: 20, right: 20),
            decoration: const BoxDecoration(
              color: Colors.white,
              border: Border(bottom: BorderSide(color: borderGrey, width: 0.5)),
            ),
            child: Row(
              children: [
                const HomlLogo(size: 40),
                const SizedBox(width: 12),
                const Text(
                  'HOML',
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.w700),
                ),
                const Spacer(),
                IconButton(
                    iconSize: 18,
                    icon: const FaIcon(FontAwesomeIcons.xmark),
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
                .push(AccountPage.route(context.read<HomeCubit>()));
          },
        ),
        _DrawerListTile(
          title: localization.settings,
          icon: const Icon(Icons.settings),
          onTap: () {
            Navigator.of(context).push(SettingsPage.route());
          },
        ),
      ],
    );

    return BlocListener<HomeCubit, HomeState>(
      listener: (context, state) {
        final homeCubit = context.read<HomeCubit>();
        if (state.modal != null) {
          ScaffoldMessenger.of(context)
            ..hideCurrentSnackBar()
            ..showSnackBar(SnackBar(
              content: Text(state.modal!.localize(localization)),
              action: SnackBarAction(
                  label: localization.global_close, onPressed: () {}),
              duration: const Duration(seconds: 5),
            )).closed.then((_) {
              homeCubit.endModal();
            });
        }
      },
      child: Scaffold(
        appBar: AppBar(
          leading: Builder(
            builder: (context) => IconButton(
              icon: const FaIcon(FontAwesomeIcons.user, size: 18),
              onPressed: () => Scaffold.of(context).openDrawer(),
            ),
          ),
          title: Text(tabTitles[_currentIndex]),
          actions: const [
            Padding(
              padding: EdgeInsets.only(right: 16),
              child: HomlLogo(size: 34),
            ),
          ],
        ),
        body: PageView(
          controller: _pageController,
          children: [
            CategoriesPage(onTagSelected: (tag) => _searchByTag(context, tag)),
            const ListPage(),
            const InsertPage(),
          ],
          onPageChanged: (index) {
            setState(() {
              // A change we did not trigger ourselves is a user swipe.
              if (index != _currentIndex) _userNavigated = true;
              _currentIndex = index;
            });
          },
        ),
        bottomNavigationBar: Container(
          decoration: const BoxDecoration(
            color: Colors.white,
            border: Border(top: BorderSide(color: borderGrey, width: 0.5)),
          ),
          child: BottomNavigationBar(
            currentIndex: _currentIndex,
            backgroundColor: Colors.transparent,
            elevation: 0,
            showSelectedLabels: false,
            showUnselectedLabels: false,
            selectedItemColor: yellow,
            unselectedItemColor: ink,
            iconSize: 22,
            onTap: (index) {
              setState(() {
                _userNavigated = true;
                _currentIndex = index;
                _pageController.animateToPage(index,
                    duration: const Duration(milliseconds: 500),
                    curve: Curves.ease);
              });
            },
            items: [
              BottomNavigationBarItem(
                  icon: const FaIcon(FontAwesomeIcons.tags),
                  label: localization.nav_categories),
              BottomNavigationBarItem(
                  icon: const FaIcon(FontAwesomeIcons.magnifyingGlass),
                  label: localization.nav_search),
              BottomNavigationBarItem(
                  icon: const FaIcon(FontAwesomeIcons.plus, size: 26),
                  label: localization.nav_add),
            ],
          ),
        ),
        drawer: Drawer(backgroundColor: Colors.white, child: drawerItems),
      ),
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
