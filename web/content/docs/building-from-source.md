This page is for developers who want to compile WebWatcher themselves, for example to change the code or to ship a build with their own Google sign-in. Most people should use the released app instead. The source is on GitHub at `https://github.com/ivg-design/web-watcher` under the MIT License with an attribution requirement: any copy or derivative must credit the project name "WebWatcher" and the original author "IVGDesign", for example in its About section, documentation or README, as the `LICENSE` file spells out.

## Requirements

| Requirement | Details |
|---|---|
| macOS | macOS 13 or later, which is the deployment target of both the Swift package and the Xcode project. |
| Swift | A Swift 5.9 or later toolchain, which the package declares as its tools version. Xcode 15 includes one. |
| Xcode | Needed for the Xcode build and for a built-in Google client. The Swift package build alone does not need the Xcode app, only the command line tools. |

## Build with Swift Package Manager

The package defines one executable product, `WebWatcher`, and a test target, `WebWatcherTests`.

1. Clone the repository and open its folder.

   ```bash
   git clone https://github.com/ivg-design/web-watcher.git
   cd web-watcher
   ```

2. Build.

   ```bash
   swift build
   ```

   **You see:** SwiftPM builds the `WebWatcher` target. The product is a command line executable under `.build/`, not a `WebWatcher.app` bundle.

3. Optionally run the tests.

   ```bash
   swift test
   ```

Use the Xcode build when you need the app bundle.

## Build with Xcode

1. Open `WebWatcher.xcodeproj` in Xcode.

   **You see:** one target, `WebWatcher`, which produces `WebWatcher.app`.

2. If Xcode reports a signing problem, open the target's **Signing & Capabilities** tab and choose your own team. The project uses automatic signing.

3. Choose **Product > Build**, or **Product > Run** to launch the app.

   **You see:** `WebWatcher.app` built for macOS 13 or later, with its menu bar icon on launch.

## Add a Google OAuth client for built-in sign-in

A build from a fresh clone has no Google OAuth client. In that build **Add Gmail Account** is dimmed, with the message "This build has no Google client configured — see Advanced below.", until you import a client under **Settings > Gmail > Advanced: use your own Google OAuth client**. To make sign-in work without that step, embed a client in the build.

1. Create a Desktop app OAuth client in Google Cloud Console and download its JSON. The steps are in [Sign in with Google](/docs/sign-in-with-google#use-your-own-google-oauth-client).

2. From the repository folder, install the file with the script.

   ```bash
   scripts/install-google-client.sh /path/to/client_secret_YOUR_CLIENT_ID.json
   ```

   **You see:** "Installed built-in Google client at" followed by the destination path, and a reminder that the path is gitignored.

3. Build again in Xcode.

   **You see:** **Settings > Gmail > Advanced: use your own Google OAuth client** shows "Using WebWatcher's built-in Google client" when no imported client overrides it.

The script copies the file unchanged to `Sources/WebWatcher/Resources/google-oauth-client.json`. That path is listed in `.gitignore`, so the client you install is never committed and each clone starts without one. An Xcode build phase copies the file into the app's `Resources` folder when it exists, which is why you rebuild in Xcode after installing it. The `swift build` command does not run that phase, so it does not give you a built-in client.

## If it does not work

| What you see | Cause | Fix |
|---|---|---|
| "error: file not found:" from the script. | The path you gave does not exist. | Check the path to the downloaded JSON. |
| **Add Gmail Account** is still dimmed after installing the client. | The build ran before the file existed, or it was not an Xcode build. | Run the script, then build again in Xcode. |
| Sign-in reports "This is a Web application client. Create a Desktop app client instead." | The JSON is for a Web application client. | Create a Desktop app client and download it. |
