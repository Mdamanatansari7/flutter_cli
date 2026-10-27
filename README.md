# NinjaDev — Flutter CLI

[![pub package](https://img.shields.io/pub/v/ninjadev.svg)](https://pub.dev/packages/ninjadev)
[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](LICENSE)
[![Dart](https://img.shields.io/badge/Dart-3.2%2B-blue)](https://dart.dev)
[![Flutter](https://img.shields.io/badge/Flutter-3.29%2B-blue)](https://flutter.dev)

**NinjaDev** is an interactive command-line tool that sets up Flutter projects and writes the boilerplate around them — the starter `main.dart`, a mode/settings page, API and WebSocket services, ready-made pages, assets and fonts, and publishing to GitHub — so you can focus on your app's UI and logic.

## Requirements

- [Flutter](https://docs.flutter.dev/get-started/install) 3.29 or newer (comes with Dart)
- [Git](https://git-scm.com/)
- [GitHub CLI](https://cli.github.com/) — only for the GitHub options; NinjaDev offers to install it (Homebrew on macOS/Linux, winget on Windows) when it's missing

## Install

```bash
dart pub global activate ninjadev
```

Or straight from GitHub, to get the very latest code:

```bash
dart pub global activate --source git https://github.com/Mdamanatansari7/flutter_cli.git
```

Make sure pub's global `bin` folder is on your `PATH`:

- **macOS / Linux** — add this line to `~/.zshrc` or `~/.bashrc`:
  ```bash
  export PATH="$PATH:$HOME/.pub-cache/bin"
  ```
- **Windows** — add `%LOCALAPPDATA%\Pub\Cache\bin` to your `PATH`.

Then check it works:

```bash
ninjadev --version
```

Update to the latest version with `ninjadev upgrade`; uninstall with `dart pub global deactivate ninjadev`.

## Quick start

```bash
ninjadev
```

This opens the interactive menu. Pick **New Project** to create an app, or run it inside a Flutter project and pick **Existing Project**. Use the arrow keys to move and Enter to select.

## New Project

The wizard checks that Flutter, Dart and Git are installed, then asks for the project name, organization (bundle id), description, target platforms and device orientation (portrait, landscape or both). You get a normal `flutter create` project, plus:

- `lib/main.dart` with the orientation lock, immersive mode, `.env` loading ([flutter_dotenv](https://pub.dev/packages/flutter_dotenv)) and [ScreenUtil](https://pub.dev/packages/flutter_screenutil) (design size 835 × 1194, or 1194 × 835 for landscape)
- `lib/pages/Homepage.dart` as a placeholder first screen
- a `.env` file, a git repository with an initial commit, and `flutter pub get` already run

The same without the wizard:

```bash
ninjadev create my_app --org com.example --platform ios,android --orientation landscape --yes
```

## Existing Project

| Option | What it does |
| --- | --- |
| Asset folders | Creates `assets/<folder>/` (images, icons, …) and registers it in `pubspec.yaml`. **fonts** copies every `.ttf` from `~/.ninjadev/fonts/` into the project and registers the font families. |
| Lib folders | Creates folders under `lib/` (screens, pages, …). |
| Service files | Empty service stubs, an **HTTP API function** generator (Dio or `package:http`, optional `.env` base URL, headers, body and query parameters), or a **WebSocket service** (`web_socket_channel` or `dart:io`, heartbeat, auto-reconnect). |
| Ready-made pages | Copies your own `.dart` pages from `~/.ninjadev/snippets/` into the project, adds the packages they import, and the iOS/Android permissions those packages need. |
| Custom settings page | A TESTING / LIVE mode page. **Online** setup, or **Local** setup with the backend IP and port plus server discovery on the local network ([Bonsoir](https://pub.dev/packages/bonsoir)), in portrait or landscape. `main.dart` is wired to the setup you pick. |
| Device orientation | Changes the orientation lock (and the ScreenUtil design size) in `main.dart`. |
| Push to GitHub | The first push asks where the project goes: **Original GitHub** creates a new repository under your account, **Office work** pushes to an existing repository — paste its link (for example your company's). Later pushes bump the version in `pubspec.yaml`, commit and push. |
| GitHub account | First asks which account: **Original GitHub** (your own) or **Office work** (your office account — paste your office GitHub link, e.g. `https://github.com/company`, or your company's own GitHub server). Log in to it, make it the active one, or log out. Pushes use the matching account. |
| Create .env file | Adds a starter `.env` file. |

## Commands

| Command | Description |
| --- | --- |
| `ninjadev create [name]` | Create a new Flutter project |
| `ninjadev generate <type> [name]` | Generate code — `feature`, `screen`, `widget`, `model`, `api`, `theme`, `settings`, `repository`, `bloc`, `cubit`, `provider`, `controller` |
| `ninjadev add <package>` | Add packages to `pubspec.yaml` |
| `ninjadev remove <package>` | Remove packages from `pubspec.yaml` |
| `ninjadev doctor` | Check Flutter, Dart, Git, IDEs and connected devices |
| `ninjadev deploy` | Build a Flutter release |
| `ninjadev init` | Initialize NinjaDev configuration in the current project |
| `ninjadev config` | Manage NinjaDev configuration |
| `ninjadev list` | List packages and generators |
| `ninjadev template` | Manage project templates |
| `ninjadev upgrade` | Update NinjaDev to the latest version from GitHub |
| `ninjadev completion <shell>` | Print a completion script for `bash`, `zsh`, `fish` or `powershell` |

Run `ninjadev <command> --help` to see a command's options. For example, the settings page can also be generated directly:

```bash
ninjadev generate settings --setup local --orientation landscape --path lib/screens
```

## Your own fonts and pages

- `~/.ninjadev/fonts/` — put `.ttf` files here once; **Asset folders → fonts** copies them into every project.
- `~/.ninjadev/snippets/` — put ready-made `.dart` pages here; they show up under **Ready-made pages**.

New files in either folder are picked up right away — nothing to rebuild.

## Development

```bash
git clone https://github.com/Mdamanatansari7/flutter_cli.git
cd flutter_cli
dart pub get
dart run bin/ninjadev.dart   # run from source
dart test
```

To use your checkout as the global `ninjadev`:

```bash
dart pub global activate --source path .
```

The global command runs a cached build, so after changing the code delete that cache once and the next run rebuilds it:

```bash
rm -rf .dart_tool/pub/bin/ninjadev
```

## Contributing

Issues and pull requests are welcome at [github.com/Mdamanatansari7/flutter_cli](https://github.com/Mdamanatansari7/flutter_cli/issues).

1. Fork the repository
2. Create a branch: `git checkout -b feature/my-feature`
3. Commit your changes and open a pull request

## License

MIT — see [LICENSE](LICENSE). Free to use, modify and share.
