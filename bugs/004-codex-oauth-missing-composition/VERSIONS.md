# Versions - bug 004

- First seen broken: `@deepseek-ai/dsh` 0.1.1-rc.2, installed bundle on
  2026-09-12.
- Fix applied locally to 0.1.1-rc.2 (2026-09-12): `dsh-base` composition row,
  `dsh-host-apiproxy` authorization RPC, `dsh-client-connection` transport, and
  the Models sign-in panel.
- Re-ported and re-applied to `0.1.5-rc.2` (2026-09-20). 0.1.5-rc.2 removed
  `dsh-host-apiproxy` and its hand-written RPC in favour of generated "Typert
  Remote" namespaces, so the caller surface was rebuilt:
  - `dsh-base/cordis.patch.yml`: mount `@deepseek-ai/dsh-authorization` after
    `credentials` and before `llm-pi-ai` (unchanged fix; the seam is still not
    mounted upstream).
  - `dsh-api-settings-controller/lib/index.js`: new `AuthorizationController`
    (a `TypertRemoteService` with `@Remote`-decorated `list`/`begin`/`status`/
    `answer`/`cancel`). The gateway dispatches it through SRC markers, so no
    generated manifest edit is needed.
  - `dsh-api-remotes/lib/client.js`: the strict client contribution
    (`TYPERT_REMOTE$15`) the browser facade mounts as `ctx.remote.authorization`.
  - `dsh-client-ui-settings-models/lib/client.js`: the Models "Subscription
    sign-in" panel, registered in the `settings.models.footer` list slot.
- Pristine patch bases: `npm pack <pkg>@0.1.5-rc.2` from the npm registry for
  `dsh-base`, `dsh-api-settings-controller`, `dsh-api-remotes`, and
  `dsh-client-ui-settings-models`. Each patch applies with no fuzz and a
  pristine->reapply round-trip reproduces the fixed bytes exactly.
- Fix markers checked by `scripts/check.sh`: composition mount, host
  `authorizationController` service + namespace, client `authorization/begin`
  descriptors + contribution, and the UI panel/copy/`remote.authorization`
  injection.
