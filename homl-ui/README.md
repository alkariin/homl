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

`EventsRepository.getEvents()` and `CategoriesRepository.getCategories()`
cache each successful payload in `flutter_secure_storage` (encrypted at
rest). On startup `HomeCubit.init()` serves the cached snapshot first, then
refreshes it from the network; when the network is unavailable the cached
copy is served instead. The caches are cleared whenever the local session
ends (logout, rejected refresh token, PIN lockout) so another account on the
same device cannot read them.

Writes (creating events/tags) still require the network; offline is
read-only for now.
