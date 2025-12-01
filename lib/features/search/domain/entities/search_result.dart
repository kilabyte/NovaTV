import '../../../playlist/domain/entities/channel.dart';
import '../../../epg/domain/entities/program.dart';

/// Represents a search result that can be either a channel or a program match
sealed class SearchResult {
  const SearchResult();
}

/// A channel that matched the search query
class ChannelSearchResult extends SearchResult {
  final Channel channel;

  const ChannelSearchResult(this.channel);
}

/// A program that matched the search query, with its associated channel
class ProgramSearchResult extends SearchResult {
  final Program program;
  final Channel channel;

  const ProgramSearchResult({
    required this.program,
    required this.channel,
  });
}
