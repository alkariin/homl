import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:flutter/material.dart';
import 'package:homl/l10n/app_localizations.dart';
import 'package:homl/data/repositories/categories.repository.dart';
import 'package:homl/data/repositories/events.repository.dart';

import 'package:homl/components/bubbles_background.dart';
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
                      ListCubit(context.read<HomeCubit>())),
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

  @override
  Widget build(BuildContext context) {
    var localization = AppLocalizations.of(context)!;

    final tabTitles = [
      localization.nav_categories,
      localization.nav_search,
      localization.nav_add,
    ];

    // Read-only identity line under the logo (the login username is the
    // account email).
    final email = context.select<HomeCubit, String>((c) => c.state.username);

    final drawerItems = ListView(
      padding: const EdgeInsets.symmetric(horizontal: 8),
      children: [
        SizedBox(
          height: 148.0,
          child: DrawerHeader(
            padding: const EdgeInsets.fromLTRB(12, 10, 4, 16),
            margin: const EdgeInsets.only(bottom: 8),
            decoration: const BoxDecoration(
              border: Border(
                  bottom: BorderSide(color: Color(0x14000000), width: 1)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    // The bare two-tone hash, as large as the tag-input
                    // button.
                    const HomlLogo(size: 51, circled: false),
                    const SizedBox(width: 12),
                    const Text(
                      'HOML',
                      style:
                          TextStyle(fontSize: 20, fontWeight: FontWeight.w700),
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
                const Spacer(),
                Padding(
                  padding: const EdgeInsets.only(left: 4),
                  child: Text(
                    email,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                        fontSize: 13, color: ink.withValues(alpha: 0.5)),
                  ),
                ),
              ],
            ),
          ),
        ),
        _DrawerListTile(
          title: localization.account,
          icon: Icons.shield_outlined,
          onTap: () {
            Navigator.of(context)
                .push(AccountPage.route(context.read<HomeCubit>()));
          },
        ),
        _DrawerListTile(
          title: localization.settings,
          icon: Icons.settings_outlined,
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
              icon: const Icon(Icons.menu_rounded),
              onPressed: () => Scaffold.of(context).openDrawer(),
            ),
          ),
          title: Text(tabTitles[_currentIndex]),
        ),
        body: Stack(
          children: [
            // One decorative background for the three tabs, wider than the
            // screen and slid sideways with the PageView: swiping to a tab
            // reveals the matching slice of the artwork.
            AnimatedBuilder(
              animation: _pageController,
              builder: (context, _) {
                final page = _pageController.hasClients &&
                        _pageController.position.haveDimensions
                    ? _pageController.page ?? _currentIndex.toDouble()
                    : _currentIndex.toDouble();
                return _ParallaxBackground(page: page, pageCount: 3);
              },
            ),
            PageView(
              controller: _pageController,
              children: [
                const CategoriesPage(),
                const ListPage(),
                // A created event brings the user back to the list.
                InsertPage(
                  onCreated: () => _pageController.animateToPage(1,
                      duration: const Duration(milliseconds: 400),
                      curve: Curves.ease),
                ),
              ],
              onPageChanged: (index) {
                setState(() {
                  // A change we did not trigger ourselves is a user swipe.
                  if (index != _currentIndex) _userNavigated = true;
                  _currentIndex = index;
                });
              },
            ),
          ],
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
            selectedItemColor: ink,
            unselectedItemColor: ink.withValues(alpha: 0.3),
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

/// Drawer entry: identical layout for every destination (icon, label,
/// chevron), rounded highlight.
class _DrawerListTile extends StatelessWidget {
  const _DrawerListTile(
      {required this.title, required this.icon, required this.onTap});

  final String title;
  final IconData icon;
  final void Function() onTap;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      contentPadding: const EdgeInsets.symmetric(horizontal: 16),
      minLeadingWidth: 32,
      leading: Icon(icon, size: 22),
      title: Text(title),
      trailing: Icon(Icons.chevron_right,
          size: 20, color: ink.withValues(alpha: 0.3)),
      onTap: onTap,
    );
  }
}

/// Renders the shared decorative background wider than the screen and slides
/// it with the PageView position: the leftmost tab shows its left slice, the
/// rightmost tab its right slice.
class _ParallaxBackground extends StatelessWidget {
  /// Extra width of the artwork relative to the screen.
  static const _overflow = 0.4;

  final double page;
  final int pageCount;

  const _ParallaxBackground({required this.page, required this.pageCount});

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(builder: (context, constraints) {
      final w = constraints.maxWidth;
      final extra = w * _overflow;
      final progress = (page / (pageCount - 1)).clamp(0.0, 1.0);
      return ClipRect(
        child: OverflowBox(
          alignment: Alignment.centerLeft,
          minWidth: 0,
          maxWidth: w + extra,
          child: Transform.translate(
            offset: Offset(-extra * progress, 0),
            child: SizedBox(
              width: w + extra,
              height: constraints.maxHeight,
              child: const BubblesBackground(),
            ),
          ),
        ),
      );
    });
  }
}
