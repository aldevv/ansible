# Ansible — local provisioning

Self-hosted Ansible playbook that bootstraps this user's Linux machine. Entry point: `local.yml` (or `local-mac.yml` on macOS). Idempotent; re-running is safe.

## Layout

- `local.yml` — top-level play. Loads roles in order, then imports task files. Defines vars (`home`, `work`, `projects`, `code`, `programs`, `repos`, `builds`, `bin`, `dotfiles`).
- `roles/` — reusable units. Always invoke via `include_role` or `roles:` block:
  - `update` — `apt update` / pacman / dnf depending on `ansible_os_family`. Other roles `include_role: update` at the top.
  - `base-devel` — system compilers + dev tooling per OS family (`tasks/{arch,debian,redhat}.yml`).
  - `core` — bigger app installs that don't fit `tasks/install/`. Has `tasks/custom/{python,rust}.yml`.
  - `auth` — credential bootstrap (gpg, ssh, etc.).
- `tasks/` — flat task files imported by `local.yml`.
  - `tasks/install/<tool>.yml` — single-tool installers. Categories:
    - root-level (`fnm.yml`, `rg.yml`, `fd.yml`, `slack.yml`, `zsh.yml`, `nvim.yml`, `nix.yml`, `hunk.yml`).
    - `install/binary/` — drop a single static binary (`pomo`).
    - `install/compressed/` — extract a tarball release (`bob`, `ripgrep_all`).
    - `install/deb/` — `apt install ./pkg.deb` (`docker`, `obsidian`).
    - `install/snap/` — snap packages (`zoom`).
    - `install/script/` — vendor curl-pipe-sh installers (`doppler`, `eget`).
  - `tasks/build/` — compile-from-source (`suckless`, `xmonad`, `picom`, `dunst`, `autorandr`, `copyq`, `gitsecret`, `snixembed`, `neovim`, `neovim-nightly`).
  - `tasks/system/` — host config (`auto-suspend`).
  - `tasks/hardware/` — keyboard / touchpad / screen / udiskie.
  - Top-level (`folders.yml`, `fonts.yml`, `wallpapers.yml`, `dotfiles.yml`, `wiki.yml`, `notes.yml`, `sudoers.yml`, `root.yml`, `talon.yaml`, `work.yml`).

## Conventions

- **Tags**: every play/block uses `tags:` with at minimum `install` plus the tool name (e.g. `- install`, `- hunk`). Add the role bucket (`core`, `fnm`, `auth`) when the task is part of a role's bootstrap. Run a single tool with `ansible-playbook local.yml --tags <tool>`.
- **Idempotency**: prefer modules with built-in idempotency (`apt`, `community.general.npm`, `community.general.github_release`, `unarchive`, `file: state=link`) over raw `shell` + `creates:`. Only fall back to shell when no module fits.
- **`become`**: only at the task level that needs root. Don't blanket-elevate the whole play.
- **Variables**: source from env via `lookup('env', 'X')` with a sensible default (`{{ lookup('env', 'WORK') or ansible_env.HOME ~ '/work' }}`). Don't hardcode `/home/kanon/...`.
- **OS families**: dispatch to `tasks/{arch,debian,redhat,freebsd}.yml` with `when: ansible_facts['os_family'] == 'X'`. Roles with multi-OS support follow that structure.
- **Collections used**: `community.general` (installed). For npm globals: `community.general.npm: { name: pkg, global: true }`. For GitHub release downloads: `community.general.github_release` then unpack via `unarchive`.

## Adding a new tool

1. Identify how the upstream ships (system package? curl-pipe-sh? GitHub release tarball? single static binary? .deb? snap? npm? cargo? source?).
2. Pick the matching pattern from **Patterns by upstream type** below and copy the skeleton.
3. Save as `tasks/install/<bucket>/<tool>.yml` (or root-level `tasks/install/<tool>.yml` for common ones).
4. Wire into `local.yml` near other tools of the same kind. Ordering matters:
   - `npm`-installed tools go after `tasks/install/nodejs.yml`.
   - Cargo tools go after the `core` role (which runs `roles/core/tasks/custom/rust.yml`).
   - Tools using fnm-managed Node go after `fnm.yml`.
   - Tools using nix go after `tasks/install/nix.yml`.
