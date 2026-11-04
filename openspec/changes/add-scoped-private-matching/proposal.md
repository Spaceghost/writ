# Scoped private matching

## Example

A team imports a design document. The importer and an invited partner approve
comparing that exact upload with a particular snapshot of the partner's design
collection. A designated reviewer may receive at most three opaque case handles
for qualifying matches. The reviewer receives no document text, collection
listing, or permission to delete anything. An interrupted mandatory comparison
leaves the import awaiting review rather than marking it clean.

The first profile uses a confined matcher that both parties explicitly trust to
see their inputs. Cryptographic comparison without that shared trust is a
separate, later profile.

## Why

Writ preserves known origins and obligations; it cannot recover an origin omitted
from an external import. A bounded comparison can supply evidence for an import
decision without opening a global search across other people's data. Its results
also disclose information, so comparison authority alone is insufficient.

## What Changes

Introduce [scoped-private-matching](specs/scoped-private-matching/spec.md), with:

- Joint approval of immutable inputs, complete declared corpus snapshots, a
  pinned matcher, and an exact result-disclosure contract.
- A first trusted-matcher profile for exact equality, with canonical chunk
  matching and cryptographic profiles admitted only after separate qualification.
- Limits on results and cumulative queries, enforced before disclosure and
  preserved across retries and recovery.
- Protected, provenance-bearing receipts that distinguish a completed scoped
  search from an incomplete one and grant no follow-up authority.

This is proposed behavior. No matcher, private-set-intersection protocol,
comparison service, or automated import classifier is implemented by this change.

## Capabilities

### New Capabilities

- `scoped-private-matching`: Compare an approved import with specifically approved
  corpus snapshots and release only the agreed evidence to the agreed recipient.

### Modified Capabilities

None. Existing monotone provenance and authority contracts remain in force.
Any authorized reduction of result restrictions uses the separately proposed,
versioned controlled-disclosure contract; it is not an implicit change to the
current source-policy representation.

## Impact

Future Bend components will own search contracts, admission, accounting,
representation registration, result validation, and receipt publication. The
enforcing host must protect matcher memory, derived indexes, and every output
channel. A later cryptographic profile needs its own protocol review and
implementation evidence. Similarity supplies evidence, not an ownership verdict
or a guarantee that an import contains no restricted material.

## Dependencies

- [add-authenticated-grant-issuance](../add-authenticated-grant-issuance/proposal.md)
- [add-confined-transform-execution](../add-confined-transform-execution/proposal.md)
- [add-controlled-disclosure](../add-controlled-disclosure/proposal.md)
- [add-durable-publication](../add-durable-publication/proposal.md)
