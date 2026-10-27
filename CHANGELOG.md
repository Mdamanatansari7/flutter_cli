## 1.2.0

- Push to GitHub: the first push now asks where the project goes — **Original GitHub** (a new repository on your account, as before) or **Office work** (an existing repository, e.g. your company's: paste its link and the project is pushed there).
- A failed first push to an office repository no longer leaves the project half-connected; the next push asks again.

## 1.1.0

- First public release.
- Interactive menu for new and existing Flutter projects.
- New Project wizard: orientation lock, immersive mode, `.env` loading, ScreenUtil design size per orientation, a Homepage placeholder and an initial git commit.
- Custom settings page: Online or Local setup (backend IP/port and server discovery with Bonsoir), in portrait or landscape, wired into `main.dart`.
- Service generators: HTTP API functions (Dio or `package:http`) and WebSocket services.
- Ready-made pages from `~/.ninjadev/snippets/` and fonts from `~/.ninjadev/fonts/`.
- Push to GitHub with automatic repository creation, plus GitHub account login / switch / logout.
- `ninjadev upgrade` updates from wherever NinjaDev was installed (pub.dev or GitHub).
