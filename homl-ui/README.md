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

## 3) Quality checks

```bash
flutter analyze
flutter test
```
