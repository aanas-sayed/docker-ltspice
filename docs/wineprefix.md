# Wine prefix

A Wine prefix is the directory Wine uses to emulate a Windows install for one user. It's a self-contained fake `C:\` plus a fake Windows registry, stored as regular Linux files in a single folder.

## Layout

```
$WINEPREFIX/
├── drive_c/              ← fake C: drive
│   ├── windows/          ← fake C:\Windows (system DLLs, fonts)
│   ├── Program Files/    ← where Windows apps install themselves
│   ├── users/<name>/     ← fake C:\Users\<name> (Desktop, AppData, Temp)
│   └── ProgramData/
├── dosdevices/
│   ├── c: -> ../drive_c
│   └── z: -> /           ← Z: maps to the Linux root, the trick that
│                            lets `Z:\sim\foo.net` mean `/sim/foo.net`
├── system.reg            ← fake HKEY_LOCAL_MACHINE
├── user.reg              ← fake HKEY_CURRENT_USER
└── userdef.reg           ← fake HKEY_USERS\.Default
```

## What it's for

When Wine runs a Windows `.exe`, the `.exe` asks Windows things like "where is `C:\Program Files`?", "what's in the registry under `HKLM\Software\X`?", "give me `%TEMP%`." Wine answers by reading files inside the prefix. The prefix is the per-user state of "Windows."

A prefix is created the first time you run `wineboot` (or any `wine` command) — Wine generates a default skeleton with system DLLs. When you install a Windows app via `wine msiexec /i installer.msi`, the installer writes files into `drive_c/Program Files/...` and registry entries into `system.reg` / `user.reg` **inside that prefix.** That on-disk state is what makes the app "installed."

You can have many prefixes — `WINEPREFIX=/some/other/dir` gives you a separate fake Windows. Used to isolate finicky apps from each other.

## Why this image cares

Wine has a check at every invocation: `stat($WINEPREFIX).st_uid != getuid()` → hard refusal with `wine: '<prefix>' is not owned by you`. The prefix must be owned by the running uid.

That single check is the reason for the prefix-template design:

- The image runs as `wineuser` (uid 1000) by default, but supports `docker run --user=$(id -u):$(id -g)` for arbitrary host uids.
- If we shipped a prefix at `/home/wineuser/.wine` owned by uid 1000, any `--user` value other than 1000 would fail Wine's owner check, and we can't `chown` at runtime under `--cap-drop=ALL`.
- So the build splits the prefix into a **uid-agnostic template** at `/opt/wineprefix-template`, and the entrypoint `cp -a --no-preserve=ownership` it into `/tmp/wine-prefix` on every container start. The copy inherits the running uid → owner check passes for any uid.

## What's in this image's prefix

- A fully installed LTspice — except its 1.7 GB install was moved out to `/opt/ltspice` and replaced with a relative symlink at `drive_c/Program Files/ADI/LTspice`. Wine still sees it at `C:\Program Files\ADI\LTspice`; the registry entries written by `msiexec` still resolve.
- The `Z: -> /` symlink under `dosdevices/`, which is what lets callers pass `Z:\sim\foo.net` to LTspice.
- The registry entries from the LTspice install (file associations, COM registration).

The prefix at `/tmp/wine-prefix` is per-container — anything written into it during a run (Wine timestamp updates, LTspice config) is discarded when the container exits. For batch simulation that's the right default; for "develop interactively in the container," preferences reset on every start.
