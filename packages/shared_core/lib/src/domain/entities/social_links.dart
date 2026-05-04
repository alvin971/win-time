import 'package:equatable/equatable.dart';

class SocialLinks extends Equatable {
  final String? facebook;
  final String? instagram;
  final String? twitter;
  final String? tiktok;

  const SocialLinks({
    this.facebook,
    this.instagram,
    this.twitter,
    this.tiktok,
  });

  bool get isEmpty =>
      facebook == null && instagram == null && twitter == null && tiktok == null;

  @override
  List<Object?> get props => [facebook, instagram, twitter, tiktok];
}