5. Test in isolation: `ansible-playbook local.yml --tags <tool> -K`. Then test in docker (see "Testing in Docker").

### Universal task-file shape

Every install task file is a list of plays/blocks. The common skeleton:

```yaml
- name: install <tool>
  block:
    - name: <step 1>
      <module>:
        ...
    - name: <step 2>
      <module>:
        ...
  vars:                       # optional — only if any step interpolates them
    author: <github-user>
    repo: <github-repo>
    prefix: <release-asset-prefix>
    extension: tar.gz         # or zip, deb, ...
  tags:
    - install
    - <tool>
```

Rules:
- **Always** include `tags: [install, <tool>]`. Single-step tasks list tags directly; multi-step tasks lift `tags:` onto the outer `block:`.
- Use `{{ home }}`, `{{ bin }}` (= `{{ home }}/.local/bin`), `{{ builds }}` from `local.yml`. Never hardcode `/home/<user>/...`.
- `become: true` lives on the **specific task** that needs it (apt, snap, system file write), not on the outer block.
- Reach for a real module before `shell:`. The order of preference: `apt`/`pacman`/`homebrew` → `community.general.github_release` → `get_url` / `unarchive` / `copy` / `file` → `shell`.
- Idempotency: rely on the module's own state checks, or guard `shell:` with `args.creates:` / `stat:` precheck. Re-running the play must be a no-op when the tool is already installed.

## Patterns by upstream type

### A. System package (apt / pacman / brew)

When the tool is in the OS package manager. Reference: usually inline in role files (e.g. `roles/base-devel/tasks/debian.yml`), but standalone form:

```yaml
- name: install <tool> (system package)
  become: true
  package:                          # auto-dispatches to apt/pacman/brew/dnf
    name: <pkg-name>
    state: present
  tags:
    - install
    - <tool>
```

For OS-specific package names, branch with `when: ansible_facts['os_family'] == 'Debian'`.

### B. Vendor curl-pipe-sh installer

When upstream provides a single `curl ... | sh` install script. Reference: `tasks/install/script/doppler.yml`, `tasks/install/script/eget.yml`.

```yaml
- name: install <tool>
  shell: |
    curl -fsSL <vendor-install-url> | sh
    # if the script drops the binary in cwd, move it:
    mv <tool> {{ bin }}
  args:
    creates: "{{ bin }}/<tool>"
  tags:
    - install
    - <tool>
```

### C. GitHub release — single static binary

For tools that publish one prebuilt binary as a release asset. Reference: `tasks/install/binary/pomo.yml`.

```yaml
- name: install {{ repo }}
  block:
    - name: get latest {{ repo }} tag
      community.general.github_release:
        user: "{{ author }}"
        repo: "{{ repo }}"
        action: latest_release
      register: <tool>_release

    - name: download {{ repo }} binary from github releases
      get_url:
        url:  "{{ download_url }}/{{ <tool>_release['tag'] }}/{{ prefix }}"
        dest: "{{ bin }}/{{ repo }}"

    - name: make executable
      file:
        path: "{{ bin }}/{{ repo }}"
        mode: 0755
  vars:
    author: <github-user>
    repo:   <github-repo>
    prefix: <release-asset-name>            # e.g. pomo-linux-amd64
    download_url: "https://github.com/{{ author }}/{{ repo }}/releases/download"
  tags:
    - install
    - <tool>
```

### D. GitHub release — tarball/zip → unarchive → copy or symlink

For compressed multi-file releases. Reference: `tasks/install/compressed/bob.yml`, `tasks/install/compressed/ripgrep_all.yml`. There are two sub-flavors:

**D1. Copy a single binary out of the archive into `{{ bin }}`** (bob style):

