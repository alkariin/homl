part of 'home_bloc.dart';

class TagView {
  final int id;
  final String color;
  final String tagName;
  final int idCategory;

  const TagView(this.id, this.color, this.tagName, this.idCategory);
}

class HomeState extends Equatable {
  final String username;
  final Settings settings;
  final List<Event> events;
  final List<Category> categories;
  final Map<String, TagView> allTagsMap;
  final String? modal;

  const HomeState(
      {required this.username,
      required this.events,
      required this.categories,
      required this.settings,
      required this.allTagsMap,
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
      String? modal}) {
    return HomeState(
      username: username ?? this.username,
      events: events ?? this.events,
      categories: categories ?? this.categories,
      settings: settings ?? this.settings,
      allTagsMap: allTagsMap ?? this.allTagsMap,
      modal: modal ?? this.modal,
    );
  }

  @override
  List<Object?> get props => [username, events, categories, settings, modal];
}
