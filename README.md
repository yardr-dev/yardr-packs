# yardr-packs

Packs for [yardr](https://github.com/yardr-dev/yardr) that live outside it: integrations, sources and tools a yard imports with `yardr pack apply <directory>`. Each directory at the top is one pack with a `pack.yaml`; its README says what it does and `SETUP.md` what its operator sets up.

Nothing here is part of yardr itself. A pack's programs are written in whatever language fits them; `.yardr/test` runs `yardr pack check` and each pack's own `test` program.
