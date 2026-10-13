# 🧪 Testing Plan — Face Attendance App

## 1. Unit Tests

### Face Recognition Module
```
test/unit/ml/face_recognition_test.dart
```

| Test Case | Expected Result |
|-----------|----------------|
| Cosine similarity of identical embeddings | 1.0 |
| Cosine similarity of different faces | < 0.65 |
| L2 normalization of embedding vector | Unit length (norm = 1.0) |
| Auto-present threshold (≥ 0.82) | Returns `MatchResult.autoPresent` |
| Borderline threshold (0.65–0.82) | Returns `MatchResult.needsReview` |
| Below threshold (< 0.65) | Returns `MatchResult.unrecognized` |
| Twins: scores within 0.05 | Returns `requiresManualConfirmation: true` |
| Multi-frame voting: 2/5 votes | Does NOT mark present |
| Multi-frame voting: 3/5 votes | Marks present |

### Encryption Module
```
test/unit/services/encryption_test.dart
```

| Test Case | Expected Result |
|-----------|----------------|
| Encrypt then decrypt 128-dim embedding | Lossless round-trip |
| Two encryptions of same data | Different ciphertext (random IV) |
| Decrypt with wrong key | Throws exception |
| Batch encrypt/decrypt 5 embeddings | All round-trip correctly |

### Frame Quality Module
```
test/unit/ml/frame_quality_test.dart
```

| Test Case | Expected Result |
|-----------|----------------|
| Sharp image (Laplacian var > threshold) | `blurScore ≥ 0.65` |
| Blurry image | `blurScore < 0.65`, not acceptable |
| Dark image (< 30% brightness) | Not acceptable |
| Bright overexposed image | Not acceptable |
| Face width < 80px | `meetsMinSize: false` |
| Good face (centered, 120px+) | `isAcceptable: true` |

### Anti-Spoofing Module
```
test/unit/ml/anti_spoof_test.dart
```

| Test Case | Expected Result |
|-----------|----------------|
| Live face (real photo) | `isLive: true, score ≥ 0.80` |
| Printed photo attack | `isLive: false, score < 0.80` |
| Phone screen replay attack | `isLive: false` |
| Liveness challenge: blink sequence | `isComplete: true` |
| Liveness challenge: timeout | `isFailed: true` |

### Sync Queue
```
test/unit/services/sync_test.dart
```

| Test Case | Expected Result |
|-----------|----------------|
| Add item to queue when offline | Stored in sync_queue table |
| Drain queue when online | All items pushed to Firestore |
| Retry on failure | Increments retry_count |
| Max retries exceeded | Item stays but not retried |
| Duplicate attendance (UNIQUE constraint) | Silently replaced (upsert) |

---

## 2. Widget Tests

```
test/widget/
├── live_scan_screen_test.dart
├── consent_screen_test.dart
├── enrollment_screen_test.dart
├── reports_screen_test.dart
└── review_screen_test.dart
```

| Test | Verification |
|------|-------------|
| Consent screen: checkbox disabled before full scroll | Checkbox not tappable |
| Consent screen: consent grants enrollment access | Routes to enroll screen |
| Consent screen: decline shows manual attendance note | Dialog appears |
| Live scan: counter increments on face match | "Present 1/30" shown |
| Review screen: tap-to-correct marks student present | Status updates |
| Reports: low attendance badge shown for < 75% | Red indicator visible |
| Export button: taps initiate PDF/Excel generation | Export dialog shown |

---

## 3. Accuracy Testing Protocol

### Dataset for Testing

Collect 200 face images across:
- **20 students** (10 images each: different angles, lighting, accessories)
- **Lighting**: bright indoor, dim indoor, outdoor sunlight, backlighting
- **Accessories**: glasses, masks (half), hat
- **Expressions**: neutral, slight smile, tired

### Metrics to Measure

```
FAR (False Accept Rate) = false positives / total negative attempts
FRR (False Reject Rate) = false negatives / total positive attempts
TAR (True Accept Rate) = 1 - FRR
```

**Target thresholds:**
```
FAR < 1%   (< 1 wrong person marked present per 100 attempts)
FRR < 5%   (< 5 correct students blocked per 100 attempts)
```

### Threshold Tuning (ROC-based)

1. Run recognition on 1000 image pairs (500 same-person, 500 different-person)
2. Compute cosine similarity for all pairs
3. Plot ROC curve: FAR vs. TAR at various similarity thresholds
4. Set `highConfidenceThreshold` where FAR < 1%
5. Set `borderlineThreshold` where TAR > 95% (catch most students)

```
Typical MobileFaceNet ROC on LFW dataset:
  Threshold 0.82 → FAR ≈ 0.1%, TAR ≈ 96%
  Threshold 0.65 → FAR ≈ 3%, TAR ≈ 99.5%
```

### Bias Testing Plan

Test accuracy per demographic group:

| Group | Target Accuracy |
|-------|----------------|
| Light skin tones | ≥ 97% TAR |
| Medium skin tones | ≥ 97% TAR |
| Dark skin tones | ≥ 97% TAR |
| Male students | ≥ 97% TAR |
| Female students | ≥ 97% TAR |
| Students with glasses | ≥ 94% TAR |
| Students with half-masks | ≥ 85% TAR |
| Age 18–20 | ≥ 97% TAR |
| Age 21–25 | ≥ 97% TAR |

