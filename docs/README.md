# DailyStore docs

Start here. Read in this order the first time; after that jump to what the task needs.

| File | Read it when |
| --- | --- |
| [overview.md](overview.md) | Always. What the app is, scope, what is done, build history, ideas for later. |
| [development.md](development.md) | Before changing anything. Workflow, CI loop, local testing, conventions, owner preferences. |
| [architecture.md](architecture.md) | Touching app logic, caching, the widget, notifications or storage. |
| [riot-api.md](riot-api.md) | Touching login, reauth, Riot endpoints or valorant-api.com. |
| [ui-design.md](ui-design.md) | Touching any screen. Design language, per-screen layout, the fit-on-one-screen rule, demo mode. |
| [testflight-pipeline.md](testflight-pipeline.md) | Touching `ios/project.yml`, `codemagic.yaml`, signing, versions or the Actions workflow. |
| [decisions.md](decisions.md) | Before proposing an alternative approach. Why things are the way they are, and what not to retry. |

Keep these files current. When a change alters behaviour, scope or a decision, update the
matching doc in the same commit, and add a row to the build history in `overview.md`
when a TestFlight build ships.
