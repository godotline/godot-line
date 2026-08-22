# Changelog

## Unreleased

- Performance: scene-dock refresh batches now share one scan cache, so the edited scene is
  serialized once per batch instead of once per scene instance root; persistent signal-connection
  checks and property-list lookups are precomputed/cached per batch and per class. Avoids the
  editor freezing when opening scenes that contain many scene instances.

## 1.0.0 - 2026-08-04