**If disparity > 5% across groups → retrain or re-enroll that group.**

---

## 4. Spoofing Resistance Tests

| Attack Type | Test Method | Expected Result |
|-------------|------------|----------------|
| Printed A4 photo | Hold color printout in front of camera | REJECTED |
| Printed A4 photo | B&W photocopy | REJECTED |
| Phone screen replay | Show live face video from phone | REJECTED |
| Tablet screen replay | Show HD face video | REJECTED |
| 3D mask (paper) | Basic paper mask | REJECTED |
| Liveness bypass | Skip blink challenge (inject image) | REJECTED |
| Same photo different angles | Rotate a printout | REJECTED |
| Real face | Live person | PASSED |

**Minimum passing rate: 98% rejection of spoof attacks.**

---

## 5. Lighting & Angle Tests

### Angle Tests
Test each student at these head poses during recognition:
```
0° (frontal), ±10°, ±15°, ±20°, ±30°
Pitch up/down: ±10°, ±15°
```

Target: TAR ≥ 94% at ±20° yaw, ≥ 90% at ±30° yaw.

### Lighting Tests
```
Bright fluorescent (500 lux)     → TAR ≥ 97%
Dim room (50 lux)                → TAR ≥ 93%
Outdoor sunlight (5000 lux)      → TAR ≥ 90%
Backlighting (contre-jour)       → TAR ≥ 85%, borderline flagged
```

---

## 6. Twins / Lookalike Tests

Collect 5 pairs of visually similar students.

| Test | Expected Behavior |
|------|------------------|
| Identical twin, high similarity | `requiresManualConfirmation: true` |
| Lookalike pair (same score ±0.05) | Flagged for review, roll-number check |
| Manual confirmation via roll number | Marked correctly |
| Wrong twin attempts to mark other twin | Flagged, audit logged |

---

## 7. Mask Tests

| Coverage | Expected TAR |
|----------|-------------|
| No mask | ≥ 97% |
| Half mask (below nose) | ≥ 85% |
| Full mask | System prompts to remove mask |
| Scarf/dupatta (variable) | ≥ 80%, many flagged borderline |

---

## 8. Performance Tests

| Metric | Target |
|--------|--------|
| Face detection latency | < 100ms per frame |
| Embedding extraction | < 50ms per face |
| Matching (60 students) | < 30ms |
| Full frame processing | < 200ms @ 5–10 FPS |
| Session for 60 students | < 3 minutes |
| App memory usage | < 300 MB |
| Battery per session | < 10% drain |

---

## 9. Offline Tests

| Scenario | Expected Behavior |
|----------|------------------|
| No internet during session | Attendance saved locally |
| App closed before sync | Data persisted in SQLite |
| Return online | Auto-sync within 30 seconds |
| Firestore write conflict | Last-write-wins with audit log |
| 7-day offline | All data intact, sync on reconnect |

---

## 10. Session Timing Comparison

To measure speed vs. manual roll call:

1. Timer starts when scan session opens
2. Timer ends when session is submitted
3. App displays: `"Scan completed in 2m 15s vs est. 8m manual"`
4. Log session duration in Firestore for analytics

Target: Face scan ≤ 40% of manual roll call time.

---

## 11. Pilot Testing Protocol (One Class)

### Phase 0 — Preparation (Week 1)
- [ ] Firebase project created, Firestore rules deployed
- [ ] Test device (Android) with teacher account
- [ ] 10 volunteer student enrollments for dry run
- [ ] Consent forms signed (both digital + paper backup)

### Phase 1 — Dry Run (Week 2)
- [ ] 3 sessions with volunteer students
- [ ] Validate: correct marking, review queue works, sync works
- [ ] Measure session time vs. manual
- [ ] Fix all critical bugs

### Phase 2 — Supervised Pilot (Weeks 3–4)
- [ ] Full class of 30–60 students enrolled
- [ ] Teacher runs face scan + verifies against manual register
- [ ] Log all discrepancies
- [ ] Target: < 2% error rate before going live

### Phase 3 — Live Deployment
- [ ] Teacher operates independently
- [ ] Weekly audit: manual spot-check 5 random attendance records
- [ ] Monthly accuracy report generated

---

## 12. Known Limitations

| Limitation | Severity | Mitigation |
|-----------|----------|-----------|
| MobileFaceNet accuracy drops in very low light (< 20 lux) | Medium | Quality check rejects dark frames |
| Full-face mask: can't recognize | High | System prompts mask removal |
| Identical twins with no ID card | High | Roll-number confirmation required |
| First-time enrollment quality varies by teacher | Medium | Guided 5-angle capture with quality feedback |
| TFLite anti-spoof model not perfect for 3D silicone masks | Low | Challenge-based liveness as backup |
| Wide-angle row scanning reduces face size | Medium | Minimum face size quality gate |
| Old Android (API 24) may have slower TFLite inference | Low | Test on minimum spec device |
| No student app — attendance can be disputed | Medium | Audit log + snapshot provides evidence |
