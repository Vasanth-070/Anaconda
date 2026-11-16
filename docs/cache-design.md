# Cache design

Status: draft (Day 20). Covers tiers, keys, TTL, eviction, request coalescing, invalidation and stale-while-revalidate.

## Problem

Anaconda shows live-ish data (quotes), rarely changing data (company profiles) and images (logos). Every screen reading from the network is slow, wasteful and useless offline. Every screen reading from a cache risks showing a wrong or stale value. The design decides where each kind of data lives, when it is fresh, when it is dropped, and what the UI does with stale data.

## Decisions

### Data classes

- **Seed (shared) data:** the same for every user. Quotes, company profiles, logos. Never cleared on logout.
- **User data:** depends on the user. Watchlist. Keyed by user id.
- Quotes are seed data because there is no tiered pricing. If entitlements are ever added, the quote key must include the tier (`AAPL|realtime`, `AAPL|delayed`), otherwise one tier's price can be served to another, including through the offline stale fallback.

### Tiers

| Data | Tier | Directory |
|---|---|---|
| Quote | Disk (memory in front is optional) | `Caches` |
| Company profile | Disk, memory in front | `Caches` |
| Logo, bytes | `URLCache` (server headers: `ETag`, `Cache-Control`) | `Caches` |
| Logo, decoded and downsampled | `NSCache` | memory |
| Watchlist (user data) | Disk, keyed by user id | `Application Support` |

- `NSCache` stays for the memory tier: it evicts on memory pressure by itself and is thread-safe. Callers depend on a cache protocol, so `NSCache` or an actor is an implementation detail (the `AcCache` seam).
- Seed data lives in `Caches` so iOS can purge it under low storage. User data lives in `Application Support` so it is not purged.

### Freshness (TTL)

- The entry stores `cachedAt`. The TTL belongs to a policy applied at read time: `isFresh = now - cachedAt < ttl`. Storing the duration in the entry would leave old entries on the old TTL after a change.
- The clock is injected, so the freshness check is a pure function that tests can drive.
- Stale does not mean deleted. The cache returns the entry with a freshness flag and the caller decides. This keeps the offline fallback working.
- Keep two timestamps apart: `cachedAt` (when we stored it) and the quote's own as-of time from the server (what the user sees as "price as of").

### Eviction

| Cache | Rule | Limit |
|---|---|---|
| Quotes | TTL for freshness, max-age sweep (for example 7 days) at launch | None needed (at most 50 symbols) |
| Profiles | LRU with a long TTL | Count cap |
| Decoded logos | LRU (`NSCache`) | Byte cost (`width * height * 4`), via `totalCostLimit` |

- TTL alone never removes anything, so the sweep is required.
- LFU is not used. The working set is small, and LFU keeps old popular entries and evicts new ones early. It suits server-side caches with a skewed workload (Redis LFU mode, W-TinyLFU in Caffeine).
- Decode and downsample to the display size before caching a logo.

### Request coalescing

- Concurrent requests for the same key share one network call: an actor holds `key -> Task`, later callers await the existing task, and the entry is removed when the task completes (success or failure).
- Written once as a generic mechanism at the HTTP client layer, not per API.
- GET only. Writes (orders, payments) are never coalesced.
- The key includes everything that changes the response, otherwise one caller can receive another's data.
- Cancellation: the shared work runs in its own unstructured `Task`, so one caller cancelling does not cancel the others.
- Not built until duplicate requests are observed in practice. Many distinct symbols are better served by a batch endpoint than by coalescing.

### Invalidation

- Seed data: expires by TTL, size cap or OS purge. Not cleared on logout.
- User data: scoped by user id, kept by default so relogin is fast.
- Wipe user data on account deletion, an explicit "remove my data", and after a long inactivity period (last-used timestamp per user, swept at launch).
- A forced logout (401, expired session) keeps the data, since the user will log in again.

### Stale-while-revalidate and UI

| Screen | Strategy | UI |
|---|---|---|
| Watchlist, online | SWR | Rows update in place when fresh data arrives; "last updated" timestamp; escalate styling only past a threshold |
| Watchlist, offline | SWR, cache only | Cached values with timestamps and an offline banner |
| Company profile | SWR, long TTL | No freshness indicator |
| Order ticket | Network-first | Skeleton or "fetching live price" while loading; on failure an error with retry and the Buy button disabled; never the cached price |

- No reachability pre-check before a refresh. Attempt the call and handle the failure. A path monitor only decides when to retry and shows the offline banner.
- Order ticket: show the fetched price with its timestamp and refresh while the screen is open. If it moves before confirmation, the user confirms the new price. The server validates the price at execution (limit or slippage tolerance).
- Rule: stale data is acceptable when the user is looking, and unacceptable when the user is acting on the number.

## Open

- Concrete TTLs and the max-age for quotes, profiles and logos.
- Count cap for profiles and byte limit for decoded logos.
- Whether a batch quotes endpoint exists on the backend.
- Whether tiered pricing is on the roadmap (changes the quote key).
- Retry policy when connectivity returns.
