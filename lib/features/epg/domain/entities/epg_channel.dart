import 'package:equatable/equatable.dart';

/// Represents a channel definition in the XMLTV EPG
class EpgChannel extends Equatable {
  final String id;
  final String? displayName;
  final String? iconUrl;
  final String? url;

  const EpgChannel({
    required this.id,
    this.displayName,
    this.iconUrl,
    this.url,
  });

  EpgChannel copyWith({
    String? id,
    String? displayName,
    String? iconUrl,
    String? url,
  }) {
    return EpgChannel(
      id: id ?? this.id,
      displayName: displayName ?? this.displayName,
      iconUrl: iconUrl ?? this.iconUrl,
      url: url ?? this.url,
    );
  }

  @override
  List<Object?> get props => [id, displayName, iconUrl, url];
}
