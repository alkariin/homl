# homl-ui frontend

Flutter client for HOML (iOS · Android · Web). It needs a running backend:
see [../homl-web/README.md](../homl-web/README.md) for the stack, and
[../homl-web/docs/api.md](../homl-web/docs/api.md) for the API it consumes.

## 1) Install dependencies

```bash
flutter pub get
```

## 2) Run

```bash
flutter run -d chrome --dart-define=API_BASE_URL=http://localhost:8080/api
```

`API_BASE_URL` is the server the app starts with. It is optional: without
it the login screen asks for the server's address before the first sign-in,
and the address picked there always wins (see "Server address" below).

For Android emulator, use host loopback mapping:

```bash
flutter run --dart-define=API_BASE_URL=http://10.0.2.2:8080/api
```

## 2b) Run on a physical Android device

### One-time toolchain setup (user-local, no sudo)

The web workflow only needs Flutter, but an Android build also needs a JDK and
the Android SDK. Everything installs under `~/.local` (no sudo):

```bash
# JDK 17 (Temurin)
curl -fsSL -o /tmp/jdk17.tar.gz \
  "https://api.adoptium.net/v3/binary/latest/17/ga/linux/x64/jdk/hotspot/normal/eclipse"
mkdir -p ~/.local/jdk && tar -xzf /tmp/jdk17.tar.gz -C ~/.local/jdk --strip-components=1

# Android command-line tools -> ~/.local/android-sdk/cmdline-tools/latest
curl -fsSL -o /tmp/cmdtools.zip \
  "https://dl.google.com/android/repository/commandlinetools-linux-11076708_latest.zip"
mkdir -p ~/.local/android-sdk/cmdline-tools
unzip -q /tmp/cmdtools.zip -d /tmp/cmdtools-x
mv /tmp/cmdtools-x/cmdline-tools ~/.local/android-sdk/cmdline-tools/latest

# SDK packages (matches Flutter's compile/target SDK 36)
export JAVA_HOME=~/.local/jdk ANDROID_HOME=~/.local/android-sdk
export PATH="$JAVA_HOME/bin:$PATH"
SDKM=~/.local/android-sdk/cmdline-tools/latest/bin/sdkmanager
yes | $SDKM --sdk_root="$ANDROID_HOME" --licenses
$SDKM --sdk_root="$ANDROID_HOME" "platform-tools" "platforms;android-36" "build-tools;36.0.0"

# Point Flutter at them and accept licenses
export PATH="$HOME/.local/flutter/bin:$ANDROID_HOME/platform-tools:$PATH"
flutter config --android-sdk "$ANDROID_HOME"
flutter config --jdk-dir "$JAVA_HOME"
yes | flutter doctor --android-licenses
flutter doctor            # Android toolchain should be [✓]
```

### Gradle toolchain

The Android build scripts use the Kotlin DSL (`*.gradle.kts`), like the
Flutter template. They pin the toolchain in `android/settings.gradle.kts` (AGP
8.11.1, Kotlin 2.4.0), and `android/gradle/wrapper/gradle-wrapper.properties`
pins Gradle 8.14.6; all three are downloaded on first build. Flutter 3.47
warns that it will soon drop these (it asks for Gradle 9.1+ and AGP 9.0.1+),
but anything newer is blocked by biometric_storage 5: it compiles against API 31, which AGP
8.12+ rejects in `checkDebugAarMetadata`, and it applies the Kotlin Gradle
plugin (and kapt) itself, so AGP 9's built-in Kotlin must stay off, while
file_picker 11 skips that plugin on AGP 9 and expects built-in Kotlin (the
build then fails on a missing `FilePickerPlugin`). biometric_storage 6, still
in dev releases, fixes both. `android/app/build.gradle.kts` uses
`flutter.ndkVersion`, so the NDK follows the Flutter SDK (28.2 today) and is
pulled by `sdkmanager` automatically. Once that blocker is gone, follow
Flutter's "will soon be dropped" warnings: bump those two files to the minimum
it prints and rebuild.

Disk tip: `flutter build apk --debug` produces a fat APK (arm64 + armeabi-v7a +
x86_64) and needs ~4 GB between `build/` and `~/.gradle/caches`. For a phone,
`flutter run` (arm64 only) or `--target-platform android-arm64` is far lighter.

### Enable debugging on the phone

1. **Settings → About phone → Software information** → tap **Build number** 7×.
2. **Settings → Developer options** → enable **USB debugging**.
3. Plug in over USB; accept the **"Allow USB debugging?"** prompt
   (check *Always allow from this computer*).
4. Confirm the host sees it:

   ```bash
   ~/.local/android-sdk/platform-tools/adb devices   # -> "<serial>   device"
   ```

### Run

A physical phone can't reach `localhost` or the emulator's `10.0.2.2`, so the
app must target this machine's **LAN IP**. The backend also has to be reachable
on the LAN (Docker Compose publishes `8080` on `0.0.0.0`, so `make dev` is fine;
just make sure your firewall allows it).

Cleartext HTTP is allowed in every build (`usesCleartextTraffic="true"` in
`android/app/src/main/AndroidManifest.xml`): a server on a home network rarely
has a certificate. See "Server address" below.

Use the helper `./run-android.sh` (local-only, auto-detects LAN IP + device), or
run manually:

```bash
export JAVA_HOME=~/.local/jdk ANDROID_HOME=~/.local/android-sdk
export PATH="$HOME/.local/flutter/bin:$JAVA_HOME/bin:$ANDROID_HOME/platform-tools:$PATH"
LAN_IP=$(ip -4 route get 1.1.1.1 | grep -oP 'src \K[0-9.]+')
flutter run -d "$(adb devices | awk '/\tdevice$/{print $1; exit}')" \
  --dart-define=API_BASE_URL=http://$LAN_IP:8080/api
```

## 3) Quality checks

```bash
flutter analyze
flutter test
```

### E2EE end-to-end test (device + live backend)

`integration_test/e2ee_flow_test.dart` drives the full E2EE lifecycle with
the real client stack — native crypto plugin, repositories, secure storage —
against a running backend: enable migration, blob storage, blind-index
search, client-built date tags, ciphertext-only cache, recovery-phrase
restore, disable migration. It exists because the unit suite runs on the
pure-Dart crypto and mocked HTTP, which cannot catch native-plugin or
wire-contract regressions.

```bash
cd ../homl-web && make db-up && make migrateup && make local   # or make dev
cd ../homl-ui && ./run-e2e-test.sh                             # picks the attached device
```

