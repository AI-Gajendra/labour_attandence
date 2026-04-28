# Graph Report - labour-attandance  (2026-04-28)

## Corpus Check
- 45 files · ~90,444 words
- Verdict: corpus is large enough that graph structure adds value.

## Summary
- 232 nodes · 265 edges · 17 communities detected
- Extraction: 95% EXTRACTED · 5% INFERRED · 0% AMBIGUOUS · INFERRED: 12 edges (avg confidence: 0.8)
- Token cost: 0 input · 0 output

## Community Hubs (Navigation)
- [[_COMMUNITY_Community 0|Community 0]]
- [[_COMMUNITY_Community 1|Community 1]]
- [[_COMMUNITY_Community 2|Community 2]]
- [[_COMMUNITY_Community 3|Community 3]]
- [[_COMMUNITY_Community 4|Community 4]]
- [[_COMMUNITY_Community 5|Community 5]]
- [[_COMMUNITY_Community 6|Community 6]]
- [[_COMMUNITY_Community 7|Community 7]]
- [[_COMMUNITY_Community 8|Community 8]]
- [[_COMMUNITY_Community 9|Community 9]]
- [[_COMMUNITY_Community 10|Community 10]]
- [[_COMMUNITY_Community 11|Community 11]]
- [[_COMMUNITY_Community 12|Community 12]]
- [[_COMMUNITY_Community 13|Community 13]]
- [[_COMMUNITY_Community 14|Community 14]]
- [[_COMMUNITY_Community 15|Community 15]]
- [[_COMMUNITY_Community 16|Community 16]]

## God Nodes (most connected - your core abstractions)
1. `package:flutter/material.dart` - 7 edges
2. `../models/worker.dart` - 7 edges
3. `Create()` - 7 edges
4. `AppDelegate` - 6 edges
5. `package:provider/provider.dart` - 6 edges
6. `../providers/worker_provider.dart` - 6 edges
7. `../design_tokens.dart` - 6 edges
8. `Destroy()` - 6 edges
9. `package:flutter/foundation.dart` - 5 edges
10. `package:cloud_firestore/cloud_firestore.dart` - 5 edges

## Surprising Connections (you probably didn't know these)
- `OnCreate()` --calls--> `RegisterPlugins()`  [INFERRED]
  windows\runner\flutter_window.cpp → windows\flutter\generated_plugin_registrant.cc
- `OnCreate()` --calls--> `Show()`  [INFERRED]
  windows\runner\flutter_window.cpp → windows\runner\win32_window.cpp
- `wWinMain()` --calls--> `CreateAndAttachConsole()`  [INFERRED]
  windows\runner\main.cpp → windows\runner\utils.cpp
- `wWinMain()` --calls--> `Create()`  [INFERRED]
  windows\runner\main.cpp → windows\runner\win32_window.cpp
- `wWinMain()` --calls--> `SetQuitOnClose()`  [INFERRED]
  windows\runner\main.cpp → windows\runner\win32_window.cpp

## Communities

### Community 0 - "Community 0"
Cohesion: 0.08
Nodes (26): build, main, MultiProvider, MyApp, SystemUiOverlayStyle, _AttendanceRow, AttendanceScreen, _AttendanceScreenState (+18 more)

### Community 1 - "Community 1"
Cohesion: 0.09
Nodes (21): cleanupTestData, main, DefaultFirebaseOptions, UnsupportedError, AttendanceProvider, reset, nextMonth, prevMonth (+13 more)

### Community 2 - "Community 2"
Cohesion: 0.15
Nodes (19): OnCreate(), RegisterPlugins(), Create(), Destroy(), EnableFullDpiSupportIfAvailable(), GetClientArea(), GetThisFromHandle(), GetWindowClass() (+11 more)

### Community 3 - "Community 3"
Cohesion: 0.11
Nodes (17): advance_screen.dart, AdvanceScreen, build, GestureDetector, HomeScreen, MainScreen, MainScreenState, _NavItem (+9 more)

### Community 4 - "Community 4"
Cohesion: 0.12
Nodes (16): AdvanceScreen, _AdvanceScreenState, _appendDigit, build, Column, Expanded, FirestoreService, Function (+8 more)

### Community 5 - "Community 5"
Cohesion: 0.12
Nodes (15): build, Column, Container, Dialog, _FooterStat, initState, _reload, Scaffold (+7 more)

### Community 6 - "Community 6"
Cohesion: 0.13
Nodes (14): attendance_screen.dart, _ActionTile, _AlertRow, build, Container, GestureDetector, HomeScreen, Icon (+6 more)

