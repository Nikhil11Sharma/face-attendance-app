# TFLite Model Sources

## mobilefacenet.tflite
- Source: https://github.com/sirius-ai/MobileFaceNet_TF
- Size: ~5 MB
- Input: [1, 112, 112, 3] — face image normalized to [-1, 1]
- Output: [1, 128] — L2-normalized embedding vector

## anti_spoof.tflite  
- Source: https://github.com/minivision-ai/Silent-Face-Anti-Spoofing
- Size: ~2 MB
- Input: [1, 80, 80, 3] — face image normalized to [0, 1]
- Output: [1, 2] — [spoof_prob, live_prob]

## Placement
Place both files in:
```
assets/models/mobilefacenet.tflite
assets/models/anti_spoof.tflite
```

## License
- MobileFaceNet: Apache 2.0
- Silent-Face: MIT

## Converting to TFLite (if using custom model)
```bash
python -m tf2onnx.convert --saved-model ./saved_model --output model.onnx
# Then use tflite_convert or ONNX→TFLite converter
```
