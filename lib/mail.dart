import 'package:googleapis/gmail/v1.dart' as gMail;

class MailProvider {
  final gMail.GmailApi _gmailApi;
  MailProvider(this._gmailApi);

  final List<String> _nextPageTokens = []; // store next page tokens
  int currentPageIndex = 0; // store current page index

  // Fetch categories
  Future<List<gMail.Label>> getLabels() async {
    final response = await _gmailApi.users.labels.list('me');
    if (response.labels == null) {
      return [];
    }
    return response.labels!;
  }

  // Fetch messages by category
  Future<List<gMail.Message>> getMessagesByLabel(
      String label, int pageIndex) async {
    // If next page requested but there's no next page token, theres nothing to fetch
    if (pageIndex > _nextPageTokens.length) {
      return [];
    }

    // If first page requested, clear the next page tokens as this is a new list query
    String? nextPageToken;
    if (pageIndex == 0) {
      _nextPageTokens.clear();
      nextPageToken = null;
    } else {
      nextPageToken = _nextPageTokens[pageIndex - 1];
    }

    // fetch messages
    final response = await _gmailApi.users.messages.list('me',
        labelIds: [label], pageToken: nextPageToken, maxResults: 10);

    // if there's no messages, return an empty list
    if (response.messages == null) {
      return [];
    }

    // fill up the messages list
    final messages = <gMail.Message>[];
    for (final message in response.messages!) {
      final fullMessage = await _gmailApi.users.messages.get('me', message.id!);
      messages.add(fullMessage);
    }

    // save the next page token if this function is called again, except if there's no next page
    if (response.nextPageToken != null) {
      _nextPageTokens.add(response.nextPageToken!);
    }

    currentPageIndex = pageIndex;

    return messages;
  }

  // Check if there is a next page
  bool hasNextPage(int pageIndex) {
    return pageIndex < _nextPageTokens.length;
  }

  String getMailTitle(gMail.Message message) {
    final headers = message.payload?.headers;
    if (headers == null) {
      return 'No title';
    }
    final subject = headers.firstWhere(
      (header) => header.name == 'Subject',
      orElse: () => gMail.MessagePartHeader(name: 'Subject', value: 'No title'),
    );
    return subject.value ?? 'No title';
  }
}