It registers a throwaway account and saves/restores the developer's local
session and E2EE key around the run, so it is safe on a daily dev phone.
`flutter test` never runs it (integration tests only run explicitly).

## Project layout

```
lib/
├── main.dart          # entry point: bloc observer, logo preload, runApp(App)
├── components/        # reusable widgets (Tag, TagInput, EventCard, Input, dialogs…)
├── data/
│   ├── models/        # json_serializable DTOs (*.g.dart committed)
│   ├── repositories/  # one per backend resource + api.dart (Dio client, refresh)
│   ├── store/         # the data saved for offline use, sealed on the device
│   ├── sync/          # the outbox of offline writes and the sync engine
│   └── transfer/      # the export file format and its password protection
├── helpers/           # cross-cutting logic: e2ee, date_tags, event_search, on_this_day, theme…
├── l10n/              # .arb sources + generated AppLocalizations
├── pages/             # one folder per screen: <page>/bloc (cubit + state) and <page>/view
│                      # pages/app wires the repository + cubit providers and routes on auth status
└── services/          # authentication service and its cubit (session lifecycle)
```

A page owns a `Cubit` and an immutable state; widgets stay dumb and read the
state. Everything that talks to the backend goes through a repository, never
through a widget or a cubit directly — that is also where the offline cache and
the E2EE encrypt/decrypt boundary live.

## Code generation

Both the model serializers and the translations are generated **and
committed**, so a plain `flutter pub get && flutter run` needs no codegen step.
Regenerate after touching a model or an `.arb` file:

```bash
dart run build_runner build --delete-conflicting-outputs   # lib/data/models/*.g.dart
flutter gen-l10n                                           # lib/l10n/app_localizations*.dart
```

Material comes from the `material_ui` package (Flutter 3.47 moved it out of
the SDK and froze the `package:flutter/material.dart` copy): import
`package:material_ui/material_ui.dart`. Every `MaterialApp`, tests included,
takes `appLocalizationsDelegates` (`lib/helpers/localizations.dart`), never the
generated `AppLocalizations.localizationsDelegates`, which still lists
flutter_localizations' delegates: material_ui would find no French or German
`MaterialLocalizations` and throw.

Translations live in `lib/l10n/app_{en,fr,de}.arb` (`app_en.arb` is the
template, see `l10n.yaml`). The three files must stay in sync — `flutter
gen-l10n` reports every key missing from a locale as an untranslated message.
The date tags are the exception that proves the rule — they are stored in
English and translated at display time only (see the insert-tab section
below). The three default categories (Dates, Persons, Others) follow the same
rule: the backend seeds them in English, and
`lib/helpers/category_labels.dart` translates them on screen keyed on
`Category.kind` (Persons only while it still wears the seeded name, since the
user may rename it). The stored name is what every request carries.

## Release builds: keep `--no-tree-shake-icons`

`flutter build web/apk` (release) tree-shakes icon fonts and silently drops
some Font Awesome glyphs that *are* referenced as constants (seen 2026-07-26:
`tag` and `ellipsisVertical` rendered as tofu boxes while `calendar`,
`xmark` and the nav icons survived). Until that is understood, build releases
with `--no-tree-shake-icons`.

## Toasts (user-facing messages)

Every message goes through `showToast` (`lib/helpers/toast.dart`), never
through `ScaffoldMessenger.showSnackBar` directly. On top of the theme's
floating snackbar (on the card color) it owns three behaviours:

- **tap to dismiss**: the whole surface reacts to a tap (hence
  `padding: EdgeInsets.zero` on the SnackBar and the padding inside the
  gesture detector), so the timeout is a fallback, not the only way out;
- **replace, never queue**: each call clears the queue first. Queued toasts
  play one after another, so a listener firing repeatedly (a failed login,
  then every keystroke of the corrected password) left a trail of toasts
  still running long after the screen that produced them;
- **durations**: 3s for confirmations, 5s for errors, `isError: true` for the
  red ones (auth failures only — everything else wears the card color).

Toasts are cleared when the user goes elsewhere, because the messenger lives
on the `MaterialApp`, above the navigator, and a toast otherwise outlives its
screen:

- `ToastRouteObserver` (wired in `MaterialApp.navigatorObservers`) clears on
  every push/pop/replace. Observers are notified synchronously during the
  navigation call, so the navigate-then-confirm flows still work: resolve the
  messenger first, navigate, then `showToastWith` (see the edit flow in
  `lib/pages/insert/insert.dart`);
- the home page clears on tab change, except for the moves it triggers itself
  (`_ownPageChange`) — the "event created" confirmation has to ride along to
  the Search tab.

The blocs that keep a message in their state (`isLoginIncorrect`, a `modal`
code) expose it until the next submit, so their listener needs a `listenWhen`
guard on the *transition* into the message; without it every unrelated
emission (a keystroke) re-shows the toast. The same guard protects the
navigation: `InsertStatus.success` also stays in the state, and the insert
form does keep emitting while it is on screen (the description field notifies
its text when it loses focus on the way out), so a listener reacting to every
state carrying `success` popped the route twice — the second pop took the list
route with it and left a black screen.

## Text inputs (`lib/components/input.dart`)

`Input` wraps a `TextFormField` and drops the validation error of a field the
user emptied when it loses the focus. `FormFieldState.reset()` is the only way
to do that, but it *also* puts the initial text back and re-notifies
`onChanged` with it, so the field is cleared again right after
(`_resetEmptied`): without it an erased description reappeared on blur and the
parent bloc heard a change the user never made.

## Light & dark themes

**Settings → Appearance** picks *System default* (the default), *Light* or
*Dark*. The choice applies at once and belongs to the device, not to the
account: it is saved under `LocalStorageKey.themeMode`, kept across logouts
(account deletion wipes it with every other key) and read in `main.dart`
before the first frame, so a dark choice on a light system never shows a
light frame first (`AppCubit.loadThemeMode` / `updateThemeMode`, the
`MaterialApp` takes `theme`, `darkTheme` and `themeMode`).

Widgets never paint white or black: the colors that depend on the brightness
are a `ThemeExtension`, `HomlColors` in `lib/helpers/theme.dart`, read with
`context.homl` — `ink` (text, icons, the monochrome controls), `card`
(cards, sheets, dialogs, the app bar, toasts), `background`, `field` (filled
inputs), `hairline` and `shadow` (around and under a card), `quiet` (the
selected segment, an off switch) and `rule` (lines that must show).
`homlTheme(brightness:)` builds both themes from them. The light values are
the palette the app always had; the dark ones are not black on white turned
over but a soft white (`#ECECEA`) on deep greys, the cards (`#1D1D1F`) a step
above the background (`#121213`) so they still read as cards. Under a theme
without the extension (a bare `MaterialApp` in a widget test),
`context.homl` falls back to the light colors.

