/// URLs to the public legal pages.
///
/// These live on a static Cloudflare Pages deployment of `web/legal/`
/// (see web/legal/privacy.html etc. and the corresponding deploy step).
/// Centralised here so a future move to a different host only touches one file.
class LegalUrls {
  LegalUrls._();

  static const String privacy =
      'https://wintime.fr/legal/privacy.html';
  static const String terms =
      'https://wintime.fr/legal/cgv.html';
  static const String mentionsLegales =
      'https://wintime.fr/legal/mentions-legales.html';
  static const String cookiePolicy =
      'https://wintime.fr/legal/cookies.html';
  static const String supportEmail = 'support@wintime.fr';
}
