# Security

Allostatik ships files, not a service. Nothing runs in the background and there is no server to attack. Two surfaces are worth reporting on:

1. **The installers.** `init.sh`, `npx allostatik`, and `pip install allostatik` run on your machine and write into a directory you name.
2. **The templates they place.** Those files are instructions an AI reads and acts on inside your project, so a flaw in them can become an action taken on your behalf.

## Reporting a vulnerability

Use GitHub's private reporting: **[Report a vulnerability](https://github.com/allostatik/allostatik/security/advisories/new)**. It opens a private thread with the maintainer — not an Issue, and not visible to anyone else. Public Issues stay public forever, so don't file anything exploitable there.

Without a GitHub account, or if the form won't cooperate, email **security@allostatik.com**. Either route stays private.

Useful to include: what you ran, what happened, and what someone could do with it. A rough reproduction beats a polished writeup.

This is a pre-1.0 project with one maintainer. Expect a first reply within a few days rather than within hours. You'll hear back either way, including when the answer is "working as intended" and why.

## The bar I'm aiming at

Allostatik targets **[OpenSSF OSPS Baseline Level 1](https://baseline.openssf.org/)** — the entry tier for open source projects. Its security-policy requirement (OSPS-VM-02) is that the documentation names a security contact; the OpenSSF Scorecard `Security-Policy` check is the automated form of the same question. Level 1 is the honest bar for a pre-1.0 project with one maintainer; the higher tiers assume a team and a user base this doesn't have yet.

I'm naming it so you can hold me to it. If something here falls short of that bar, tell me — that counts as a report. So does arguing the bar is the wrong one for a tool that writes instruction files into your project.

## In scope

- **The installers** — arbitrary code execution, writing outside the target directory, the existing-`allostatik/` collision guard failing open, or the template fetch falling back to something it shouldn't.
- **Template sourcing** — anything that lets a third party change what lands on disk. All three installers fetch `main` as a tarball at install time. The npm and pip packages fall back to a copy bundled at publish time, and `init.sh` halts instead. Upgrades fetch a release *tag*, resolve it to a commit where they can, and work from a parked copy.
- **The published packages** — integrity of `allostatik` on npm and PyPI — and of the deprecated `allostat` packages, which stay published as pointers — including typosquats you come across.
- **Template content** — a shipped file that steers an assistant toward an action a reasonable user wouldn't sanction: reaching outside the project, writing where it shouldn't, or pulling credentials into a context file that then gets committed.
- **The upgrade path** — `UPGRADING.md` and `CHANGELOG.md` are fetched by an adopter's AI and steer edits to the instruction files it already follows. Anything that lets fetched content escape the placed *Upgrade contract* — a write outside the three stamped regions, an apply without a shown diff, a suggested command that gets run, render-hidden characters in a shipped file — is in scope. So is a tag or release that doesn't match what the package registries carry for the same version. What the path does and doesn't defend against is the next section, and I'd rather you held me to it than assumed more.

## What the upgrade path defends against — and what it doesn't

You are trusting the tool's repository at one tag, and your own reading of each diff. The stamps on your regions are drift fingerprints: they prove a region changed, not who changed it. Whoever supplies a body can supply its matching stamp. A compromised maintainer account could make the tag, the routine, the changelog, and the published packages all lie together. Against that, the diff you read is the check, and the routine's package cross-check is a second opinion. That cross-check works because releases are committed and tagged before publishing, so npm's `gitHead` names the release commit. A mismatch with what the tag resolves to is visible to anyone.

**It defends against:**

- an install silently falling behind;
- your own edits being overwritten — a customized region is never auto-replaced;
- a fetched document rewriting its own rules — the contract is placed, not fetched, so a fetched document can neither waive a rule by omitting it nor narrow one. A narrowing halts;
- the bytes you reviewed differing from the bytes applied — everything is applied from the parked copy you reviewed, and re-hashed after the write;
- render-hidden text in a shipped file — the routine scans for it and halts;
- a half-finished upgrade resuming on a different reference;
- a parked file being mistaken for instructions — parked files carry non-instruction names and open with a visible *data under review* line.

**It does not defend against:**

- a malicious maintainer;
- the repository and both package registries compromised at once;
- an approval you gave without reading;
- a compromised AI surface;
- anyone who already has write access to your project.

## Out of scope

- **The assistant's output.** It's generated and non-deterministic (see the README's disclaimer). A wrong or unhelpful answer isn't a vulnerability.
- **Flaws in Claude, GitHub, npm, or PyPI themselves.** Report those to them.
- **Anything that already assumes write access** to your machine or your repository.

## Supported versions

Pre-1.0. Fixes go to the latest release only — currently the 0.3.x line.

## Notes for anyone installing

- `init.sh` is short and readable. If piping it to a shell bothers you, read it first, or clone the repo and run it locally — both paths are supported and place the same files.
- `--offline` (or `ALLOSTATIK_OFFLINE=1`; the legacy `ALLOSTAT_OFFLINE=1` is accepted until 1.0) makes the npm and pip installers use their bundled templates instead of fetching.
- The `allostatik/` files are plain text in your repository, and they go wherever your repository goes. Keep credentials out of them — point at where a secret lives rather than pasting it in.
