import 'package:record/record.dart';

void main() {
  final _audioRecorder = AudioRecorder();
  _audioRecorder.start(const RecordConfig(), path: '/tmp/test.m4a');
}
