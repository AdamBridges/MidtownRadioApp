
// format used for slider endpoints, displaying duration under an episode

/// function that takes a *nullable* [Duration] and return formatted string
/// "HH:MM:SS". if hours is 0, format is "MM:SS".
/// if null, returns "--:--"
String formatDuration(Duration? duration) {
  if (duration == null) return '--:--';
  String twoDigits(int n) => n.toString().padLeft(2, '0');
  final hours = duration.inHours;
  final minutes = duration.inMinutes.remainder(60);
  final seconds = duration.inSeconds.remainder(60);

  if (hours > 0) {
    return '$hours:${twoDigits(minutes)}:${twoDigits(seconds)}';
  } else {
    return '${twoDigits(minutes)}:${twoDigits(seconds)}';
  }
}