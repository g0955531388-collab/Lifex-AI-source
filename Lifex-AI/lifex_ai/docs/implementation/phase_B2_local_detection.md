# Phase B2 — Local object detection with boxes

WO-CAMERA-REA-2026-10-27, branch `feat/camera-rea-clock`.

## Decision

Option A: `google_mlkit_object_detection: 0.14.0` (base model bundled in the
ML Kit SDK). Version 0.14.0 is the latest that shares the locked
`google_mlkit_commons 0.9.0`; no other ML Kit plugin changed. No Gradle change.

Boxes come from ML Kit object detection. Each box is cropped from the same
NV21 frame and named by the existing ML Kit image labeler. If neither the
labeler nor the detector's coarse category passes the threshold, the object is
spoken as unknown. Position is left / center / right by thirds of the upright
frame; the front lens is mirrored. No distance and no meters.

The naming threshold is 0.5, the labeler's documented default. It has not been
evaluated on a phone yet.

## Upgrade path (recorded, not active)

Option B (EfficientDet-Lite0 via `tflite_flutter`) is an upgrade path. It is
enabled only after option A passes the phone tests and after a separate
approval of the Gradle change (`noCompress` for the model and the native
TFLite runtime per ABI).

## Device scenario — known home scene

"Door" is not one of the 80 COCO classes and is removed from the scenario.
The scenario uses classes that exist in COCO: chair, table (dining table), cup,
TV, person, bottle, book, bag (handbag / backpack).

Under option A the names come from the ML Kit image labeler, not COCO. The
phone test measures how many of these eight are named correctly.

## Open items

1. First item of the next phone session: hear the vision state sentence on a
   real phone (state → dictionary → speech end to end).
2. Phone test of the eight-class home scene.
3. Evaluate the 0.5 naming threshold on a phone.