```yaml
- name: install {{ repo }}
  block:
    - name: get latest {{ repo }} tag
      community.general.github_release:
        user: "{{ author }}"
        repo: "{{ repo }}"
        action: latest_release
      register: <tool>_release

    - name: unarchive {{ repo }}
      unarchive:
        src:  "{{ download_url }}/{{ <tool>_release['tag'] }}/{{ prefix }}.{{ extension }}"
        dest: "/tmp"
        remote_src: true

    - name: copy {{ repo }} to {{ bin }}
      copy:
        src:  "/tmp/{{ prefix }}/{{ repo }}"
        dest: "{{ bin }}"

    - name: make executable
      file:
        path: "{{ bin }}/{{ repo }}"
        mode: 0755
  vars:
    author: <github-user>
    repo:   <github-repo>
    prefix: <archive-prefix>                # e.g. bob-linux-x86_64
    extension: zip                          # or tar.gz
    download_url: "https://github.com/{{ author }}/{{ repo }}/releases/download"
  tags:
    - install
    - <tool>
```

**D2. Symlink the binary inside `{{ builds }}/<name>/` from `{{ bin }}`** (rg/fd style — used when you want to keep the full extracted tree around):

```yaml
- name: install {{ name }}
  block:
    - name: check latest {{ name }}
      uri:
        url: https://api.github.com/repos/{{ author_repo }}/releases/latest
        return_content: true
      register: latest

    - name: create {{ builds }}/{{ name }} directory
      file:
        path:  "{{ builds }}/{{ name }}"
        state: directory

    - name: download and unarchive {{ name }}
      loop: "{{ latest.json.assets }}"
      when: "'{{ pattern }}.{{ ext }}' in item.name"
      unarchive:
        remote_src: yes
        src:  "{{ item.browser_download_url }}"
        dest: "{{ builds }}/{{ name }}"
        mode: 0755

    - name: find extracted folder name
      shell: "ls {{ builds }}/{{ name }}"
      register: folder

    - name: create {{ name }} symlink
      file:
        src:   "{{ builds }}/{{ name }}/{{ folder.stdout }}/{{ name }}"
        dest:  "{{ home }}/.local/bin/{{ name }}"
        state: link
  vars:
    author_repo: <user>/<repo>
    name:        <bin-name>
    pattern:     x86_64-unknown-linux-musl    # match against asset filenames
    ext:         tar.gz
  tags:
    - install
    - <name>
```

### E. .deb from GitHub release

Reference: `tasks/install/deb/obsidian.yml`.

```yaml
- name: install <tool>
  block:
    - name: get latest <tool> tag
      community.general.github_release:
        user: "{{ author }}"
        repo: "{{ repo }}"
        action: latest_release
      register: <tool>_release

    - name: download .deb
      get_url:
        url:  "https://github.com/{{ author }}/{{ repo }}/releases/download/{{ <tool>_release['tag'] }}/<asset-pattern>.deb"
        dest: "{{ home }}/Downloads/<tool>.deb"

    - name: install via apt
      become: true
      apt:
        deb:   "{{ home }}/Downloads/<tool>.deb"
        state: present
  vars:
    author: <github-user>
    repo:   <github-repo>
  tags:
    - install
    - <tool>
```

### F. apt with vendor repo + GPG key

When the tool is in a vendor's apt repo (Docker, Microsoft, GitHub CLI). Reference: `tasks/install/deb/docker.yml`.

```yaml
- name: install <tool>
  block:
    - name: add <tool> apt repository
      become: true
      shell: |
        if [[ -f /etc/apt/keyrings/<tool>.asc ]]; then
          return 0
        fi
        apt update
        install -m 0755 -d /etc/apt/keyrings
        curl -fsSL <vendor-key-url> -o /etc/apt/keyrings/<tool>.asc
        chmod a+r /etc/apt/keyrings/<tool>.asc
        echo "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/<tool>.asc] <vendor-repo-url> $(. /etc/os-release && echo "$VERSION_CODENAME") stable" | tee /etc/apt/sources.list.d/<tool>.list > /dev/null
        apt update

    - name: install <tool> via apt
      become: true
      apt:
        name:
          - <pkg-1>
          - <pkg-2>
  tags:
    - install
    - <tool>
```

