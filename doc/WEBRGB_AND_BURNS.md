# WebRGB and BFA Burns

Target: RN beta.37 at `e38329eba11cce16e3bea75b8a4e7becd52c0036`,
`@utexo/webrgb` 0.1.2, RLN 0.16.0-beta.3. This document defines integration
contracts, not production qualification. Check RELEASE_READINESS_TRACKER.md.

## Optional Provider

Import `package:rgb_sdk_flutter/rgb_sdk_flutter_webrgb.dart`. The ordinary
wallet entrypoint does not install or expose a browser provider automatically.
`WebRgbProvider` implements the same RN subset: enable, getInfo, getAddress,
blindReceive, witnessReceive, signMessage, listAssets, getAssetBalance,
listTransfers, getTransferStatus,
decodeRgbInvoice, and optional burnAsset/getConsignment. It does not pretend to
implement the rest of WebRGB (issuance, generic sends, discovery, transports).

The host owns transport authentication, origin verification, JSON request
validation, user consent, timeouts and session expiration. Pass immutable typed
arguments rather than untrusted maps. Construct one provider per authenticated
origin/session/wallet. Never accept the origin or payout-chain policy from a
dApp request. The origin must be HTTP(S), without credentials, query or fragment.
Call revoke on disconnect, expiry or wallet switch; also supply
assertAuthorized for host permission changes outside the provider.

No response may escape after the session revision changes, including a
revoke/re-enable race. Concurrent enable calls share one approval. Host consent
callbacks receive immutable snapshots, including the effective minimum
confirmations and the full burn amount/payout. Read/receive defaults follow RN;
the provider enforces at least three confirmations and exact JS-safe numeric
fields. Balances and receive inputs outside that numeric range fail rather
than round. Transfer history instead preserves `amountBaseUnits` as an exact
UInt64 decimal string and omits `amount` above the JS safe-integer range.
Outgoing Send/Burn/Inflation use the requested recipient amount, not change or
the whole batch; ReceiveBlind/ReceiveWitness/Issuance use actual allocations.
Missing evidence produces an absent amount, not zero or the requested invoice.
Named-asset receiving and balance queries check wallet inventory first so an
unknown asset returns ASSET_NOT_FOUND without guessing from native NotFound
messages. An unnamed blind receive remains available for a new contract.
Typed native invalid-request failures become sanitized INVALID_PARAMS.

The chain allowlist is not verification that a particular asset is redeemable
on that chain. Before approving burnAsset, the host must independently validate
the asset/bridge route and display the destination, amount and fee policy. The
SDK does not discover a redemption contract, verify an external payout, or
guarantee that the bridge will honor a burn. Reject approval if the host cannot
verify the route. All returned DTOs expose toJson for the transport host.

RN beta.36 removed its host allowlist in favor of positive EIP-155 chain syntax.
Flutter deliberately retains `WebRgbBurnOptions.allowedPayoutChainIds` as a
stricter host authorization boundary. It is not taken from the dApp and does
not imply bridge-route verification. This is documented divergence, not exact
policy parity. Native-transfer unknown shapes likewise fail closed instead of
RN's `Any` fallback; known shapes and monetary semantics match the reference.

## Durable Burn Ownership

Burns destroy RGB units. A burn result is not confirmation or proof that an
external-chain payout occurred. Use BurnOperations, not automatic retries of
UtexoWallet.burn. The native low-level method intentionally has no idempotency
contract, just as in RN.

Supply one app-owned BurnOperationStore for each wallet. Its write must perform
an atomic durable upsert by SDK-generated record ID and resolve only after the
write is committed. A rejected write may already have reached disk. The store
must retain all records across process restart. Only one process/isolate may
own a wallet and store. There is deliberately no in-memory production store.
Test fixtures are not an implementation recommendation.

State transitions are prepared -> pending -> complete. Pending is durably
written before native invocation. Failure/revocation before invocation cancels
the record. Typed native InsufficientFunds/NoAvailableUtxos from the burn call,
before a result is returned, also cancel because native guarantees no broadcast.
An uncertain outcome after invocation remains pending and blocks
every new burn, including from another provider. A known native result whose
final write failed remains in memory and can be flushed with retryPersistence
without another native call. After process death, durable pending stays pending.

