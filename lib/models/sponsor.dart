import '../config/app_config.dart';

class NdrlSponsor {
  const NdrlSponsor({
    required this.id,
    required this.name,
    this.slug,
    this.description,
    this.logoUrl,
    this.websiteUrl,
    this.clickUrl,
  });

  final int id;
  final String name;
  final String? slug;
  final String? description;
  final Uri? logoUrl;
  final Uri? websiteUrl;
  final Uri? clickUrl;

  static final Uri _apiOrigin = Uri.parse(AppConfig.baseUrl);

  static Uri? _url(Object? value, {bool allowRelative = false}) {
    if (value is! String || value.trim().isEmpty) return null;
    final raw = Uri.tryParse(value.trim());
    if (raw == null) return null;
    if (raw.scheme == 'https' && raw.host.isNotEmpty) return raw;
    if (allowRelative &&
        raw.scheme.isEmpty &&
        raw.host.isEmpty &&
        value.startsWith('/') &&
        !value.startsWith('//')) {
      return _apiOrigin.resolveUri(raw);
    }
    return null;
  }

  // Directory clicks must use the backend-provided tracking endpoint.
  // Never construct tokens or fall back to an untracked website URL.
  static Uri? _directoryClickUrl(Object? value) {
    final url = _url(value);
    if (url == null ||
        url.host != _apiOrigin.host ||
        url.userInfo.isNotEmpty ||
        url.hasPort ||
        url.fragment.isNotEmpty) {
      return null;
    }
    return url;
  }

  factory NdrlSponsor.fromJson(Map<String, dynamic> json) {
    final id = json['sponsor_id'];
    final name = json['name'];
    if (id is! int || name is! String || name.trim().isEmpty) {
      throw const FormatException('Invalid sponsor');
    }
    return NdrlSponsor(
      id: id,
      name: name.trim(),
      slug: json['slug'] is String ? json['slug'] as String : null,
      description: json['description'] is String
          ? json['description'] as String
          : null,
      logoUrl: _url(json['logo_url'], allowRelative: true),
      websiteUrl: _url(json['website_url']),
      clickUrl: _directoryClickUrl(json['click_url']),
    );
  }
}
