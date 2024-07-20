import 'dart:convert';
import 'package:googleapis/drive/v2.dart';
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

    var labels = parseLabels(response.labels!);

    return labels;
  }

  List<gMail.Label> parseLabels(List<gMail.Label> labels) {
    // sort labels by name, with INBOX first
    labels.sort((a, b) {
      if (a.name == 'INBOX') {
        return -1;
      } else if (b.name == 'INBOX') {
        return 1;
      } else {
        return a.name!.compareTo(b.name!);
      }
    });
    // cut the CATEGORY_ prefix from label strings
    for (var label in labels) {
      if (label.name!.startsWith('CATEGORY_')) {
        label.name = label.name!.substring('CATEGORY_'.length);
      }
    }
    return labels;
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

  String getMailSender(gMail.Message message) {
    final headers = message.payload?.headers;
    if (headers == null) {
      return 'No sender';
    }
    final from = headers.firstWhere(
      (header) => header.name == 'From',
      orElse: () => gMail.MessagePartHeader(name: 'From', value: 'No sender'),
    );
    return from.value ?? 'No sender';
  }

  String getMailDate(gMail.Message message) {
    final headers = message.payload?.headers;
    if (headers == null) {
      return 'No date';
    }
    final date = headers.firstWhere(
      (header) => header.name == 'Date',
      orElse: () => gMail.MessagePartHeader(name: 'Date', value: 'No date'),
    );
    return date.value ?? 'No date';
  }

  String getMailBody(gMail.Message message) {
    final parts = message.payload?.parts;
    if (parts == null) {
      return 'No body';
    }
    final body = parts.firstWhere(
      (part) => part.mimeType == 'text/plain',
      orElse: () => gMail.MessagePart(
          mimeType: 'text/plain', body: gMail.MessagePartBody(data: '')),
    );

    if (body.body?.data == null) {
      return 'No body';
    }

    // decode the body
    String decoded = utf8.decode(base64.decode(body.body!.data!));
    return _cleanMailBody(decoded);
  }

  String _cleanMailBody(String body) {
    // remove urls
    body = body.replaceAll(RegExp(r'http(s)?://[^\s]*'), '');
    // remove html tags
    body.replaceAll(RegExp(r'<[^>]*>'), '');
    // remove media blocks
    body = body.replaceAll(
        RegExp(r'@media[^{]*{([^{}]*{[^{}]*})*[^{}]*}', dotAll: true), '');
    // remove empty parentheses
    body = body.replaceAll(RegExp(r'\([\s]*\)'), '');
    // join lines with single line break
    body = body.replaceAll(RegExp(r'\n(?!\n)'), ' ');

    return body;
  }
}
