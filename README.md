# zorp Mail for Omarchy

An envelope in the Omarchy bar with the unread count from
[zorp](https://github.com/perlsaiyan/zorp)'s local cache beside it. Hover it for
the newest mail in the watched folders; click to open zorp.

Built for Omarchy 4.x (Quattro shell plugins).

## Install

zorp must already be set up with its daemon running (see zorp's `DEPLOY.md`),
and `zorp-focus` must be on `PATH`.

```bash
git clone <this-repo> ~/git/omarchy-zorp-plugin
ln -s ~/git/omarchy-zorp-plugin ~/.config/omarchy/plugins/zorp.mail
omarchy plugin enable zorp.mail --section right
```

The shell does not follow the symlink out to the repo for hot reload; after
editing the QML, run `omarchy restart shell`.

## Using it

| Action | Does |
|---|---|
| Hover | Shows the card: unread count, account, newest messages |
| Left click (icon, count or any row) | `zorp-focus`: raise zorp, or open it |
| Right click | Pin the card open / unpin it |
| Middle click | Re-read the cache now |

Unread rows have an accent bar and a bold sender. The markers after the time
are zorp's own: `!` high importance, `*` flagged, `+` attachments. The envelope
turns the urgent colour when the feed is broken (signed out, no cache, no
matching folder), and the card says why.

## Configuration

Optional, in `~/.config/omarchy/zorp-mail.env` (see `example.env`):

| Variable | Default | Meaning |
|---|---|---|
| `FOLDERS` | `inbox` | Space-separated folders to count and list |
| `LIMIT` | `8` | Messages shown in the card |

The refresh interval and hover behaviour are manifest settings, adjustable in
the Omarchy settings panel.

## How it works

```
bin/omarchy-zorp-update   reads zorp.db (read-only), writes the record
BarWidget.qml             the bar slot: envelope, count, clicks, hover
Panel.qml                 polls the updater, watches the record, draws the card
```

The updater opens `~/.local/share/zorp/zorp.db` with `sqlite3 -readonly`, so it
never takes a lock against the daemon and never talks to Microsoft. It asks
`zorp daemon status` for the sync state, which never starts a daemon. The
record lands in `~/.local/state/omarchy/zorp/mail.json`; run the updater by
hand and the bar repaints.

New-mail desktop notifications come from the zorp daemon itself, not from
this plugin. Set `notify.click_command = "zorp-focus"` in zorp's config to have
clicking one raise the window.

## Caveats

- It reads zorp's cache schema directly, so a zorp release that changes the
  `messages` or `folders` tables can break it. The card will show "could not
  read the zorp cache".
- zorp has no way to open a particular message from outside, so clicking a
  row opens zorp rather than that message.

## License

MIT
