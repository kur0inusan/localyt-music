/// 再生位置・曲の長さの表示(1:23 / 1:00:12)。
String formatPlaybackTime(Duration duration) {
  final int hours = duration.inHours;
  final String minutes = duration.inMinutes
      .remainder(60)
      .toString()
      .padLeft(hours > 0 ? 2 : 1, '0');
  final String seconds = duration.inSeconds
      .remainder(60)
      .toString()
      .padLeft(2, '0');
  return hours > 0 ? '$hours:$minutes:$seconds' : '$minutes:$seconds';
}

/// プレイリストの更新日などの日付(10月2日)。年が違えば年も付ける。
String formatMonthDay(DateTime date, {DateTime? now}) {
  final DateTime today = now ?? DateTime.now();
  final String monthDay = '${date.month}月${date.day}日';
  return date.year == today.year ? monthDay : '${date.year}年$monthDay';
}
