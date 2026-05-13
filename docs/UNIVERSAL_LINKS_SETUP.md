# Universal Links / App Links — setup checklist

Audit refs: S7.2.2, S12.4, T27.

The repo already contains:
- `web/.well-known/apple-app-site-association` (template)
- `web/.well-known/assetlinks.json` (template)
- `web/_headers` already serves them with `Content-Type: application/json` and `Cache-Control: public, max-age=600`.

What you (Alvin) need to do:

## 1. Get the Apple Team ID

```bash
# From Xcode → preferences → Accounts → your team → Membership → Team ID (10 chars)
# Or via the App Store Connect API:
python3 scripts/check_asc_builds.py | head -5
```

Then in `web/.well-known/apple-app-site-association`, replace `REPLACE_TEAMID`
with the 10-character team identifier in **both** appIDs.

## 2. Get the Android release-keystore SHA-256 fingerprint

After you generate the release keystore (Sprint 0 T18), run:

```bash
keytool -list -v -keystore ./release.keystore \
  -alias upload \
  -storepass "$KEYSTORE_PASSWORD" \
  | grep 'SHA256' | head -1
```

The output line looks like `SHA256: AB:CD:EF:01:...`. Strip the colons — no
that's wrong, **keep the colons** per Google's spec. Paste the
`AB:CD:EF:...` string into `assetlinks.json`'s `sha256_cert_fingerprints`.

Repeat for the Pro keystore.

## 3. Add intent filters to AndroidManifest.xml

Inside the `<activity android:name=".MainActivity">` block of both Client
and Pro `android/app/src/main/AndroidManifest.xml`:

```xml
<intent-filter android:autoVerify="true">
  <action android:name="android.intent.action.VIEW" />
  <category android:name="android.intent.category.DEFAULT" />
  <category android:name="android.intent.category.BROWSABLE" />
  <data android:scheme="https" />
  <data android:host="wintime.fr" />
  <data android:pathPrefix="/r/" />
  <data android:pathPrefix="/o/" />
</intent-filter>
```

## 4. Add `associatedDomains` to iOS

In Xcode → Signing & Capabilities → + Capability → Associated Domains.
Add `applinks:wintime.fr`. For the Pro app, also add `applinks:pro.wintime.fr`
if you split the domains.

This requires entitlements file changes that Xcode handles automatically
when you toggle the capability.

## 5. Verify

After deploying to Cloudflare Pages and signing a release build:

```bash
# Apple checker:
curl -s https://app-site-association.cdn-apple.com/a/v1/wintime.fr | jq .

# Google checker:
curl -s "https://digitalassetlinks.googleapis.com/v1/statements:list?source.web.site=https://wintime.fr&relation=delegate_permission/common.handle_all_urls" | jq .

# Test from Terminal on a connected Android device:
adb shell pm verify-app-links --re-verify com.wintime.app
adb shell pm get-app-links com.wintime.app
```

If Apple's checker shows the JSON correctly and Android's `get-app-links`
shows `verified`, deep links into the app will work.
