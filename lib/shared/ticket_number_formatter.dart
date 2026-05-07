import 'package:finadvise/models/models.dart';
import 'package:intl/intl.dart';

String formatTicketNumberFromTicket(Ticket ticket) =>
    formatTicketNumber(createdAt: ticket.createdAt);

String formatTicketNumber({String? createdAt}) {
  final resolvedDate = _parseTicketDate(createdAt) ?? DateTime.now();
  return DateFormat('MM/yy/dd').format(resolvedDate);
}

DateTime? _parseTicketDate(String? raw) {
  final value = raw?.trim() ?? '';
  if (value.isEmpty) return null;

  DateTime? _tryParse(String input) {
    try {
      return DateTime.parse(input).toLocal();
    } catch (_) {
      return null;
    }
  }

  final direct = _tryParse(value);
  if (direct != null) return direct;

  final normalized =
      (value.endsWith('Z') || value.contains('+')) ? value : '${value}Z';
  return _tryParse(normalized);
}
