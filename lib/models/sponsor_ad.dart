import '../config/app_config.dart';

class SponsorAd {
  const SponsorAd({
    required this.adId,
    required this.sponsorId,
    required this.sponsorName,
    required this.imageUrl,
    required this.clickUrl,
    required this.weight,
    this.adName,
    this.altText,
    this.destinationUrl,
    this.impressionToken,
  });

  final int adId;
  final int sponsorId;
  final String sponsorName;
  final String? adName;
  final String? altText;
  final Uri imageUrl;
  final Uri clickUrl;
  final Uri? destinationUrl;
  final String? impressionToken;
  final int weight;

  static final Uri _apiOrigin = Uri.parse('${AppConfig.baseUrl}');

  static Uri _imageUrl(Object? value) {
    if (value is! String || value.trim().isEmpty) {
      throw const FormatException('Missing image_url');
    }
    final raw = Uri.tryParse(value.trim());
    if (raw == null) throw const FormatException('Invalid image_url');
    final uri = raw.hasScheme ? raw : _apiOrigin.resolveUri(raw);
    if (uri.scheme != 'https' ||
        uri.host.isEmpty ||
        (raw.hasAuthority && !raw.hasScheme)) {
      throw const FormatException('Invalid image_url');
    }
    return uri;
  }

  static Uri _httpsUrl(Object? value, String field) {
    if (value is! String) throw FormatException('Missing $field');
    final uri = Uri.tryParse(value);
    if (uri == null || uri.scheme != 'https' || uri.host.isEmpty) {
      throw FormatException('Invalid $field');
    }
    return uri;
  }

  static int _int(Object? value, String field) {
    if (value is int) return value;
    throw FormatException('Invalid $field');
  }

  factory SponsorAd.fromJson(Map<String, dynamic> json) {
    final clickUrl = _httpsUrl(json['click_url'], 'click_url');
    // Require click tracking to use the configured API host.
    if (clickUrl.host != Uri.parse(AppConfig.baseUrl).host ||
        clickUrl.path != '/api/sponsor_click.php') {
      throw const FormatException('Unexpected sponsor click endpoint');
    }
    final name = json['sponsor_name'];
    if (name is! String || name.trim().isEmpty) {
      throw const FormatException('Invalid sponsor_name');
    }
    final destination = json['destination_url'];
    return SponsorAd(
      adId: _int(json['ad_id'], 'ad_id'),
      sponsorId: _int(json['sponsor_id'], 'sponsor_id'),
      sponsorName: name,
      adName: json['ad_name'] is String ? json['ad_name'] as String : null,
      altText: json['alt_text'] is String ? json['alt_text'] as String : null,
      imageUrl: _imageUrl(json['image_url']),
      clickUrl: clickUrl,
      destinationUrl: destination == null
          ? null
          : _httpsUrl(destination, 'destination_url'),
      impressionToken: json['impression_token'] is String
          ? json['impression_token'] as String
          : null,
      weight: _int(json['weight'], 'weight').clamp(1, 1000000).toInt(),
    );
  }
}

class SponsorAdBatch {
  const SponsorAdBatch({required this.rotationSeconds, required this.ads});
  final int rotationSeconds;
  final List<SponsorAd> ads;
}
