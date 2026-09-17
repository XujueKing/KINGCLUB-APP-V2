/// Standard keys serve web capture; flutter_webrtc Android currently reads
/// mandatory/optional maps when constructing its native AudioSource.
const callAudioConstraints = <String, dynamic>{
  'echoCancellation': true,
  'noiseSuppression': true,
  'autoGainControl': true,
  'optional': [
    {'googEchoCancellation': true},
    {'googNoiseSuppression': true},
    {'googAutoGainControl': true},
  ],
};
