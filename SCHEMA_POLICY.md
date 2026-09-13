# Schema Policy

How database migrations work in this workspace. Adopted 2026-08-30, replacing the previous
edit-in-place practice for schema only.

## The rule

> **An applied migration is immutable. Every schema change is a new file.**

Everything below follows from that line. Flyway's checksum validation is not an obstacle to work
around -- it is the mechanism that enforces this.

**Forward-only.** No down-migrations. They are rarely tested, frequently wrong, and cannot restore
data a `DROP COLUMN` destroyed. Recovery from a bad migration is a new migration that fixes it.

## This does NOT change the rule for application code

The standing practice -- no shims, no adapters, no `@Deprecated` beside its replacement, delete and
rewrite in one step -- still governs **code**. It no longer governs **migrations**.

Stated explicitly because the two read as contradictory otherwise, and applying the code rule to a
migration is what caused the incident below.

## Practice

**Naming:** `V<YYYYMMDDHHMMSS>__short_description.sql`. Sequential `V2`, `V3` collide the moment two
branches each add a migration.

> **When naming and immutability conflict, immutability wins.** A sequentially-named migration that
> has already been applied cannot be renamed: the version in `flyway_schema_history` would no longer
> resolve to a file, and the next boot fails with *detected applied migration not resolved locally*.
> `WalletService/V2__money_timestamps_tz.sql` and `V3__index_wallet_topup_gateway_order_id.sql` are
> in exactly that position — both are present in the deployed revision — so they are grandfathered
> in `validate_phase4.py`'s `GRANDFATHERED_VERSIONS`, and `VERSIONS-GRANDFATHER-CURRENT` deletes the
> exemption if the file ever goes. The naming rule still fails any **new** migration. Recorded
> 2026-09-11.

**One logical change per file**, named so a reviewer knows what it does without opening it.
`add_missing_columns` fails that test; `add_city_id_to_delivery_executives` passes.

**Expand/contract for anything destructive.** A rename or type change is never one migration:

```
release N     add the new column, backfill it, write to both     (old column still works)
release N+1   readers use only the new column                    (no schema change)
release N+2   drop the old column                                (nothing references it)
```

This is what makes a deploy safe when old and new code briefly run together, and what makes a
rollback safe -- crossing an additive migration is fine, crossing a destructive one is not.

**`R__` repeatable migrations** for views, functions and triggers, so those objects live in one file
that reads as current state rather than accumulating `CREATE OR REPLACE` versions.

**Hibernate never owns the schema.** `ddl-auto: validate` everywhere -- already true in every
service. Flyway is the single writer; Hibernate only checks agreement.

**Baseline squash is a release-boundary activity**, not a way to keep editing `V1`. Legitimate when
every environment is known to be at or past a version; not legitimate as routine.

## Two things that cost real time

**`validate-on-migrate` defaults to true and is not overridden.** Editing a migration that a database
has already applied is a **failed boot**, not a warning. The service will not start.

**Do not reproduce Flyway's checksum by hand.** A CRC32-over-lines implementation was tried on
2026-08-30 and disagreed with *both* stored rows -- including a migration that had never been
edited. The mismatch was the algorithm, not the files. Compare file contents directly, or read
`flyway_schema_history`.

## Which databases hold data worth keeping

Every database reachable through the deployed environment currently does: seeded restaurants,
registered users, saved delivery addresses, order history. So the immutability rule applies to all
of them, not just a nominal "production".

Counts verified against the filesystem 2026-09-11; every row had to be corrected or confirmed,
because the table had drifted since it was written on 2026-08-30 and a stale count is how a service
looks like it has no migrations to preserve.

| Service | Baseline | Additive migrations |
|---|---|---|
| `CampaignService` | 1 | 0 |
| `CommunicationIntegration` | 1 | 0 |
| `CommunicationService` | 1 | 0 |
| `CustomerApplication` | 1 | 0 |
| `DeliveryExecutiveApplication` | 1 | 5 |
| `GovernmentIDValidationService` | 1 | 1 |
| `IdentityService` | 1 | 0 |
| `LedgerService` | 1 | 0 |
| `ONDCIntegrationService` | 1 | 0 |
| `PaymentGatewayIntegration` | 1 | 0 |
| `RestaurantApplication` | 1 | 5 |
| `ReviewsService` | 1 | 1 |
| `WalletService` | 1 | 2 |

`CommonLibrary` is excluded deliberately: `db/migration/common` is a shared overlay applied alongside
every service's own baseline (see `flyway.locations`), so it has no baseline of its own.

## Enforcement

- `validate_core_services.py` -- `CI-ROOT-POM`, and the migration checks
- `Deployment/validate_phase4.py` -- `APPLIED-MIGRATIONS-UNCHANGED` compares each migration against
  the revision recorded in `.versions`, so an edit to an already-shipped file fails before deploy
- `ADD-COLUMN-TOLERATES-EXISTING-ROWS` -- a `NOT NULL` column with no `DEFAULT` fails against a
  non-empty table, so it is rejected outside the baseline
