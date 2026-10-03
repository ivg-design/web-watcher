The source is MIT licensed on GitHub. A plain build works out of the box.

## Build

```bash
cd WebWatcher
swift build
```

Or open `WebWatcher.xcodeproj` in Xcode and build.

## Built-in Google sign-in

Without a Google client, *Add Gmail Account* falls back to the Advanced import described under [Sign in with Google](/docs/sign-in-with-google). To get built-in sign-in in your own build, download a Desktop-app OAuth client JSON from Google Cloud Console and install it with:

```bash
scripts/install-google-client.sh /path/to/client_secret_*.json
```

This copies the JSON to `Sources/WebWatcher/Resources/google-oauth-client.json`, a path that is gitignored so it never gets committed. Rebuild after installing it.

## License

MIT.
