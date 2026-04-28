# Labour Attendance App - Implementation Summary

This document serves as a comprehensive overview of the architecture, features, and technical implementations present in the Labour Attendance App.

## 1. Overview
The **Labour Attendance** application is a premium, real-time Flutter app designed to manage construction or workshop labor forces. It handles worker profiles, daily attendance (Full Day, Half Day, Overtime, Absent), "Kharchi" (Advance Payments), and detailed Payroll Summaries. 

## 2. File Structure
The project rigorously adheres to a layered architecture to separate concerns, making the app highly maintainable and scalable.

```text
lib/
├── models/                     # Data models and JSON serialization
│   ├── advance.dart
│   ├── attendance.dart
│   └── worker.dart
├── providers/                  # State Management (ChangeNotifier)
│   ├── attendance_provider.dart
│   ├── summary_provider.dart
│   └── worker_provider.dart
├── screens/                    # UI / View Layer
│   ├── advance_screen.dart     # Records advance payments
│   ├── attendance_screen.dart  # Marks daily attendance & OT
│   ├── home_screen.dart        # Dashboard & Navigation Hub
│   ├── main_screen.dart        # Root shell with persistent BottomNavBar
│   ├── summary_screen.dart     # Payroll reports and totals
│   └── worker_list_screen.dart # "Manage Staff" (Add/Edit workers)
├── services/                   # Backend Integration
│   └── firestore_service.dart  # Encapsulates Firebase SDK calls
├── design_tokens.dart          # Centralized Design System (Colors, Fonts)
├── firebase_options.dart       # Firebase configuration values
└── main.dart                   # Application entry point and MultiProvider wrapper
```

## 3. Total Screens
The app navigates across **five primary screens** hosted within a persistent shell:

1. **Main Screen (`main_screen.dart`)**: Uses an `IndexedStack` wrapping the `BottomNavigationBar` to persist states and prevent bottom navigation from disappearing when switching screens.
2. **Dashboard / Home (`home_screen.dart`)**: Quick overview of the workforce for the day, total wage expenses, and shortcut tiles to navigate to other tabs.
3. **Manage Staff (`worker_list_screen.dart`)**: Adding new workers, defining their daily wage, their specializations, and removing old workers.
4. **Attendance (`attendance_screen.dart`)**: Central hub for selecting a date and marking attendance properties (Full, Half, Absent, plus Overtime Hours) for individual workers. Features a gesture-driven UI (Tap for Present, Long Press for Absent, Swipe Left for Half Day).
5. **Kharchi / Advances (`advance_screen.dart`)**: Keeping track of cash advances given to laborers with automated date filtering.
6. **Reports / Summary (`summary_screen.dart`)**: Selecting a specific date range (e.g., Weekly, Monthly) to view total earnings, total advances, and the net payable amount for each active worker.

## 4. State Management
- **Provider (`ChangeNotifier`)**: The app uses the robust `provider` package to manage state globally where necessary and locally otherwise.
- **`MultiProvider` Injection**: In `main.dart`, we provide `WorkerProvider`, `AttendanceProvider`, and `SummaryProvider` making them accessible to any widget further down the tree.
- **Reactive Updates**: Screens listen to Provider state (`context.watch` or `Consumer`). When a record updates (e.g., a new Attendance is added), Firestore updates the stream, the Provider catches the new data, calls `notifyListeners()`, and the UI seamlessly repaints without blocking the main thread.

## 5. Firestore Integration
- **`FirestoreService`**: Instead of bleeding `FirebaseFirestore.instance` calls directly into UI templates, all database actions are wrapped in `firestore_service.dart`.
- **Collections used**: `workers`, `attendance`, `advances`.
- **Real-time Streams**: Utilizing Firestore Streams (`snapshots()`) meaning any update directly on the database immediately syncs back into the app.
- **Integration Tests**: Tested and validated through `integration_test/firestore_test.dart` to make sure CRU operations correctly commit to the Cloud Firestore backend.

## 6. Code Writing Style & Architecture
- **Design System First**: The entire visual structure is driven by `design_tokens.dart`. All colors use a cohesive Slate/Indigo/Amber palette. Padding, borders, and shadowing strictly use constants from this file (e.g., `AppColors.primary`, `AppBorders.radiusLg`).
- **Data Models**: `lib/models` utilizes strongly-typed Dart 3 models with explicit `fromMap` and `toMap` converters ensuring secure casting when talking to Firestore.
- **Declarative Navigation**: The App moves away from fragile `Navigator.push` actions covering up the Bottom Bar, and instead favors `MainScreenState` indexed routing, yielding a highly professional UX layer.
- **Surgical UI Updates**: Flutter's compositional components are heavily utilized. Reusable layout blocks (like Custom Cards and Data Chips) ensure consistent aesthetics and significantly less boilerplate throughout the `screens/` directory.

## 7. Key Features & Business Logic
- **Gesture-Based Attendance**: Quick gesture actions on the attendance screen: **Tap** for Full Day (Present, Green Check), **Long Press** for Absent (Red X), and **Swipe Left** for Half Day (Orange ½ symbol).
- **Fractional Payroll Calculation**: Half days are calculated as `0.5` working days. The `SummaryProvider` and related UI compute totally aggregated days utilizing `double` types to ensure accurate wage distribution (Salary = Total Days × Daily Wage).
