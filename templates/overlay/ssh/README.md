# ssh/

Source folder for the container2wsl `ssh-keys` poststrap. **Nothing in this folder except this README
is tracked by git** (see `.gitignore`); the keys exist only in the local checkout of each machine.
Put here what a new distro's `~/.ssh` should contain:

| file | installed as | mode |
|---|---|---|
| `id_*` (private keys) | `~/.ssh/<name>` | 600 |
| `*.pub` | `~/.ssh/<name>` | 644 |
| `config` | appended to `~/.ssh/config`, after the config from any overlay that loads earlier (name order) | 600 |
| `known_hosts` | `~/.ssh/known_hosts` | 644 |

No key is loaded at login: the generated `~/.ssh/config` starts with `AddKeysToAgent yes`, so each
key joins the keychain agent the first time ssh uses it (a passphrase key asks once then).

Before copying, the strap checks this folder's **Windows ACLs** and refuses if anyone but you,
SYSTEM and Administrators has access (the same rule Windows OpenSSH applies to `~/.ssh`), or
if a file is not readable by you. Files only their owner may read show up in WSL as another
user's, so the copy reads them as root: build with `-b sudo`.
Set it right once (replace the path with this overlay's `ssh` folder):

```cmd
icacls "C:\path\to\<overlay>\ssh" /inheritance:r /grant:r "%USERNAME%:(OI)(CI)F" "SYSTEM:(OI)(CI)F" "Administrators:(OI)(CI)F"
```

Getting keys here on a new machine: copy them from your existing `%USERPROFILE%\.ssh`, or build
the distro with `set C2W_SSH_SOURCE=%USERPROFILE%\.ssh` instead of using this folder.
