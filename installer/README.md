# Windows installer version 2.0.0

The installer is written to `../../dist/VighnahartaBillingSetup-2.0.0.exe`.
It installs the complete Flutter release, Start Menu and optional desktop
shortcuts, an uninstaller, and the bundled Microsoft Visual C++ x64 runtime
when the installed runtime is older than 14.51.36247.

The app connects to the production API configured in `lib/constants.dart`.
The Django backend is hosted separately and is not included in this installer.

## Rebuild

1. Run `flutter build windows --release --build-name=2.0.0 --build-number=2`
   from the Flutter project. Close any app using that build directory first,
   or build a separate copy of the source.
2. Copy all files and subfolders from `build/windows/x64/runner/Release`
   into `../../dist/VighnahartaBilling-2.0.0/app`. Do not copy an obsolete
   release README containing a localhost API address.
3. Copy the Microsoft-signed Visual C++ redistributable version 14.51.36247
   from the installed Visual Studio redistributables into
   `../../dist/VighnahartaBilling-2.0.0/prerequisites/vc_redist.x64.exe`.
4. Open `VighnahartaBilling.iss` in Inno Setup and compile, or run:

   ```powershell
   & 'C:\Program Files\Inno Setup 7\ISCC.exe' .\VighnahartaBilling.iss
   ```

For future releases, update the version, staging paths, output filename, and
runtime requirement as needed. Keep the AppId unchanged so upgrades use the
same installation. A signing certificate is not configured for this project.
