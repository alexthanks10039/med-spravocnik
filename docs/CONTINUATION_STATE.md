# Continuation state

Updated: 2026-09-24

## Completed in this run

- Added `flutter_app/lib/core/network/api_client.dart`.
- The client now provides typed JSON GET/POST helpers, timeout handling, transport error normalization, HTTP error payload extraction, and explicit resource cleanup.
- The implementation is intentionally independent from the current `OfflineMedicalRepository`, so the existing offline MVP remains unchanged while the REST integration is introduced incrementally.

## Next executable step

Replace the catalog/search feature's direct offline reads with a repository adapter backed by `ApiClient`, while keeping offline fallback for development and no-network states. Add focused Flutter tests for:

1. successful JSON response decoding;
2. non-2xx error message extraction;
3. timeout and connection error mapping;
4. fallback to the offline repository.

## Current product constraint

The backend and Flutter client are not fully synchronized yet. Keep the medical disclaimer and source/date metadata requirements in place before exposing medical content as authoritative.
