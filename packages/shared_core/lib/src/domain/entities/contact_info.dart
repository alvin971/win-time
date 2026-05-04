import 'package:equatable/equatable.dart';

class ContactInfo extends Equatable {
  final String email;
  final String phoneNumber;
  final String? websiteUrl;

  const ContactInfo({
    required this.email,
    required this.phoneNumber,
    this.websiteUrl,
  });

  ContactInfo copyWith({
    String? email,
    String? phoneNumber,
    String? websiteUrl,
  }) {
    return ContactInfo(
      email: email ?? this.email,
      phoneNumber: phoneNumber ?? this.phoneNumber,
      websiteUrl: websiteUrl ?? this.websiteUrl,
    );
  }

  @override
  List<Object?> get props => [email, phoneNumber, websiteUrl];
}