What stays the same in both: the gold accent, the category pastels and the
red of destructive actions. Tag chips, timeline bars and calendar squares
are the pastel at low opacity over whatever surface is under them, so they
dim with it. The square icons of the Categories tab turn over in the dark:
the pastel itself is the icon, over a dimmer square, where the light theme
darkens it.

The logo artwork is drawn black and gold (`assets/images/logo.svg`): its
black strokes are repainted in the theme's ink, so the hash is soft white on
the dark theme (`_LogoColorMapper` in `lib/components/logo.dart`, which also
takes a tag's tint for the gold strokes). The mapper compares by value
because it is part of the SVG cache key: each coloring is parsed once
instead of on every frame of the mark's animations, and `precacheLogo()`
parses the colorings the splash starts with, in both brightnesses.

The native splash has a dark variant too (`color_dark` / `image_dark` in
`pubspec.yaml`, the hash in the dark ink on the dark background, see
`tool/icons/README.md`). It follows the *system* setting: Android and iOS
show it before Flutter runs, when the in-app choice cannot be read yet. With
an appearance forced against the system, the native splash wears the
system's for that moment.

## Categories tab: tag & category management

`lib/pages/categories/view/category_management.dart` gives full CRUD on
categories, tags and synonyms (rules per category kind in
`homl-web/docs/default-categories.md`; only the Dates tags are read-only —
the Others tags are manageable so free tags typed on the insert page can be
sorted into real categories). Each category is an expandable card: a colored
icon, the name and a tag count in the header, the tag chips and a "New tag"
pill in the body; category edit/delete live in the header's "⋮" menu (hidden
for locked categories and in picker mode). `CategoryManagementBody` has two
modes: the management view of the Categories tab (tap or long-press a tag →
its actions menu), and a read-only picker (`showTagPickerSheet`, opened from
the browse button of the tag inputs, and titled "Choose a tag" since the
button no longer says what it opens) where tapping a tag hands it to the
caller. The picker's `showDates` says whether the Dates category is listed:
true on the Search tab (filtering on a month or a year is fair game), false
on the Insert tab, where an event's date tags come from its period and
picking one by hand would either do nothing or fight that derivation.
Destructive actions confirm with the counts served by `GET /tags/:id/usage` /
`GET /categories/:id/usage`:

- a main tag can be renamed, given synonyms, **moved to another category**
  (its synonyms follow) or deleted — the delete dialog says how many events
  use the tag and, as soon as there is one, asks whether to keep them (only
  the tag is removed; it says how many would be left with their date only) or
  delete them all (`deleteEvents` on `DELETE /tags/:id`). Creating, renaming
  or moving onto a name the target category already holds is refused
  (`409 TAG_NAME_CONFLICT`, nothing written) and the toast asks for another
  name — tag names are unique per category;
- a synonym (tap or long press on its chip) can be renamed, detached or
  deleted — deletion confirms that its events are repointed to the main tag;
- a **tag group** (see below) is created from the "New group" pill, next to
  "New tag" (offered once the category has a tag), and edited or deleted
  from its chip;
- deleting a category offers to move its tags to the Others category
  (default, so a hasty confirm loses nothing), delete them while keeping the
  events (those left without another non-date tag keep their date only), or
  delete them together with **every** event tagged from the category —
  whatever other tags it carries. The last option is hidden when no event uses
  the category. Moving is refused (`409 TAG_NAME_CONFLICT`, nothing deleted)
  when Others already holds one of the names, since tag names are unique per
  category: the toast then says to rename the tag or delete the tags instead
  of moving them. The three outcomes are pinned end to end, from the dialog
  down to the SQL: see [../homl-web/TESTING.md](../homl-web/TESTING.md).

### Tag groups

A tag group is a named set of main tags of one category ("Family" = Alice and
Bob) that the tag inputs expand into its tags: it is never chipped, never
linked to an event (`homl-web/docs/tag-groups.md`). In the app:

- the expanded card of a category lists its groups under the tags, each chip
  marked with a stack icon and followed by the tags it holds ("No tags left"
  once they were all deleted);
