# Iconia Print Helper

Standalone Dart CLI sidecar for Iconia Restaurant Web POS thermal printing.

The web app writes print jobs to:

```text
/restaurants/{restaurantId}/print_queue/{jobId}
```

This helper polls pending jobs, reads active network printer destinations from
the restaurant's Firestore `printers` collection, renders ESC/POS bytes, and
dispatches them to the matching printer backend.

The Firebase-hosted web app does not launch this helper. Each restaurant that
uses network thermal printers installs one helper on its cashier computer. The
helper starts with that computer and only listens to the `restaurantId` in its
local private configuration.

## Setup

1. Create a dedicated Firebase Auth user for the helper.
   - Firebase Console -> Authentication -> Users -> Add user
   - Example email: `print-helper@iconia.local`
   - Use a strong password.
   - Do not use this account to sign in to the web app UI.

2. Find the Firebase Web API key.
   - Firebase Console -> Project Settings -> General -> Web API Key

3. Create local config.

```bash
cd print_helper
cp config.example.json config.json
```

Edit `config.json`:

- `firebase.projectId`: Firebase project ID
- `firebase.apiKey`: Firebase Web API key
- `firebase.email`: helper user email
- `firebase.password`: helper user password
- `helperId`: unique name for this cashier machine, for example `cashier-main`
- `restaurantId`: restaurant document ID from Firestore
- `printers`: optional local-only mappings, used for fake-printer testing or
  temporary migration fallback

For fake-printer testing, retain an entry such as:

```json
{
  "id": "fake-printer-1",
  "name": "Fake Printer (testing)",
  "backend": "fake",
  "outputFile": "./prints/output.txt"
}
```

For real network printers, do not copy printer IDs or IP addresses into this
file. Add and edit them in the web app's Printers screen. The helper
automatically loads active Network printer IDs, IP addresses, and ports from
Firestore. A local entry with the same ID is overridden by the web app record.

4. Grant the helper user restaurant membership.

The existing membership rules cover `print_queue` if the helper user has a membership document:

```text
/users/{helperUid}/memberships/{restaurantId}
```

Use role `system`. This role is restricted by Firestore rules to print queue
processing, helper heartbeat, and printer status writes; it cannot access POS
business data such as customers, reports, or cash drawer records.

5. Install dependencies and run.

```bash
dart pub get
dart run bin/print_helper.dart
```

You can pass a custom config path:

```bash
dart run bin/print_helper.dart path/to/config.json
```

Expected startup output includes:

```text
Helper started
Listening for jobs
Printer Kitchen Network Printer (...) online
```

While running, the helper writes:

```text
/restaurants/{restaurantId}/print_helper/{helperId}
/restaurants/{restaurantId}/printer_status/{printerId}
```

The web app Printers screen uses those documents to show helper presence and live
printer reachability. Keep the helper running on the cashier machine for silent
thermal printing.

`config.json` contains helper credentials and restaurant binding information.
It is ignored by source control and must remain private on the cashier
computer.

## Test With Fake Printer

1. Run the helper.
2. Open the web app.
3. Complete an order.
4. Click `Print Bill` or `Print KOT` on the receipt screen.
5. Watch the helper logs for job processing and the `PRINT PREVIEW` block.
6. Inspect `print_helper/prints/output.txt`.

The fake backend appends a printable view and raw hex dump for each print job.
For real network printers, the helper also logs a readable logical receipt
before sending bytes. Arabic in that preview is the exact logical text sent
through PC1001; if the preview reads correctly but the paper does not, the
remaining issue is the printer code-page/firmware setting rather than invoice
data.

## Network Printer

Use a printer that accepts raw ESC/POS over TCP, commonly port `9100`.

Add the printer in the web app as type `Network`, with its LAN IP address and
port (normally `9100`). The running helper refreshes active network printer
records automatically and publishes its reachability check back to the
Printers screen. Printer IDs are managed by Firestore and do not need to be
entered on the cashier machine.

For printers that support Arabic via PC1001, the network helper uses the
confirmed `ESC t 21` code page for Arabic receipt/KOT text.

## Production Installation

For development, run:

```bash
dart run bin/print_helper.dart
```

For a restaurant deployment, install the helper as an auto-start background
process. The installer accepts either a precompiled native executable or
compiles one locally when the Dart SDK is present.

Build release binaries on the matching operating system:

```bash
# macOS
dart compile exe bin/print_helper.dart -o iconia_print_helper
```

```powershell
# Windows
dart compile exe bin\print_helper.dart -o iconia_print_helper.exe
```

### macOS Auto-Start

Prepare a private `config.json`, then run:

```bash
chmod +x install/macos/install.sh install/macos/uninstall.sh
./install/macos/install.sh /path/to/config.json /path/to/iconia_print_helper
```

If the second argument is omitted, the installer compiles the binary locally.
It installs a LaunchAgent that starts on user login and restarts the helper if
it exits.

Installed files:

```text
~/Library/Application Support/Iconia Print Helper/
~/Library/LaunchAgents/com.iconia.print-helper.plist
```

Uninstall auto-start:

```bash
./install/macos/uninstall.sh
```

### Windows Auto-Start

Run PowerShell as Administrator:

```powershell
.\install\windows\install.ps1 `
  -ConfigPath "C:\Setup\config.json" `
  -BinaryPath "C:\Setup\iconia_print_helper.exe"
```

If `-BinaryPath` is omitted, Dart must be installed and the script compiles the
helper locally. The installer registers a Windows Scheduled Task that runs at
cashier login and restarts after failure.

Installed files:

```text
C:\ProgramData\Iconia\PrintHelper\
```

Uninstall auto-start:

```powershell
.\install\windows\uninstall.ps1
```

### Restaurant Setup Checklist

1. Add real network printers in the web app with their IP address and port.
2. Create a dedicated Firebase helper user and grant access to only that restaurant.
3. Create a private config with helper credentials, helper ID, and restaurant ID.
4. Install the helper on the cashier computer using the OS installer above.
5. Open the web app Printers page and confirm the helper/printer status is online.
6. Run Test Print for each physical printer.
7. Assign KOT printers to menu categories and test one bill and one KOT.

## Job Retry Behavior

- `pending`: waiting for helper
- `printing`: helper is processing
- `printed`: success
- `failed`: permanent failure after retries

If the helper is offline, jobs remain `pending` and are picked up when the helper starts again.

## Remaining One-Time Provisioning

The installer starts the native helper automatically after login, and printer
destinations now come from the web app. A restaurant installation still needs a
private helper identity and restaurant assignment once: Firebase helper
email/password and `restaurantId` in `config.json`, with a `system` membership
document. Removing those credentials securely requires an approval/pairing
flow or a trusted provisioning backend; it must not be implemented by allowing
a downloaded helper to grant itself restaurant access.

## Browser Fallback

The receipt screen still has `Browser Print` actions. Use them if the helper is offline or a printer is not configured on the current machine.
