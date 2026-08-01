# Security

Do not open public issues containing credentials, tokens, private hostnames, personal paths, or shell history.

Report suspected vulnerabilities or accidental secret exposure through GitHub private vulnerability reporting when it is enabled. Until then, contact the maintainer through the private contact method listed on the GitHub profile.

Include:

- affected version or commit;
- reproduction steps;
- expected and observed behavior;
- impact assessment;
- whether credentials may have been exposed.

The project treats user-owned Zsh files as executable code. `zshenv` validates configuration structure and Zsh syntax, but cannot prove that arbitrary custom shell code is safe or free of side effects.
