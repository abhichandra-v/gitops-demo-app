# 0001 — LF line endings and a script-backed `make doctor`

**Context.** The repo is developed on Windows (Git Bash) but its scripts and
manifests run in Linux containers and GitHub Actions. CRLF in a shell script
breaks it there. `make` is also not always present on a fresh Windows machine,
which makes a prerequisite check written only as a Makefile recipe unusable
exactly when it is needed.

**Decision.** `.gitattributes` forces `eol=lf` for all text files. The
prerequisite check lives in `scripts/doctor.sh`; `make doctor` just calls it.

**Consequence.** Scripts behave the same locally and in CI. The check can be run
as `bash scripts/doctor.sh` before `make` is installed. `doctor` only reports;
it never installs anything.
