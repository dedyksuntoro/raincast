class RainViewerData {
  final List<RadarFrame> past;
  final List<RadarFrame> nowcast;

  RainViewerData({required this.past, required this.nowcast});

  factory RainViewerData.fromJson(Map<String, dynamic> json) {
    final radar = json['radar'];
    final past =
        (radar['past'] as List?)
            ?.map((frame) => RadarFrame.fromJson(frame))
            .toList() ??
        [];
    final nowcast =
        (radar['nowcast'] as List?)
            ?.map((frame) => RadarFrame.fromJson(frame))
            .toList() ??
        [];

    print(
      "Parsed Past Frames: ${past.length}, Nowcast Frames: ${nowcast.length}",
    );

    return RainViewerData(past: past, nowcast: nowcast);
  }
}

class RadarFrame {
  final int time;
  final String path;

  RadarFrame({required this.time, required this.path});

  factory RadarFrame.fromJson(Map<String, dynamic> json) {
    return RadarFrame(time: json['time'], path: json['path']);
  }
}
