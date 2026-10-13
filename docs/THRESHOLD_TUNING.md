# 🎯 Threshold Tuning Guide — FAR/FRR Calibration

## Overview

Face recognition uses **cosine similarity** between MobileFaceNet 128-dim embeddings.
Score range: `-1.0` (opposite faces) to `1.0` (identical).

## Current Thresholds

```dart
// lib/core/constants/app_constants.dart
static const double highConfidenceThreshold = 0.82; // Auto-present
static const double borderlineThreshold = 0.65;      // Needs review
```

## What Each Threshold Controls

| Zone | Score | Action | Risk |
|------|-------|--------|------|
| High | ≥ 0.82 | Auto-mark present ✅ | Low FAR |
| Borderline | 0.65–0.82 | Add to "Needs Review" ⚠️ | Review queue |
| Low | < 0.65 | Unrecognized ❌ | Student may miss attendance |

## How to Calibrate for Your Dataset

### Step 1: Collect Verification Pairs
```python
# Run this script on your enrolled student photos
pairs = []
for student in students:
    # Genuine pairs: same student, different photos
    for (img1, img2) in combinations(student.photos, 2):
        pairs.append((img1, img2, 'genuine'))

    # Impostor pairs: different students
    for other_student in other_students:
        pairs.append((student.photos[0], other_student.photos[0], 'impostor'))
```

### Step 2: Extract Embeddings and Compute Similarities
```python
similarities_genuine = []
similarities_impostor = []

for (img1, img2, label) in pairs:
    emb1 = mobilefacenet(img1)
    emb2 = mobilefacenet(img2)
    sim = cosine_similarity(emb1, emb2)
    if label == 'genuine':
        similarities_genuine.append(sim)
    else:
        similarities_impostor.append(sim)
```

### Step 3: Plot ROC Curve
```python
import numpy as np
from sklearn.metrics import roc_curve, auc

labels = [1]*len(similarities_genuine) + [0]*len(similarities_impostor)
scores = similarities_genuine + similarities_impostor

fpr, tpr, thresholds = roc_curve(labels, scores)
roc_auc = auc(fpr, tpr)

# Find threshold where FAR = 1%
idx = np.argmin(np.abs(fpr - 0.01))
recommended_high_threshold = thresholds[idx]

# Find threshold where TAR = 95%
idx = np.argmin(np.abs(tpr - 0.95))
recommended_low_threshold = thresholds[idx]
```

### Step 4: Typical MobileFaceNet Results (LFW benchmark)

```
Threshold | FAR    | TAR (=1-FRR) | Recommendation
----------|--------|--------------|---------------
0.90      | 0.01%  | 88%          | Too strict for classroom
0.85      | 0.05%  | 93%          | Tight, use for VIP
0.82      | 0.1%   | 96%          | ✅ Default highConfidence
0.75      | 0.5%   | 98%          | Between zones
0.65      | 3%     | 99.5%        | ✅ Default borderline
0.55      | 8%     | 99.9%        | Too many false accepts
```

### Step 5: Adjust for Your Environment

**If you see too many "Needs Review" (FRR too high):**
```dart
// Lower the high threshold slightly
static const double highConfidenceThreshold = 0.78; // Was 0.82
```

**If you get wrong students marked present (FAR too high):**
```dart
// Raise the high threshold
static const double highConfidenceThreshold = 0.85; // Was 0.82
```

**For a class with known twins/lookalikes:**
```dart
// Raise ambiguity detection sensitivity
// In face_recognition_service.dart:
final ambiguous = (bestSimilarity - secondBestSimilarity) < 0.08; // Was 0.05
```

## Multi-Frame Voting Effect on FAR/FRR

| Votes Required | Effect |
|---------------|--------|
| 1/5 (no voting) | Lower FRR, higher FAR |
| 3/5 (default) | Balanced |
| 5/5 (strict) | Very low FAR, higher FRR (slow students miss mark) |

## Semester Re-Calibration

After each semester re-enrollment:
1. Run 50 genuine verification pairs per student
2. Recompute average similarity
3. If class average drops (new angles, aging), lower thresholds by 0.02
4. Log threshold changes in audit system

## Reporting Template

```
Calibration Date: [DATE]
Class: [CLASS NAME]
Students: [N]
Test pairs (genuine): [N]
Test pairs (impostor): [N]

Threshold | FAR | FRR | Notes
---------|-----|-----|------
0.82     | X%  | Y%  | High confidence
0.65     | X%  | Y%  | Borderline
```