- the group dialog (`tagGroupDialog`) takes a name and the main tags of the
  category to hold (filter chips, synonyms not offered; saved in the
  category's order). It refuses, before anything is sent, a name reserved for
  the dates and a name already carried by **any** tag or group of the account
  (normalized like the backend): the name is typed in the same field as the
  tags, and two things of one name would make it ambiguous. The server only
  enforces the unique name within the category (`409 TAG_NAME_CONFLICT`,
  toast "this category already has a group with that name");
- group management works offline like the rest of the tab: a group waits in
  the outbox, a tag created offline can join it at once (the group goes once
  the tag has its server id);
- both tag inputs suggest the groups next to the tags (`tagGroupSuggestions`
  in `lib/helpers/tag_groups.dart`): the chip of the group, with the tags it
  adds named on the right instead of a category. Picking it — a tap, or the
  name typed in full then enter — adds its tags that are not chipped yet, and
  a group with nothing left to add is no longer offered. On the Insert tab the
  event gets the tags; on the Search tab each tag becomes a filter, so the
  search keeps its AND semantics and finds the events carrying them all —
  typed behind a `-` (`-Family`), each tag is excluded instead. When
  a tag and a group share a name, enter adds the tag (what was typed) and the
  group stays one tap away in the dropdown;
- the picker sheet lists the groups too: tapping one hands its tags over, as
  if they were picked one by one, and closes the sheet once;
- the app bar mark and the input border follow a group suggestion like a tag
  of its category (the input reports its first tag).

Both tag inputs carry a **browse button** next to the field (a tonal square
the height of the field, wearing the Categories tab's tag icon): it opens the
picker sheet on the Search tab, where tapping a tag inserts it as a search
filter, and on the Insert tab, where it adds the tag to the event (without the
Dates category, as above). It replaced the "#" logo button that used to sit
there: a logo is not an affordance, and the mark it showed now lives in the
app bar (see below).

On the **Insert tab**, a name none of the known tags matches opens a panel
under the field with the categories it can be created in (Dates excluded — the
backend owns those); one tap creates the tag there and chips it on the event,
instead of letting it fall into Others on submit. The panel only opens when
the autocomplete has nothing to offer, so the two never fight for the room
under the field, and ignoring it still works: submitting files the tag under
Others, as it always did.

Submitting a new event slides back to the Search tab (`InsertView.onCreated`,
wired to the home PageView) — the created event is the natural next focus.
Edits pop back to the list instead.

The dialogs owning a `TextEditingController` are `StatefulWidget`s so the
controller is disposed with the route: disposing it from `showDialog`'s
future crashes, the future completes on pop while the dialog is still
animating out.

## The app bar mark

The "#" logo sits at the right of the app bar (`lib/components/app_bar_mark.dart`),
shared by the three tabs and repeated by the edit route's own bar. It is
**never a button** — `IgnorePointer` and `ExcludeSemantics`, no ripple, no
tooltip — and its two gold strokes take the color of the tags in play, which
is the whole point of keeping it on screen:

- priority, highest first: the tag being typed (the top suggestion the input
  reports through `onSuggestionChanged`), then the last chosen tag carrying a
  category color, then the resting two-tone gold. **One color at a time**, so
  a second filter replaces the first rather than splitting the mark;
- a tag that carries no color — an Others tag (its grey never reads as a
  category) or a date tag (the mark already wears the Dates gold) — falls
  through to the chosen tags instead of dropping the mark back to rest in the
  middle of a word. `HomeState.markAccentFor` is the single rule, shared by
  the mark and the input border;
- taking a color on replays the splash reveal (the strokes fill base to tip,
  350 ms); every other change is a plain cross-fade (200 ms), since a second
  reveal on every keystroke would pull the eye away from the field;
- the Categories tab has no tag field, so the mark rests there.

The tags come from the cubits the mark is fed by: `ListCubit.filters` on the
Search tab and `InsertCubit.tagNames` on the Add tab — which is why the insert
cubit is provided by `HomePage` rather than by the tab itself, the app bar
living above the `PageView`. What is being typed travels the other way, from
the input up to a `ValueNotifier<String?>` owned by the page holding the bar
(cleared on a tab change: the field left behind is not what the mark shows).

## Insert tab: the date chips & the month tag language

The insert form (and the edit form, same `InsertView`) opens with two fixed
chips in front of the tag input: the **month** and the **year** of the event.
They are not decorative — they are exactly the two date tags the event ends up
filed under (`buildDateTags` on the backend, `InsertCubit._buildDateTags`
under E2EE), so what the form shows is what the Dates category will hold and
what the search can filter on. Both chips open the date picker, and both
follow the picked date (`leading` of `TagInput` takes a list of widgets).

Tags are optional: an event needs a tag **or** a description, and saving one
with neither says so (`AppMessage.insertEmpty`). Deleting a tag can leave
events without any tag of their own anyway, and they must stay editable. The
two date chips never count, they only file the event.

An event is a single day, a closed period or an open one ("still ongoing"),
picked with the segmented control under the tag input. Its selected segment
wears the palette's grey (`segmentedButtonTheme` in `lib/helpers/theme.dart`):
Material 3 fills it with the scheme's `secondaryContainer`, which the black
seed of `ColorScheme.fromSeed` turns into a washed red — the only warm surface
in an otherwise monochrome app. The chips follow: a closed period adds a third
chip with its end (`→ 5 Jul 2026`, tap it to change the end), an open one the
**Ongoing** chip — the very date tag the event is filed under, translated like
the months. Only the start month is chipped for a closed period, although the
event is filed under every month it covers: a long one would flood the field.
The shape is *derived* from the state (`InsertState.shape`, from `endDate` and
`isOngoing`), never stored: "period" opens the end picker straight away and
only becomes the selected shape once a day is picked, so cancelling leaves the
previous shape, and the form can never rest on "a period without an end". The
end picker starts on the start day and offers nothing before it; moving the
start past an already-picked end drops the end (back to a single day).

The date tags are stored in **English** for every user: they are keys shared
with the backend, and under E2EE the client must be able to rebuild the exact
same names. Translating them is therefore a display-only concern, handled by
`lib/helpers/date_tags.dart`:

- `localizedTagName(name, locale)` returns the app-language month name
  ("juillet", "Juli") for a month tag and the stored name for anything else.
  It is applied wherever a stored tag reaches the screen — the search filters
  and their suggestions, the event detail sheet and the Categories tab;
- `TagChipData.displayName` carries that label next to the stored `name`.
  `TagInput` displays the label, matches the typed text against **both**, and
  always reports the stored `name` to `onAddTag` — a French user typing
  "juillet" (or picking it in the suggestions) filters on `July`, which is
  what the tag names in the events actually are.

`dateTagMonths` (same file) is the single source of the English month names.
`periodDateTagNames` builds the date tags of a whole period from it — every
month and year covered, plus `Ongoing` for an open period, which is tagged
from its start month only — as the mirror of the backend `event.DateTagNames`
(the two share the vector table of `test/event_period_test.dart`); the client
uses it under E2EE, where the server cannot derive the tags itself.
`E2ee.isBlacklistedTag` mirrors the backend blacklist: the month names,
`Ongoing`, and any four-digit name (a year tag — `1984` as a user tag is the
accepted cost of never colliding with one).

## Search tab: the event cards

The events are laid out in a grid of `EventCard`s
(`lib/components/event_card.dart`). A cell is small, so the card decides what
fits:

- the date is the card header, so the month/year date tags are **not** chipped
  — they would only repeat it. The card gets an `isDateTag` predicate from
  `ListPage`, which resolves each tag's category through
  `HomeState.allTagsMap` (the categories fetch, more reliable than the
  category carried by a cached event) and compares it to
  `dateCategoryIds(...)` (`lib/helpers/categories.dart`, shared with the edit
  page);
- a period adds a small pill under the date: how long it lasted (`16 days`,
  `3 months`, `2 years` — inclusive days, then calendar months from 31 days,
  then years from 24 months, see `lib/helpers/event_period.dart`) or
  `Ongoing`. Under the date, not beside it: on a phone-width cell the date
  alone takes most of the line. The pill is deliberately not a `Tag` and must
  not read as one; the rows below are sized from the room left, so it costs
  at most a tag row on a short card. A single day shows no pill — most
  events look exactly as they always did;
- a tag longer than the card is truncated with an ellipsis (`Tag` makes its
  label flexible), so a single very long tag still reads;
- with a description, the tags get every whole row that fits once the
  separator and one line of description are set aside: a second row pushes
  the description down instead of dropping tags, but the description is never
  hidden — at worst it ends up flush with the bottom of the card. Rows are
  clipped whole (`Tag.heightOf` gives the row height), so tags that do not
  fit are simply not shown rather than half-drawn;
- without a description the tags fill the card.

## Search tab: event detail, edit & delete

Tapping an event card opens a bottom sheet
(`lib/pages/list/view/event_detail_sheet.dart`) with the full period, the
regular tags and the whole description (scrollable), plus two actions. The
header is the start date and, for a period, a second line: the end and the
length (`→ Thursday, June 18, 2026 · 16 days`) or, for an open one,
`→ Ongoing · for 2 years` — counted to today at render time, never stored,
and left out until a full day has passed so a start still in the future never
reads as a negative duration. The date tags (months, years, `Ongoing`) are not
chipped, as on the card: the header already carries the period, and a long
one would put a dozen month chips under it.

- **edit** pushes `EditEventPage` (`lib/pages/insert/insert.dart`), which
  reuses `InsertView`/`InsertCubit` in edit mode: `InsertState.fromEvent`
  prefills the form, period included, but excludes the date tags — the
  backend rebuilds them from the period on every update, so sending them back
  in `tagsId` would duplicate them as regular tags. Saving calls
  `PATCH /events/:id` (full state: the description is always sent, even
  empty, which is how it gets erased, and so are `endDate` and `isOngoing`,
  which is how a period turns back into a single day), pops back and
  confirms with a snackbar.
- **delete** asks for confirmation, then calls `DELETE /events/:id`.

Neither action refreshes the list by hand: both repository calls emit on
`EventsRepository.changes`, which `HomeCubit` already listens to (refetch +
offline cache rewrite), and `ListCubit` re-filters from `HomeCubit.stream`.

## Search tab: "On this day" & "Last time"

Two headers above the grid, scrolling with it (`ListPage` is a
`CustomScrollView`: the header slivers, then the grid). Both are worked out
by `ListPage` at render time from the events already in memory — nothing is
stored or asked of the server, so they work offline and for an E2EE account
alike, and are never a day behind.

- **On this day** (`lib/helpers/on_this_day.dart`,
  `lib/pages/list/view/on_this_day_strip.dart`), on the whole list only (no
  term, no range) and in the grid view: a horizontal strip of the events that *started* on today's month and day in
  an earlier year, the most recent first, each card under "1 year ago",
  "10 years ago". The cards are the grid's own `EventCard`s, so a tap opens
  the detail sheet. Only the start counts: a period comes back on the
  anniversary of its first day, never on every day it covers (a five-year
  period would otherwise fill the strip every day for five years). An event
  of 29 February comes back on 28 February in the years without one, never on
  1 March. The current year's events are not memories yet. No memory, no
  strip.
- **Last time** (`lib/helpers/last_time.dart`,
  `lib/pages/list/view/last_time_summary.dart`), once a term or a range
  narrows the list: what the results say about the past.

  ```
  Last time: 14 months ago · Aug 12, 2025
  23 events · 6 this year
  ```

  The last time is the latest day the results covered: the day of a
  single-day event, the end of a closed period. While one of them is still
  going on — an open period, or a closed one not over yet — it reads
  "right now" instead. "Ago" uses the period badge scale (days, then months
  from 31 days, years from 24 months; `agoLabel` in
  `lib/helpers/event_period.dart`), with "today" and "yesterday". Only the
  past counts: an event dated after today is a plan, left out of the counts
  as well, so they can be lower than the number of cards. "This year" counts
  the events that started in the current calendar year. No past result, no
  summary.

## Search tab: the activity calendar

Under the "Last time" summary, a search with a term gets a calendar of its
activity, GitHub style (`lib/pages/list/view/activity_calendar.dart`,
`lib/helpers/activity.dart`): a column per week, Monday to Sunday, a square
per day, the darker the more results that day — one shade per event, four
and more alike (a journal's days rarely hold many). A period counts on every
day it covers, an open one until today.

- **The span**: the last twelve months by default, ending today; the menu on
  the right turns it to any year a result took place in (a past year whole,
  the current one up to today). It scrolls sideways and opens on the most
  recent week; month names sit over the week holding their first day,
  Monday, Wednesday and Friday name their rows.
- **The color** is the category color of the first tag the search asks for
  (an excluded one or an Others tag does not count); the app's gold
  otherwise, for a text search.
- **A tap on a day** narrows the search to it: the usual date chip appears
  and the results below follow. The calendar itself keeps showing what the
  terms find without the day range (`searchEvents` with the terms alone), so
  picking a day never empties it; the picked days are outlined, and a tap on
  the day already picked lifts the range. Each square has a tooltip ("2
  events · Mon, Oct 12, 2026").
- It is worked out at render time from the events in memory, like the rest
  of the tab: offline and E2EE alike.

## Search tab: the timeline

The app bar of the Search tab carries a view switch (`_viewSwitch` in
`lib/pages/home/view/home.dart`, a Gantt icon, a grid icon once switched):
the grid of cards, or the **timeline** of the periods among the same
results (`ListState.timeline`, `ListCubit.toggleTimeline`). The search is
untouched by the switch, so the timeline follows it: `Work` lays the jobs
out, `-Trip` drops the trips, a range keeps the periods overlapping it. The
"Last time" summary stays above it; the "On this day" strip belongs to the
grid. The choice lasts as long as the session.

- **What it shows** (`timelineOf` in `lib/helpers/timeline.dart`): every
  closed or open period, one row each, newest first (by start, then by end).
  An open period runs until today. Single-day events have no length to
  draw: they are left out and counted under the rows ("2 single-day events
  are not shown"). No period at all gives a short explanation of what makes
  one instead.
- **The axis** spans whole years, from 1 January of the earliest start to
  the end of the latest year reached, and fits the screen width: no
  horizontal scrolling. It is pinned on top while the rows scroll, labelled
  every year when the labels fit and otherwise every 2, 5, 10… years on
  round ones (`Timeline.tickYears`). Faint year lines run through the rows,
  and a gold line (a dot on the axis) marks today.
- **A row** (`lib/pages/list/view/period_timeline.dart`) is named by its
  tags without the date tags, like a card without room for chips; then by
  the first line of its description; then by its dates ("Mar 2021 –
  Jun 2021"). Its length sits on the right, on the period badge scale ("3
  years", "for 2 years" while it goes on). The bar wears the color of its
  first tag in a real category; a period with only Others tags, or none, is
  drawn in the neutral grey, as the pale Others grey would vanish on the
  light background. An open period fades out on the right. A bar is at least
  6 px wide, so a few days stay visible on a long axis. A tap opens the
  event's detail sheet, as a card does.
- It is slivers (`SliverMainAxisGroup`) in the page's `CustomScrollView`, so
  the pull to refresh works the same in both views.

## Server address (login screen)

homl is self-hosted, so the app cannot know its server: the user tells it.
`lib/helpers/server_address.dart` holds the address in use (`ServerAddress`),
as an API base URL (`/api` included):

- **Where it comes from.** The address picked on this device
  (`LocalStorageKey.serverUrl`, read in `main.dart` before the first frame),
  else the build's `--dart-define=API_BASE_URL`, else none. With none, the
  login screen's sign-in, sign-up and forgot-password buttons open the server
  dialog first, and a session left by a build that had a default is not
  restored (`Api.restoreSession`): there is no server to renew it with.
- **The dialog** (`lib/pages/login/view/server_dialog.dart`) opens from the
  address shown under the login form. What is typed goes through
  `apiBaseUrlFor`: no scheme means `http://` for an IPv4 address or
  `localhost` and `https://` for a name; `/api` is appended unless already
  there, so `192.168.1.10:8090` becomes `http://192.168.1.10:8090/api` and a
  proxy sub-path is kept. An `http://` address shows a warning as it is
  typed: the password and the session token would cross the network in clear.
- **The check.** Saving asks the `/healthz` next to the address
  (`checkServer`) and keeps the address only when a homl server answers —
  a `503` from a server whose MySQL or Redis is down counts, it is the right
  address. Otherwise the dialog stays open and says why: nothing answers,
  something that is not homl answers (a NAS admin page, a router), or the HTTPS
  certificate is not trusted (self-signed).
- **Switching** (`UsersRepository.changeServer`, signed out only) points the
  Api's Dio client at the new address (`Api.useServer`) without a restart.
  Moving to *another* server also wipes the local store, the changes not sent
  yet included: account ids repeat from one server to the next, and the
  outbox kept "for the same account's next sign-in" (see "Offline mode") must
  not reach a stranger's account that shares the id there.
- **Lifetime.** The address is a setting of the device: kept across logouts
  and account deletion (`LocalStorageManager.clearAll` skips it).
  Settings → About shows it under the versions.

Plain HTTP works in release builds on purpose — Android's main manifest sets
`usesCleartextTraffic`, iOS sets `NSAllowsLocalNetworking` — so a server kept
on the home network needs no certificate.

## Sign-up page: a server that takes no new accounts

An instance can close registration (`REGISTRATION_OPEN=false`, see
`homl-web/docs/deployment.md`). The sign-up page (`lib/pages/register/`)
asks first: `RegisterCubit.checkRegistration()` runs as the page opens and
calls `GET /registration` (`UsersRepository.isRegistrationOpen`). On
`{"open": false}` the form gives way to a short explanation and a "Back to
login" button, before anything is typed. An answer it cannot read —
offline, or a server older than the route — keeps the form, and the sign-up
itself has the last word: a `403 REGISTRATION_CLOSED` becomes a
`RegistrationClosedFailure`, which switches the page to the same
explanation rather than the generic "Registration failed" toast. The login
page keeps its "create an account" link either way: the explanation is
what a visitor of a closed server needs.

## Security page (drawer): password, PIN, fingerprint, delete account

`lib/pages/account/` is the "Security" screen: password change
(`password_dialog.dart`), **Signed-in devices**, the two local unlock factors
(fingerprint / PIN, mutually exclusive), the E2EE toggle, **Export my data** /
**Import data** (see "Data export & import" below), then a destructive group
with **Logout** and **Delete my account**.

**Signed-in devices** (`view/sessions.dart`, `bloc/sessions_cubit.dart`)
lists the account's device sessions from `GET /sessions`: this device first,
then the others with their platform and app version, when they were last
active and signed in, and their address. Each other device has a sign-out
button, and "Sign out all other devices" ends them all; both ask first. It is
online only: without the server the page says so and offers to try again.
What names a device is the `X-Homl-Client` header the `Api` sends with every
request (`clientLabel` in `lib/helpers/version.dart`: the platform, and the
app version when the package info can be read) — nothing else about the
device leaves it.

Deleting the account is irreversible, so it is gated twice: a single dialog
(`delete_account_dialog.dart`) states what is lost *and* asks for the password,
which the backend re-checks (`DELETE /account`, see
[homl-web/docs/api.md](../homl-web/docs/api.md)). A wrong password shows inline
and the dialog stays open.

On success `UsersRepository.deleteAccount` wipes **everything** this device
holds — a superset of logout: `LocalStorageManager.clearAll()` (refresh token,
the local store, the `e2eeMasterKey` seed, the PIN keypair, the fingerprint flag)
plus the biometric entry (`removeStorageFile`). It then emits the
`accountDeleted` authentication status, which `app.dart` turns into
"navigate to login + confirmation toast" — the same shape as `pinLocked`.
The cubit emits nothing on success: the page is disposed by that navigation.

The PIN and fingerprint switches write their local flags (`pinKeypair`,
`isFingerprintEnabled`) only once `PUT /secureAuth` succeeded: those flags
pick the factor the next app start sends, and one that disagrees with the
server — a toggle that failed offline — would get the session refused there.
A PIN the server accepts (here or at unlock) also becomes the one checked
offline (see "Offline mode" below).

## Data export & import

Two rows of the Security page (`data_transfer_group.dart`) copy the account's
data to a JSON file and bring such a file back. File format, password
protection and merge rules: [homl-web/docs/data-export.md](../homl-web/docs/data-export.md).

- `lib/data/transfer/export_file.dart` is the format (`ExportFile`): built
  from the decrypted categories and events, everything referenced by name
  (the tag groups too, by the names of their tags), date tags left out; `fromJson` checks the whole file before anything is
  written. `export_seal.dart` wraps it under a password (PBKDF2 + AES-GCM).
- `DataTransferRepository` exports through the other repositories (offline
  too, from the saved copy) and imports through them as well — so E2EE
  encryption, the client-side date tags and the blacklist apply exactly as
  for the forms. The import refuses to start offline or with changes waiting
  in the outbox, matches categories, tags and tag groups by name, skips the
  events the account already has (re-importing a file changes nothing), and
  stops at the first write the server cannot receive
  (`ImportInterruptedFailure`): running it again finishes it.
- `DataTransferCubit` runs the work and turns failures into toasts; the
  group drives the dialogs (`data_transfer_dialogs.dart`: export options,
  password, confirmation, a progress dialog that cannot be dismissed, the
  report) and the platform pickers (`file_picker`: the Android document
  picker, a download on the web).
- The password switch of the export dialog is on by default for an E2EE
  account, whose file would otherwise hold its data in clear, and turning it
  off says so.

## Offline cache & local search

The Search tab does **not** query the backend per filter change: it searches
the shared in-memory events list locally (`searchEvents` in
`lib/helpers/event_search.dart`), so the search is instant, works offline and
reaches the descriptions of an E2EE account, which only the device can read.
What the field takes (`SearchTerm.parse`):

| Typed | Finds |
| --- | --- |
| `Alice` | a tag: the events carrying it |
| `beach`, when no tag bears that name | the events whose description contains it |
| `"Paris"` | the descriptions only, even with a tag named Paris |
| `-Bob`, `-"beach"` | the events the term does **not** match |

- **Tag or text.** A term is a tag when a tag bears its name, synonyms
  included, and a text otherwise. That is settled at each search, never when
  the term is typed: a term set before the categories load, or before its
  tag exists, finds what it names once they do.
- **Tags** match the way the backend does (`FindEventsWithTags`): names in
  the backend's canonical title case (`normalizeTagName` mirrors
  `application/text.go`), so any typed casing matches, and each name through
  its whole synonym group (`idParentTag ?? id` as the group root, see
  `homl-web/docs/tag-synonyms.md`). An excluded tag leaves its whole group
  out.
- **Texts** match anywhere in the description as one phrase, ignoring case,
  the accents of the Latin letters, curly apostrophes and runs of spaces
  (`foldForSearch`): `cafe by` finds "Café by the sea". Quotes may be the
  typographic ones a phone keyboard types, and the closing one may be left
  out.
- **Dates.** The calendar button after the browse one opens the Material
  date range picker. An event is kept when it took place on one of the
  picked days at least: a period overlapping the range counts, an open one
  runs until today. The range is a gold chip with a calendar icon, first in
  the row; a tap lifts it, a new pick replaces it.
- Every term and the range combine with **AND**.
- **Chips.** A tag term wears its tag's chip, a text term a neutral grey one
  in quotes, an excluded term a ban icon. A tap (or a long press) removes a
  chip, as before. The same term typed the other way round (`-Bob` while
  `Bob` is set) turns its chip over instead of adding a contradiction.
- **The field** (`allowExclusion` on `TagInput`) reads a leading `-`: the
  suggestions and the enter key work on what follows it, and the name it
  reports keeps it (`-Bob`); a group picked behind a `-` excludes each of its
  tags. While a `-` is typed the app bar mark ignores the suggestion, and it
  only ever wears the included tags (`ListState.chosenTagNames`): an excluded
  tag is not what the search is about. The empty field shows an example
  (`-Bob, "beach"`), the `-` first so it survives a cut on a narrow phone.
  The tag sheet adds tags by name (`ListCubit.addTag`), so a tag whose name
  starts with a `-` is still searchable from there.

While typing, the field autocompletes on the existing tags (prefix matches
first, then substring matches); each suggestion is drawn as the chip it would
become, with its category named on the right, so the colors explain
themselves. That name is capped and cut with an ellipsis: a `ListTile` gives
its trailing the whole row, and a long name wrapped across it failed the tile
layout and broke the dropdown. The input border takes the category color of
the top suggestion — except for tags of the Others category, which keep the
default styling (`lib/components/tag_input.dart`, `highlightColor` on
`TagChipData`) — and the app bar mark follows the same suggestion by name
(see above). Both tabs behave alike: the Add tab used to stay colorless,
since it passed no `highlightColor` at all.

The logo is an SVG (`assets/images/logo.svg`) rendered with `flutter_svg`: a
`ColorMapper` repaints only its gold strokes (drawn in the palette's
`yellow`), the black ones stay black. The rest of the app stays monochrome —
buttons, focus borders and the selected nav item are ink, the gold stays in
the logo and small accents.

`EventsRepository.getEvents()`, `CategoriesRepository.getCategories()` and
`SettingsRepository.getSettings()` save each successful payload in the local
store (below). On startup `HomeCubit.init()` serves the saved snapshot first,
then refreshes it from the network; when the network is unavailable the saved
copy is served instead. The store is wiped whenever the local session ends
(logout, rejected refresh token, PIN lockout, account deletion) so another
account on the same device cannot read it. What happens when the server is
out of reach is the next section.

## Offline mode (server out of reach)

Away from the network that reaches the server, the app keeps the session,
runs on the data saved on the device, and keeps working: events, tags,
synonyms, tag groups and categories can be created, edited and deleted; it all
waits in an outbox and is sent once the server answers again. Settings, the
Security page and the import stay online-only ("server unreachable"). The protocol side —
what ends a session, the offline unlock, the trade-off of the offline PIN — is
in [homl-web/docs/auth-flows.md](../homl-web/docs/auth-flows.md), "Client
session"; the outbox and the sync in
[homl-web/docs/offline-sync.md](../homl-web/docs/offline-sync.md).

- **What the user sees**: a cloud-off icon in the app bar while the server is
  unreachable (tap: what it means, and when the data on screen was fetched);
  "server unreachable" instead of "unexpected error" or "incorrect
  credentials" when a request fails for that reason. The app reconnects by
  itself and the icon goes away. Online, pulling the Search list down fetches
  everything again, and coming back to the app after a minute or more does it
  by itself (`HomeCubit.refresh` / `refreshIfStale`). Those reads are
  conditional (`lib/data/store/conditional_get.dart`): the server answers
  "not modified", with no data, when nothing changed since the saved copy.
- **Unlock** respects each account's own factor. No second factor: the saved
  data opens directly. Fingerprint: the same OS prompt as online (releasing the
  keypair is the proof of presence). PIN: the PIN is checked against a hash of
  the last PIN the server accepted on this device, 3 tries like the server's
  lockout; until the PIN was entered once online, the dialog says so instead.
- **`lib/helpers/server_reachability.dart`** — `ServerReachability`, the
  online / offline flag the Api maintains. A plain singleton that needs no
  network stack, so cubits read it to pick their message
  (`AppMessage.requestFailed`) and their tests build without the network stack.
- **`lib/data/repositories/api.dart`** — tells a network failure (keep the
  session, go offline) from a verdict on the session (a `401` on
  `/refresh` / `/challenge`: end it); holds the session's second factor in
  memory for the silent refreshes; probes `/healthz` while offline and in the
  foreground (`onAppResumed` / `onAppPaused`, wired in `app.dart`), then
  reopens the session with a refresh. Requests fail at once for 10 s after a
  network failure, so an offline start does not wait out one timeout per
  request.
- **`lib/helpers/pin_verifier.dart`** — the offline PIN check (PBKDF2-SHA256,
  600 000 iterations — native through cryptography_flutter; the tests lower it)
  and its counter.
- **`lib/data/store/local_store.dart`** — `LocalStore`, the data saved for
  offline use: one entry per payload (events, categories, settings), as the
  server sent it (ciphertext for an E2EE account), each sealed with
  AES-256-GCM under a random device key kept in the secure storage
  (`localStoreKey`), the entry name bound as associated data. Each entry
  records the account it belongs to (the `user_id` of the refresh token):
  one saved by another account is never shown, the whole store is wiped
  instead. An entry also keeps the server's `ETag` of its payload, sent back
  to ask whether it changed. `wipe()` deletes the key first, so a file whose
  deletion failed is unreadable anyway. Failures read as "nothing saved" — it is a cache. The
  payloads the app used to keep in the secure storage are carried over once.
- **`lib/data/store/blob_store*.dart`** — where the sealed entries live: one
  file per entry under the app support directory (`store/<entry>.bin`, written
  next to the target then renamed over it, so a crash never leaves half an
  entry), the browser storage on the web.
- **No OS backup**: the Android manifest sets `allowBackup="false"` and
  `res/xml/data_extraction_rules.xml` excludes the app data from cloud backups
  and device-to-device transfers (the secure storage could not be decrypted
  on another device anyway). On iOS the device key is a "this device only"
  keychain item, so a restored backup holds no readable copy. A new phone
  fetches everything again after the login.
- **Back online**, `HomeCubit` reloads the data and `AuthenticationCubit` runs
  the E2EE gate again on fresh settings.
- **Writing offline** (`lib/data/sync/`): the repositories send a write
  directly when they can, and queue it in the `Outbox` when the server is out
  of reach — or when earlier changes still wait, so nothing overtakes them.
  The form then says "saved on this device". `projection.dart` shows the
  saved data with the waiting changes applied (a small clock on their cards);
  `SyncEngine` sends them once the server answers, merging an edit with what
  changed on another device meanwhile (for events, an edit wins over a
  deletion either way; a tag, category or group edited here but deleted
  elsewhere stays deleted, since the server already took it off its events;
  the same field changed on both sides keeps this device's value — each case
  says so). The app bar counts the waiting changes; its sheet lists them and
  lets the user discard one (with what was made with it), or try again those
  the server refused.
- **Managing offline**: `TagsRepository` and `CategoriesRepository` queue a
  change the way `EventsRepository` does, with the server's last copy as its
  base (`serverTag`, `serverCategory`, `serverGroup` in
  `offline_writes.dart`) and "saved on this device" as the message. A deletion
  "with its events" cannot wait as it is (`DeleteEventsOfflineFailure`):
  `HomeCubit` deletes the events the screen shows one by one, then the tag or
  category alone, so another device's events added meanwhile are never
  deleted unseen. The delete dialogs count from the data on the device while
  changes wait or the server is away (`lib/helpers/local_usage.dart`).
  Logging out with changes waiting asks first; enabling or disabling E2EE
  waits until they are sent.

### Trying it on a phone

Run the app against the dev backend (`./run-android.sh`), then for each kind
of account — no second factor, PIN, fingerprint (Security page), with and
without E2EE:

1. Open the app once online (for a PIN account: enter the PIN, which stores
   the offline hash), browse a bit so the local store is filled, close it.
2. Airplane mode (or `docker stop homlback` on the dev machine). Reopen the
   app: the same unlock as usual, then the journal with the cloud-off icon.
   Search works. Add an event with a new tag, edit it, edit an older event,
   delete another: each says "saved on this device", the cards show a clock,
   the app bar counts the waiting changes.
3. PIN account: three wrong PINs offline lead to the login screen, like the
   server's lockout.
4. Back online (or `docker start homlback`): bring the app to the foreground,
   the icon goes away within seconds, the changes are sent ("your offline
   changes were sent"), the clocks and the count disappear. Tapping the icon
   while offline gives the date of the data on screen; pulling the list down
   while offline says the server is unreachable.
5. Conflicts, with the web app (or `curl`) as the other device: offline,
   edit an event's description on the phone; meanwhile change its date (or
   delete it) on the other device; back online, both changes are kept (or the
   event comes back with the phone's edit), and a message says so.
6. With `ENVIRONMENT=PROD` on the backend (10-minute access tokens), leave a
   PIN or fingerprint session open for more than 10 minutes: it keeps working
   without asking for the factor again.

## End-to-end encryption (opt-in)

An account can be end-to-end encrypted from the Security page (drawer):
tag names,
category names and event descriptions are encrypted on the device with a key
only the user holds, so the server stores ciphertext it cannot read. Design
and wire format: [homl-web/docs/e2ee.md](../homl-web/docs/e2ee.md).

- `lib/helpers/e2ee.dart` (`E2ee` singleton) holds the crypto: a 16-byte seed
  in secure storage (`e2eeMasterKey`, exportable as a 12-word BIP39 recovery
  phrase; it survives logout on purpose, and is wiped only by account
  deletion — there is no data left to unlock), HKDF-derived content and index keys, AES-256-GCM value encryption
  (`e2ee:v1:` blobs) and the tag blind index. It also mirrors the backend tag
  blacklist (`isBlacklistedTag`, over the `dateTagMonths` of
  `lib/helpers/date_tags.dart`), which the server can no longer enforce for
  these users.
- The repositories encrypt on write and decrypt on read at their boundary
  (`events`/`categories`/`tags`), so the rest of the app only sees plaintext;
  the offline caches deliberately store the ciphertext.
- Under E2EE the client builds the month/year date tags itself
  (`InsertCubit`), since the backend can no longer derive them from an
  encrypted event.
- Enabling/disabling runs an atomic whole-dataset migration
  (`E2eeRepository`); after login an encrypted account with no local key is
  blocked on the restore-or-purge screen (`lib/pages/e2ee/`) reached via the
  `e2eeLocked` authentication status.
