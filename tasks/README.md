# sample get binary from github release, no zip

```yaml
- name: install pomo
  block:
  - name: get latest pomo tag
    community.general.github_release:
      user: "{{author}}"
      repo: "{{repo}}"
      action: latest_release
    register: pomo_release

  - name: download binary from github releases
    get_url:
      url:  "https://github.com/{{author}}/{{repo}}/releases/download/{{ pomo_release['tag'] }}/pomo-linux-amd64"
      dest: "{{ bin }}/pomo"

  - name: "make executable"
    file:
      path: "{{bin}}/pomo"
      mode: 0755
  vars:
    author: rwxrob
    repo: pomo
    path: "{{ bin }}/{{ repo }}"
  tags:
    - install
    - pomo
```
