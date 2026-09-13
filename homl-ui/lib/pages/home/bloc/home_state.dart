part of 'home_cubit.dart';

class TagView {
  final int id;
  final String color;
  final String tagName;
  final int idCategory;

  /// Id of the main tag when this tag is a synonym (null = main tag).
  final int? idParentTag;

  const TagView(this.id, this.color, this.tagName, this.idCategory,
      [this.idParentTag]);
}

class HomeState extends Equatable {
  final String username;
  final Settings settings;
  final List<Event> events;
  final List<Category> categories;
  final Map<String, TagView> allTagsMap;

  /// True once the events/categories were loaded at least once, from the
  /// offline cache or from the network.
  final bool initialized;
  final AppMessage? modal;

  const HomeState(
      {required this.username,
      required this.events,
      required this.categories,
      required this.settings,
      required this.allTagsMap,
      this.initialized = false,
      this.modal});

  HomeState.initial(String username)
      : this(
            username: username,
            events: [],
            categories: [],
            settings: Settings.initial(),
            allTagsMap: <String, TagView>{});

  HomeState copyWith(
      {String? username,
      List<Event>? events,
      List<Category>? categories,
      Settings? settings,
      Map<String, TagView>? allTagsMap,
      bool? initialized,
      AppMessage? modal,
      bool clearModal = false}) {
    return HomeState(
      username: username ?? this.username,
      events: events ?? this.events,
      categories: categories ?? this.categories,
      settings: settings ?? this.settings,
      allTagsMap: allTagsMap ?? this.allTagsMap,
      initialized: initialized ?? this.initialized,
      modal: clearModal ? null : (modal ?? this.modal),
    );
  }

  /// Category color ("#RRGGBB") tinting the app bar mark for [tagName], or
  /// null when the mark must stay in its resting gold: an unknown tag, a date
  /// tag (the mark already wears the gold of the Dates category) or an Others
  /// tag (its grey never reads as a category — the same rule the input border
  /// follows).
  String? markAccentFor(String tagName) {
    final tag = allTagsMap[tagName];
    if (tag == null || dateCategoryIds(categories).contains(tag.idCategory)) {
      return null;
    }

    for (final category in categories) {
      if (category.id == tag.idCategory) {
        return category.kind == CategoryKind.other ? null : tag.color;
      }
    }
    return null;
  }

  @override
  List<Object?> get props =>
      [username, events, categories, settings, allTagsMap, initialized, modal];
}
