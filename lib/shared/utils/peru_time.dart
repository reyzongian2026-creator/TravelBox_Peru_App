class PeruTime {
  PeruTime._();

  static const Duration _peruOffset = Duration(hours: -5);

  static DateTime toPeruClock(DateTime value) {
    return value.toUtc().add(_peruOffset);
  }

  static DateTime fromPeruClock(DateTime peruClock) {
    return DateTime.utc(
      peruClock.year,
      peruClock.month,
      peruClock.day,
      peruClock.hour,
      peruClock.minute,
      peruClock.second,
      peruClock.millisecond,
      peruClock.microsecond,
    ).subtract(_peruOffset);
  }

  static DateTime nowPeruClock() {
    return toPeruClock(DateTime.now());
  }

  static DateTime nextWholeHourUtc() {
    final peruNow = nowPeruClock();
    final roundedPeru = DateTime(
      peruNow.year,
      peruNow.month,
      peruNow.day,
      peruNow.hour,
    ).add(const Duration(hours: 1));
    return fromPeruClock(roundedPeru);
  }

  static String formatDateTime(
    DateTime value, {
    bool includeYear = true,
  }) {
    final peru = toPeruClock(value);
    final day = peru.day.toString().padLeft(2, '0');
    final month = peru.month.toString().padLeft(2, '0');
    final hour = peru.hour.toString().padLeft(2, '0');
    final minute = peru.minute.toString().padLeft(2, '0');
    if (!includeYear) {
      return '$day/$month $hour:$minute';
    }
    return '$day/$month/${peru.year} $hour:$minute';
  }

  static String formatDateRange(DateTime start, DateTime end) {
    return '${formatDateTime(start)} - ${formatDateTime(end)}';
  }
}
