# Security Policy

VSLA Ledger stores financial records of real savings groups, so we take security reports seriously.

## Reporting a vulnerability

**Please don't open a public issue.** Instead, use GitHub's
[private vulnerability reporting](../../security/advisories/new) for this repository, or email
the maintainers at **[contact email to be added]**.

Include what you found, how to reproduce it, and what you think the impact is. We'll reply within
a few days and keep you updated until it's fixed. With your permission, we'll credit you.

## What's in scope

- Reading or changing another group's records
- Getting data off a locked or encrypted device database
- Secrets accidentally committed to the repository
- Sync paths that could lose, duplicate or alter money records

## Design notes

- The on-device database is encrypted (SQLCipher); its key is stored in Android Keystore.
- No API keys or backend config files are committed. Contributors use their own.
- The app records savings. It never moves real money.

## Supported versions

Until the first stable release, only the latest `main` is supported.
