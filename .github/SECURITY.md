# Security Policy

## Supported version

This portfolio project is maintained on the `main` branch. Historical commits,
forks, and independently deployed environments are not supported releases.

| Version | Security updates |
| --- | --- |
| `main` | Supported |
| Historical commits | Not supported |

## Report a vulnerability

Do not open a public issue for a suspected vulnerability. Use GitHub's
**Security** tab to submit a private vulnerability report or private security
advisory to the repository owner.

Include:

- The affected file, component, image digest, or dependency version.
- The vulnerability identifier, if one exists.
- Reproduction steps or a minimal proof of concept.
- The realistic impact and required attacker access.
- Any known fixed version or mitigation.

Do not include real credentials, personal data, or destructive test results.
Do not test against a live AWS endpoint or account without the account owner's
explicit authorization.

## Supply-chain findings

For a dependency or container finding, include the scanner name and database
date, package path, installed version, fixed version, and whether the package is
reachable at runtime. Scanner output alone is useful evidence but does not by
itself establish exploitability.

The repository intentionally keeps fixable `HIGH` and `CRITICAL` findings visible
in its automated gates. Exceptions should be narrow, time-limited, and justified;
global CVE suppression is not an accepted remediation.

## Project scope

The default deployment is a short-lived portfolio lab. Public AWS-hostname
endpoints use HTTP and must not handle sensitive or production data. Operational
security assumptions and safer access options are documented in the
[user guide](../docs/user-guide.md).
