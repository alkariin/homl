# homl-ui frontend

## 1) Install dependencies

```bash
flutter pub get
```

## 2) Run (required API_BASE_URL)

```bash
flutter run -d chrome --dart-define=API_BASE_URL=http://localhost:8080/api
```

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

Cleartext HTTP to the dev backend is enabled for **debug builds only** via
`android/app/src/debug/AndroidManifest.xml` (`usesCleartextTraffic="true"`).

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

## Categories tab: tag & category management

`lib/pages/categories/view/category_management.dart` gives full CRUD on
categories, tags and synonyms (rules per category kind in
`homl-web/docs/default-categories.md`; only the Dates tags are read-only —
the Others tags are manageable so free tags typed on the insert page can be
sorted into real categories). `CategoryManagementBody` has two modes: the
management view of the Categories tab (tap or long-press a tag → its actions
menu), and a read-only picker (`showTagPickerSheet`, opened from the "#" logo
of the tag inputs) where tapping a tag hands it to the caller. Destructive
actions confirm with the counts served by `GET /tags/:id/usage` /
`GET /categories/:id/usage`:

- a main tag can be renamed, given synonyms, **moved to another category**
  (its synonyms follow) or deleted — the delete dialog says how many events
  use the tag and lets the user delete the events that only carry this tag or
  keep them with their date only (`deleteEvents` on `DELETE /tags/:id`);
- a synonym (tap or long press on its chip) can be renamed, detached or
  deleted — deletion confirms that its events are repointed to the main tag;
- deleting a category offers to move its tags to the Others category
  (default), delete them while keeping the events, or delete them together
  with the events that only use tags from this category.

The "#" logo next to the tag inputs is a button:

- **Search tab**: opens the tag picker sheet; tapping a tag inserts it as a
  search filter.
- **Insert tab**: with an empty field it opens the same picker (tap a tag to
  add it to the event); with a **new** tag typed it asks which category the
  tag belongs to, creates it there and chips it on the event (instead of
  letting it fall into Others on submit); with an existing tag typed it does
  nothing.

The dialogs owning a `TextEditingController` are `StatefulWidget`s so the
controller is disposed with the route: disposing it from `showDialog`'s
future crashes, the future completes on pop while the dialog is still
animating out.

## Search tab: event detail, edit & delete

Tapping an event card opens a bottom sheet
(`lib/pages/list/view/event_detail_sheet.dart`) with the full date, all the
tags and the whole description (scrollable), plus two actions:

- **edit** pushes `EditEventPage` (`lib/pages/insert/insert.dart`), which
  reuses `InsertView`/`InsertCubit` in edit mode: `InsertState.fromEvent`
  prefills the form but excludes the month/year date tags — the backend
  rebuilds them from the date on every update, so sending them back in
  `tagsId` would duplicate them as regular tags. Saving calls
  `PATCH /events/:id` (full state: the description is always sent, even
  empty, which is how it gets erased), pops back and confirms with a
  snackbar.
- **delete** asks for confirmation, then calls `DELETE /events/:id`.

Neither action refreshes the list by hand: both repository calls emit on
`EventsRepository.changes`, which `HomeCubit` already listens to (refetch +
offline cache rewrite), and `ListCubit` re-filters from `HomeCubit.stream`.

## Offline cache & local search

The Search tab does **not** query the backend per filter change: it filters
the shared in-memory events list locally, so the search is instant and works
offline. The matching replicates the backend one (`FindEventsWithTags`):

- filter names are normalized to the backend's canonical title case
  (`lib/helpers/event_search.dart` mirrors `application/text.go`), so any
  typed casing matches;
- each name matches through its whole synonym group
  (`idParentTag ?? id` as the group root, see
  `homl-web/docs/tag-synonyms.md`);
- multiple filters use AND semantics.

While typing, the field autocompletes on the existing tags (prefix matches
first, then substring matches). The input border and the "#" logo take the
category color of the top suggestion — except for tags of the Others
category, which keep the default styling (`lib/components/tag_input.dart`,
`highlightColor` on `TagChipData`). The logo is an SVG
(`assets/images/logo.svg`) rendered with `flutter_svg`: a `ColorMapper`
repaints only its gold strokes (drawn in the palette's `yellow`), the black
ones stay black.

`EventsRepository.getEvents()` and `CategoriesRepository.getCategories()`
cache each successful payload in `flutter_secure_storage` (encrypted at
rest). On startup `HomeCubit.init()` serves the cached snapshot first, then
refreshes it from the network; when the network is unavailable the cached
copy is served instead. The caches are cleared whenever the local session
ends (logout, rejected refresh token, PIN lockout) so another account on the
same device cannot read them.

Writes (creating events/tags) still require the network; offline is
read-only for now.

## End-to-end encryption (opt-in)

An account can be end-to-end encrypted from the Account page: tag names,
category names and event descriptions are encrypted on the device with a key
only the user holds, so the server stores ciphertext it cannot read. Design
and wire format: [homl-web/docs/e2ee.md](../homl-web/docs/e2ee.md).

- `lib/helpers/e2ee.dart` (`E2ee` singleton) holds the crypto: a 16-byte seed
  in secure storage (`e2eeMasterKey`, exportable as a 12-word BIP39 recovery
  phrase), HKDF-derived content and index keys, AES-256-GCM value encryption
  (`e2ee:v1:` blobs) and the tag blind index. It also mirrors the backend tag
  blacklist and English month names, which the server can no longer enforce
  for these users.
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
