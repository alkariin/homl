import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:flutter/material.dart';
import 'package:homl/l10n/app_localizations.dart';
import 'package:homl/data/repositories/categories.repository.dart';
import 'package:homl/data/repositories/events.repository.dart';

import 'package:homl/components/app_bar_mark.dart';
import 'package:homl/components/bubbles_background.dart';
import 'package:homl/components/logo.dart';
import 'package:homl/data/repositories/settings.repository.dart';
import 'package:homl/data/repositories/tags.repository.dart';
import 'package:homl/helpers/app_message.dart';
import 'package:homl/helpers/colors.dart';
import 'package:homl/helpers/server_reachability.dart';
import 'package:homl/helpers/toast.dart';
import 'package:homl/pages/settings/view/settings.dart';
import 'package:homl/pages/categories/categories.dart';
import 'package:homl/pages/home/bloc/home_cubit.dart';
import 'package:homl/pages/insert/bloc/insert_cubit.dart';
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
              // Provided here rather than by the Add tab: the app bar mark
              // lives above the PageView and follows the tags of the event
              // being written. The edit route, outside this scope, still
              // creates its own (seeded from the event).
              BlocProvider(
                  create: (BuildContext context) =>
                      InsertCubit(_eventsRepository, _tagsRepository)),
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

  /// Set while we drive the PageView ourselves (a created event sends the user
  /// back to the list, the defaultScreen setting arrives late): the resulting
  /// page change is not a user navigation and must not wipe the toast we just
  /// showed.
  bool _ownPageChange = false;

  /// Stored name of the tag being typed in the visible tab's field, watched
  /// by the app bar mark. Cleared on a tab change: the mark then falls back
  /// to the tags chosen in the tab the user lands on.
  final ValueNotifier<String?> _typedTag = ValueNotifier(null);

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
        _ownPageChange = true;
        _pageController.jumpToPage(_currentIndex);
      }
    }
  }

  @override
  void dispose() {
    _pageController.dispose();
    _typedTag.dispose();
    super.dispose();
  }

  /// The app bar mark, fed by the tags of the visible tab: the search
  /// filters, the tags of the event being written, or nothing on the
  /// Categories tab, which has no tag field.
  Widget _mark() {
    return BlocBuilder<HomeCubit, HomeState>(builder: (context, home) {
      switch (_currentIndex) {
        case 1:
          return BlocBuilder<ListCubit, ListState>(
              builder: (context, state) => AppBarMark(
                  tagNames: state.filters,
                  typedTag: _typedTag,
                  accentColorOf: home.markAccentFor));
        case 2:
          return BlocBuilder<InsertCubit, InsertState>(
              builder: (context, state) => AppBarMark(
                  tagNames: state.tagNames,
                  typedTag: _typedTag,
                  accentColorOf: home.markAccentFor));
        default:
          return AppBarMark(
              tagNames: const [], accentColorOf: home.markAccentFor);
      }
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

    // Read-only identity line under the logo (the login username is the
    // account email).
    final email = context.select<HomeCubit, String>((c) => c.state.username);

    final drawerItems = ListView(
      padding: const EdgeInsets.symmetric(horizontal: 8),
      children: [
        // Deliberately NOT a DrawerHeader: that widget hardcodes a 161px
        // height and adds the status bar inset to its top padding, so the
        // leftover space (and any Spacer in it) differed between mobile and
        // web. This sizes to its content instead, keeping the logo/email gap
        // identical everywhere, and insets the status bar itself.
        Container(
          padding: EdgeInsets.fromLTRB(
              12, 10 + MediaQuery.paddingOf(context).top, 4, 16),
          margin: const EdgeInsets.only(bottom: 8),
          decoration: const BoxDecoration(
            border:
                Border(bottom: BorderSide(color: Color(0x14000000), width: 1)),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  // The bare two-tone hash, as large as the tag-input button.
                  const HomlLogo(size: 51),
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
              // Matches what the old Spacer resolved to on mobile, which is
              // where this header already looked right.
              const SizedBox(height: 18),
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
          showToast(context, state.modal!.localize(localization),
                  duration: const Duration(seconds: 5))
              .closed
              .then((_) {
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
          actions: [
            const OfflineIndicator(),
            _mark(),
            const SizedBox(width: 16)
          ],
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
                ListPage(typedTag: _typedTag),
                // A created event brings the user back to the list.
                InsertView(
                  typedTag: _typedTag,
                  onCreated: () {
                    _ownPageChange = true;
                    _pageController.animateToPage(1,
                        duration: const Duration(milliseconds: 400),
                        curve: Curves.ease);
                  },
                ),
              ],
              onPageChanged: (index) {
                // A change we did not trigger ourselves is a user swipe: the
                // toast of the tab he is leaving does not belong to the new
                // one. Our own moves keep it (the "event created"
                // confirmation rides along to the list).
                if (_ownPageChange) {
                  _ownPageChange = false;
                } else {
                  dismissToasts(context);
                }
                // The field of the tab being left keeps its text; its
                // suggestion is not what the mark must show here.
                _typedTag.value = null;
                setState(() {
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
              dismissToasts(context);
              setState(() {
                _userNavigated = true;
                _currentIndex = index;
                _ownPageChange = true;
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

/// Shown in the app bar while the server cannot be reached: the screens run
/// on the data saved on this device, changes need a connection. Tapping it
/// says so.
class OfflineIndicator extends StatelessWidget {
  const OfflineIndicator({super.key});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<Reachability>(
      stream: ServerReachability.instance.stream,
      initialData: ServerReachability.instance.value,
      builder: (context, snapshot) {
        if (snapshot.data != Reachability.offline) {
          return const SizedBox.shrink();
        }
        final localization = AppLocalizations.of(context)!;
        return IconButton(
          tooltip: localization.offline_title,
          icon: const Icon(Icons.cloud_off_outlined),
          onPressed: () => showToast(context, localization.offline_explanation,
              duration: const Duration(seconds: 6)),
        );
      },
    );
  }
}