### G. snap

Reference: `tasks/install/snap/zoom.yml`.

```yaml
- name: install <tool>
  become: true
  snap:
    name:
      - <snap-name>
  tags:
    - install
    - <tool>
```

### H. npm-installed tool — ALWAYS `--prefix {{ home }}/.local`

System-global `npm install -g` lands the binary in npm's configured prefix — on this user's machine that's an fnm-managed path that changes per Node version, and on a fresh box it would write to `/usr/lib/node_modules`. **Neither is correct.** The user keeps user-scoped binaries at `~/.local/bin`.

Always use `--prefix {{ home }}/.local` so the binary symlink lands in `{{ home }}/.local/bin/<tool>`:

```yaml
- name: install <tool>
  shell: npm install -g --prefix {{ home }}/.local <npm-package>
  args:
    creates: "{{ home }}/.local/bin/<binary>"
  tags:
    - install
    - <tool>
```

In `local.yml`, ensure `nodejs.yml` is imported before any npm tool:

```yaml
- import_tasks: tasks/install/nodejs.yml
- import_tasks: tasks/install/<tool>.yml
```

Reference: `tasks/install/hunk.yml`.

**Don't use `community.general.npm` with `global: true`** — the module ignores `path:` when global, so you can't pin the prefix.

**Don't bake the Node bootstrap into individual tool tasks** — that logic lives once in `nodejs.yml` (Debian via NodeSource, Arch via pacman, macOS via Homebrew, gated on `node_major < 18`). Future npm tools just import `nodejs.yml` once via `local.yml`.

### I. Composite installer

When one logical "install" wraps several others. Reference: `tasks/install/nvim.yml`.

```yaml
- name: install <feature> and requirements
  block:
    - include_tasks: tasks/install/<dep1>.yml
    - include_tasks: tasks/install/<dep2>.yml
    - include_tasks: tasks/install/<dep3>.yml
```

No `tags:` here — each included file carries its own.

### J. Custom multi-step (`shell:` heavy)

When no module fits — multi-step shell flows with stat-based idempotency. Reference: `tasks/install/zsh.yml`, `tasks/install/fnm.yml`. Use sparingly. Pattern:

```yaml
- name: check if <tool> already installed
  stat:
    path: ~/.<tool>/marker
  register: <tool>_check

- name: install <tool>
  when: <tool>_check.stat.exists == False
  block:
    - name: <step that does the install>
      shell: ...
    - name: <follow-up step>
      shell: ...
  tags:
    - install
    - <tool>
```

## Testing in Docker

A `Dockerfile` builds an Ubuntu jammy image with a non-root `kanon` user (`pass`) and runs the playbook:

```bash
cd ~/.local/share/ansible
docker build --target final -t ansible-test .
# Run a single tag:
docker run --rm -e TAGS="-t hunk" ansible-test
# Default (dotfiles + neovim + zsh + zsh_plugins):
docker run --rm ansible-test
```

The image copies the current playbook in at build time, so rebuild after each change. There's also `Dockerfile.arch` for testing the Arch path.

## Debugging

- `debug.yml` — scratch playbook for one-off testing. Don't commit logic into `local.yml` until proven there.
- `core` role does heavy installs; comment lines in `roles/base-devel/tasks/<os>.yml` to speed up iteration.
- `install.sh` (root) and `install-fast.sh` are shell wrappers around `ansible-playbook -t install`.

## Don'ts

- Don't write task files outside `tasks/`. Roles (`roles/<name>/tasks/`) are for reusable bundles; one-off installs go in `tasks/install/`.
- Don't add absolute paths to the user's home — use the vars defined in `local.yml`.
- Don't skip tags; running the whole play unfiltered is slow and reinstalls everything.
- Don't commit secrets. Use ansible-vault or `lookup('env', ...)` if a value must come from env.