### Community 7 - "Community 7"
Cohesion: 0.13
Nodes (14): build, Center, Column, _FormField, GestureDetector, Padding, Scaffold, _showForm (+6 more)

### Community 8 - "Community 8"
Cohesion: 0.13
Nodes (6): dispose, fl_register_plugins(), main(), my_application_activate(), my_application_dispose(), my_application_new()

### Community 9 - "Community 9"
Cohesion: 0.18
Nodes (7): Advance, Attendance, Worker, FirestoreService, ../models/advance.dart, ../models/attendance.dart, package:cloud_firestore/cloud_firestore.dart

### Community 10 - "Community 10"
Cohesion: 0.29
Nodes (2): AppDelegate, FlutterAppDelegate

### Community 11 - "Community 11"
Cohesion: 0.38
Nodes (5): wWinMain(), CreateAndAttachConsole(), GetCommandLineArguments(), Utf8FromUtf16(), SetQuitOnClose()

### Community 12 - "Community 12"
Cohesion: 0.33
Nodes (3): RegisterGeneratedPlugins(), MainFlutterWindow, NSWindow

### Community 13 - "Community 13"
Cohesion: 0.4
Nodes (2): GeneratedPluginRegistrant, -registerWithRegistry

### Community 14 - "Community 14"
Cohesion: 0.4
Nodes (2): RunnerTests, XCTestCase

### Community 15 - "Community 15"
Cohesion: 0.4
Nodes (1): FlutterWindow()

### Community 16 - "Community 16"
Cohesion: 1.0
Nodes (1): MainActivity

## Knowledge Gaps
- **119 isolated node(s):** `MainActivity`, `main`, `cleanupTestData`, `package:flutter_test/flutter_test.dart`, `package:integration_test/integration_test.dart` (+114 more)
  These have ≤1 connection - possible missing edges or undocumented components.
- **Thin community `Community 10`** (7 nodes): `AppDelegate`, `.application()`, `.applicationShouldTerminateAfterLastWindowClosed()`, `.applicationSupportsSecureRestorableState()`, `FlutterAppDelegate`, `AppDelegate.swift`, `AppDelegate.swift`
  Too small to be a meaningful cluster - may be noise or needs more connections extracted.
- **Thin community `Community 13`** (5 nodes): `GeneratedPluginRegistrant.java`, `GeneratedPluginRegistrant`, `.registerWith()`, `-registerWithRegistry`, `GeneratedPluginRegistrant.m`
  Too small to be a meaningful cluster - may be noise or needs more connections extracted.
- **Thin community `Community 14`** (5 nodes): `RunnerTests.swift`, `RunnerTests.swift`, `RunnerTests`, `.testExample()`, `XCTestCase`
  Too small to be a meaningful cluster - may be noise or needs more connections extracted.
- **Thin community `Community 15`** (5 nodes): `FlutterWindow()`, `MessageHandler()`, `OnDestroy()`, `flutter_window.cpp`, `flutter_window.h`
  Too small to be a meaningful cluster - may be noise or needs more connections extracted.
- **Thin community `Community 16`** (2 nodes): `MainActivity.kt`, `MainActivity`
  Too small to be a meaningful cluster - may be noise or needs more connections extracted.

## Suggested Questions
_Questions this graph is uniquely positioned to answer:_

- **Why does `../models/worker.dart` connect `Community 1` to `Community 0`, `Community 4`, `Community 5`, `Community 7`, `Community 9`?**
  _High betweenness centrality (0.112) - this node is a cross-community bridge._
- **Why does `package:flutter/material.dart` connect `Community 0` to `Community 3`, `Community 4`, `Community 5`, `Community 6`, `Community 7`?**
  _High betweenness centrality (0.100) - this node is a cross-community bridge._
- **Why does `dispose` connect `Community 8` to `Community 7`?**
  _High betweenness centrality (0.077) - this node is a cross-community bridge._
- **What connects `MainActivity`, `main`, `cleanupTestData` to the rest of the system?**
  _119 weakly-connected nodes found - possible documentation gaps or missing edges._
- **Should `Community 0` be split into smaller, more focused modules?**
  _Cohesion score 0.08 - nodes in this community are weakly interconnected._
- **Should `Community 1` be split into smaller, more focused modules?**
  _Cohesion score 0.09 - nodes in this community are weakly interconnected._
- **Should `Community 3` be split into smaller, more focused modules?**
  _Cohesion score 0.11 - nodes in this community are weakly interconnected._