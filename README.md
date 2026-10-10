# beammp-linux

Native Linux build recipe and helpers for the [BeamMP](https://beammp.com) client
launcher for **BeamNG.drive**.

BeamMP does not ship a prebuilt Linux launcher, and its documented Linux build
path (vcpkg + OpenSSL built from source) is slow and error-prone. This repo has a
small script that builds the official upstream launcher from source against your
distro's system libraries in a couple of minutes, plus a session monitor and a
desktop-entry installer.

## What's here

| File | Purpose |
| --- | --- |
| `update-beammp.sh` | Fetch the latest upstream BeamMP-Launcher release and build + install it. |
| `monitor-session.sh` | Watch the BeamNG/BeamMP logs during a session and write a summary. |
| `install-desktop.sh` | Create application-menu and Desktop shortcuts. |
| `desktop/beammp.desktop.in` | Template used by `install-desktop.sh`. |
| `LICENSE` | MIT (covers these scripts only). |

## Requirements

- A Debian/Ubuntu-style distro (tested on **Ubuntu 26.04**).
- Build dependencies:

  ```bash
  sudo apt install build-essential cmake git curl \
      libcurl4-openssl-dev libssl-dev zlib1g-dev nlohmann-json3-dev
  ```

  You do **not** need `libcpp-httplib-dev` — the script fetches the header-only
  `cpp-httplib` itself.
- BeamNG.drive installed (via Steam).

## Quick start

```bash
git clone https://github.com/slippers/beammp-linux.git
cd beammp-linux

./update-beammp.sh      # builds and installs ~/beammp-launcher/BeamMP-Launcher
./install-desktop.sh    # optional: app-menu + Desktop shortcut
```

Then launch **BeamMP** from the application menu or your Desktop.

To update after a new BeamMP release, just re-run `./update-beammp.sh`.

> The launcher must stay running while you play — keep its window open.

## Why it builds this way (the workaround)

Upstream expects `find_package(httplib)` (normally supplied by vcpkg). Debian and
Ubuntu's `libcpp-httplib-dev` has no CMake config and ships a declaration-only
header built with conflicting feature macros, so `update-beammp.sh`:

1. downloads the header-only `httplib.h` (pinned to a known-good release) into
   `third_party/httplib`,
2. supplies a tiny `httplibConfig.cmake` shim defining the `httplib::httplib`
   imported target, and
3. adds `httplib::httplib` to the CMake link line.

It also builds **Debug** on purpose, per upstream's note about a Linux
"connect once per run" bug.

## Monitoring a session

```bash
./monitor-session.sh
```

It writes `~/beammp-launcher/session-events.log` while you play and
`~/beammp-launcher/session-summary.txt` when the game closes. You can start it
**before** launching BeamMP — it waits for the game to appear.

## Caveats

- **Auto-update is not implemented** in the Linux launcher upstream — that is
  exactly why `update-beammp.sh` exists. Re-run it after each BeamMP release.
- On Linux the launcher can, per upstream, connect to a server only **once per
  run**. Relaunch to join a different server.
- Guest authentication occasionally retries several times
  ("Trying to logon as guest…") before it succeeds. If it hangs on the login
  screen, do a clean restart of the launcher **and** the game.
- On hybrid-GPU laptops BeamNG automatically selects the discrete GPU (it looks
  for a Vulkan device of type `Discrete`).

## License & attribution

The scripts in this repository are **MIT**-licensed — see [`LICENSE`](LICENSE).

`BeamMP-Launcher` itself is **AGPL-3.0** and is **not** redistributed here:
`update-beammp.sh` clones and builds it from the official upstream repository. If
you redistribute a compiled launcher binary, you must comply with the AGPL-3.0
(e.g. provide the corresponding source). The BeamMP game mod (`beammp.zip`) is
downloaded by the launcher from BeamMP's servers and is not included.

Tested with: Ubuntu 26.04, BeamNG.drive 0.39.4, BeamMP-Launcher 2.8.1,
cpp-httplib 0.26.0.
