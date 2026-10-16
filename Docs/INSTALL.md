# Install / share Mac Explorer

The GitHub repo is **public**: https://github.com/underteo/Mac-Explorer  
Source is readable; redistribution of binaries you build is still governed by `LICENSE`.

Do **not** commit `.app` / `.zip` into git (`dist/` is gitignored). Publish packages via **GitHub Releases**.

## You (developer): create a shareable zip

On your Mac (Xcode installed):

```bash
cd "/path/to/Mac Explorer"
./scripts/package_app.sh
# → dist/Mac Explorer.app
# → dist/MacExplorer-macOS.zip
```

Then either:

1. **Release (preferred)** — tag and push, Actions attaches the zip:

   ```bash
   git tag v0.1.0
   git push origin v0.1.0
   ```

   Or: GitHub → **Actions** → **Package** → **Run workflow** (optional tag name).

2. **Send the zip directly** — attach `dist/MacExplorer-macOS.zip` (AirDrop, Drive, …).

Local daily use on *your* machine stays:

```bash
./scripts/install_to_applications.sh   # signed Apple Development → /Applications
```

## Someone else (end user): install from a zip / Release

Requirements: **Mac with macOS Tahoe 26+**.

1. Download `MacExplorer-macOS.zip` from the [Releases](https://github.com/underteo/Mac-Explorer/releases) page (or the file you sent).
2. Unzip.
3. Drag **Mac Explorer.app** into **Applications**.
4. First open: **right-click the app → Open** → confirm (ad-hoc signature; Gatekeeper will warn once).
5. Optional: System Settings → Privacy → Full Disk Access → enable Mac Explorer if they need protected folders.

**Message you can paste:**

> Ecco Mac Explorer (macOS 26+). Scarica lo zip dal Release / allegato, scompatta, metti `Mac Explorer.app` in Applicazioni. Al primo avvio: tasto destro → Apri. Non servono Xcode né account GitHub.

## From source (developers only)

```bash
git clone https://github.com/underteo/Mac-Explorer.git
cd Mac-Explorer
./scripts/build.sh
# or open MacExplorer.xcodeproj and ⌘R
```

## Notes

- Packaged builds are **ad-hoc signed** until you add Developer ID + notarization.
- Plugins are **not** inside the `.app`; the app creates an empty Plugins folder on first launch.
