# 🎓 Face Attendance — AI-Powered Attendance System

[![Flutter](https://img.shields.io/badge/Flutter-3.13+-blue?logo=flutter)](https://flutter.dev)
[![Firebase](https://img.shields.io/badge/Firebase-Enabled-orange?logo=firebase)](https://firebase.google.com)
[![License](https://img.shields.io/badge/License-MIT-green)](LICENSE)
[![Platform](https://img.shields.io/badge/Platform-Android-brightgreen?logo=android)](https://android.com)

An on-device, privacy-first face recognition attendance system built for Indian colleges. Compliant with the **India DPDP Act 2023**.

---

## ✨ Features

| Feature | Details |
|---------|---------|
| 🔍 Face Detection | Google ML Kit — real-time, multi-face |
| 🧠 Recognition | MobileFaceNet TFLite — on-device, no cloud |
| 🛡️ Anti-Spoofing | Blink/head-turn liveness + texture model |
| 🔐 Privacy | AES-256 encrypted embeddings, never raw photos |
| 📴 Offline-First | SQLite local DB, Firebase sync when online |
| 📊 Reports | Monthly/yearly, PDF/Excel export, low-attendance alerts |
| ✅ DPDP Compliant | Consent screen, delete-on-request, retention policy |
| 👥 Twins/Lookalikes | Manual confirmation + roll-number fallback |
| ⚡ Speed | Row-by-row wide-angle scan, background processing |
| 📝 Audit Log | Every action logged with timestamp and actor |

---

## 🏗️ Architecture

```
face_attendance/
├── lib/
│   ├── core/              # Constants, errors, utils, theme, router
│   ├── data/
│   │   ├── local/         # SQLite DB + local models
│   │   ├── remote/        # Firebase services
│   │   └── repositories/  # Repository implementations
│   ├── domain/
│   │   ├── entities/      # Pure Dart entities
│   │   ├── repositories/  # Abstract interfaces
│   │   └── usecases/      # Business logic
│   ├── features/
│   │   ├── auth/          # Login, role management
│   │   ├── dashboard/     # Home screen, class selection
│   │   ├── enrollment/    # Student face enrollment
│   │   ├── scan/          # Live scan mode
│   │   ├── reports/       # Attendance reports
│   │   ├── manual_override/ # Manual attendance
│   │   └── settings/      # App settings, privacy
│   ├── ml/
│   │   ├── face_detection/   # ML Kit wrapper
│   │   ├── face_recognition/ # MobileFaceNet TFLite
│   │   ├── anti_spoofing/    # Liveness + texture check
│   │   └── embedding/        # Embedding manager
│   ├── services/
│   │   ├── encryption/    # AES-256 encryption
│   │   ├── sync/          # Offline-first sync engine
│   │   ├── export/        # PDF + Excel generation
│   │   ├── notification/  # Local + push notifications
│   │   └── audit/         # Audit log service
│   └── shared/            # Shared widgets, extensions
├── android/               # Android native config
├── assets/
│   ├── models/            # TFLite model files
│   └── images/            # App assets
├── test/                  # Unit, widget, integration tests
└── docs/                  # Architecture docs, DB schema
```

---

## 🚀 Quick Start

### Prerequisites
- Flutter SDK ≥ 3.13
- Android Studio / VS Code
- Firebase project (see setup below)
- Android device/emulator with camera (API 24+)

### 1. Clone the Repository
```bash
git clone https://github.com/Nikhil11Sharma/face-attendance-app.git
cd face-attendance-app
```

### 2. Firebase Setup
```bash
# Install Firebase CLI
npm install -g firebase-tools
firebase login

# Install FlutterFire CLI
dart pub global activate flutterfire_cli

# Configure Firebase for Android
flutterfire configure --project=YOUR_FIREBASE_PROJECT_ID
```

### 3. Add TFLite Models
Download and place in `assets/models/`:
- `mobilefacenet.tflite` — Face recognition model
- `anti_spoof.tflite` — Anti-spoofing texture model

> Models download links in `docs/MODEL_SOURCES.md`

### 4. Install Dependencies
```bash
flutter pub get
flutter pub run build_runner build --delete-conflicting-outputs
```

### 5. Run
```bash
flutter run --release
```

---

## 🗄️ Database Schema

See [`docs/DATABASE_SCHEMA.md`](docs/DATABASE_SCHEMA.md) for full Firestore + SQLite schema.

---

## 🧪 Testing

```bash
# Unit tests
flutter test test/unit/

# Widget tests
flutter test test/widget/

# Integration tests
flutter test integration_test/
```

See [`docs/TESTING_PLAN.md`](docs/TESTING_PLAN.md) for full bias/accuracy testing protocol.

---

## 🔐 Privacy & Compliance

- **India DPDP Act 2023** compliant
- Informed consent before enrollment
- Encrypted face embeddings (AES-256-GCM), never raw photos
- Right to erasure — delete-on-request implemented
- 2-year retention policy with auto-purge
- Manual attendance option for students who decline biometrics
- Role-based access: Teacher, HOD, Admin

---

## 📊 Threshold Tuning

| Similarity | Action |
|-----------|--------|
| ≥ 0.82 | ✅ Auto-present |
| 0.65–0.82 | ⚠️ Needs review |
| < 0.65 | ❌ Unrecognized |

See [`docs/THRESHOLD_TUNING.md`](docs/THRESHOLD_TUNING.md) for FAR/FRR calibration guide.

---

## 📦 Tech Stack

| Layer | Technology |
|-------|-----------|
| UI | Flutter 3.13, Material 3 |
| State | BLoC / Cubit |
| Navigation | GoRouter |
| Face Detection | Google ML Kit |
| Face Recognition | MobileFaceNet (TFLite) |
| Anti-Spoofing | Custom TFLite texture model |
| Local DB | SQLite (sqflite) |
| Remote DB | Firebase Firestore |
| Auth | Firebase Auth |
| Encryption | AES-256-GCM (encrypt package) |
| Export | PDF (pdf pkg), Excel (excel pkg) |
| DI | GetIt + Injectable |

---

## 🤝 Contributing

1. Fork the repo
2. Create feature branch: `git checkout -b feature/your-feature`
3. Commit: `git commit -m 'feat: add your feature'`
4. Push: `git push origin feature/your-feature`
5. Open a Pull Request

---

## 📄 License

MIT License — see [LICENSE](LICENSE)

---

## 👨‍💻 Built With ❤️ for Indian Colleges