Recovery is wallet-owned. reconcile requires a matching Burn transfer and a
host-supplied independent proof verifier checking asset, amount, recipient and
native result against the saved operation. Txid equality alone is insufficient.
The pinned native API does not expose that proof decoder; the SDK does not
invent one or silently clear uncertain outcomes. If no real verifier is
available, keep the operation pending and seek wallet recovery support.

Journal metadata contains origin, network and payout destination and must be
treated as private wallet data. It must not be exposed to the dApp. Legacy RN
records normalize to v2 while preserving their old private IDs; unsupported
versions, missing results, conflicting recipients and malformed records fail
closed. WebRGB responses use txid as transferId, never a private journal ID.

The optional error field round-trips legacy RN records (which may contain
private native messages). New Flutter failures persist only sanitized codes.
A journal persistence failure after a known successful burn never becomes a
cancelled burn, even if that storage failure happens to use a funding error code.

## WalletConnect Router

`WebRgbWalletConnectSession` implements wallet-side positional RPC dispatch for
the experimental `webrgb:1` profile, `rgb:<network>` chain and qualified account.
It is not a complete WalletKit transport. The host must initialize WalletKit,
pair, negotiate proposals, verify peer origin, obtain consent, persist sessions,
subscribe/unsubscribe events, deliver replies and close expired approval UI.
Invalid/scam verification must be rejected; unknown verification needs explicit
user warning and approval. Never build a grant from request-provided identity.

Each router binds one wallet and session, checks current grant permissions at
async boundaries, serializes requests, and deduplicates IDs without replaying
mutations. Disposal is terminal. It bounds unexpired request IDs to 256 and
input JSON to 64 KiB. Proof export uses 48 KiB chunks, a 16 MiB decoded bound
and Keccak-256 verification off the UI isolate. Cached results are copied for
delivery so host edits cannot corrupt later duplicate replies. Live relay,
session restoration, proposal negotiation and app consent UI remain OCT-031,
not claimed by the router's unit tests.

Message signing always prompts with the exact origin/message and uses native
wallet identity. Unpaired UTF-16 surrogates fail before approval; valid Unicode
is unchanged. This is not the experimental standalone Dart Schnorr signer.

## Proof Export

Only saved Burn consignments can be exported. Capability checks and user
consent apply even when native supports general saved consignment access.
Burn approval can include proof-export approval for that session/transaction.
A new or revoked session must obtain fresh consent, even for the same origin.
This is intentionally stricter than RN's lasting journal-derived consent.

Exports return complete canonical standard Base64, byteLength and a 0x-prefixed
Keccak-256 digest (not SHA3-256). The limit is 16 MiB decoded, and only one proof
is cached. Hashing runs in a separate isolate receiving only immutable proof
inputs. Concurrent calls retain their own results; revoke drops cached proof
and permissions. Raw native error messages and wallet paths never cross the
provider boundary. Diagnostic causes remain on the wallet side.

## Native and Dart Adaptations

- BFA means bridged fungible asset. This RN release adds BFA listing and burn,
  not a public wallet BFA issuance API.
- Native/core amounts retain full u64 via BigInt; WebRGB decimal burn amounts
  remain strings and its ordinary numeric amounts enforce JS-safe integers.
- Dart uses named/typed argument classes. decodeRgbInvoice takes a string;
  the transport host handles any wire-level object form.
- One store object is required across BurnOperations wrappers around a wallet.
  Different store instances cannot silently share in-memory recovery state.
- Password and native external-signer unlock forward ethRpcUrl. The latter
  uses RLN 0.16's request API, a deliberate bridge improvement over RN's flat
  entrypoint. External-signer burn remains unsupported. Never log RPC credentials.
- New RLN importRgbContract/importRgbTransferConsignment methods are not
  exported by RN; Flutter does not add unsupported stable wallet surface.

## Verification Scope

The unit suite ports the upstream journal/provider failure cases and extends
them with revocation revision races, typed corruption failures, cross-wallet
journal binding and isolated proof hashing. Native tests cover input boundaries
and bridge failures. They are not funded BFA burn or external payout evidence.
Funded burns, Ethereum RPC/reject-list behavior, restart recovery and both
platform release matrices remain required before a qualified release claim.
