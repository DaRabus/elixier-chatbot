# Connecting Microsoft Teams

Teams does not let bots connect out; it calls a public HTTPS webhook. The chain is:

`Teams user -> Azure Bot Service -> https://<your-host>/api/messages -> this app`
and back: `this app -> Bot Framework service URL -> Teams`.

## 1. Azure Bot and app registration

1. In the Azure portal create an **Azure Bot** resource, type **Single Tenant**, and let it create a new
   Entra app registration (Microsoft retired creating new multi-tenant bots).
2. Collect:
   - Application (client) ID -> `TEAMS_APP_ID`
   - Directory (tenant) ID -> `TEAMS_TENANT_ID`
   - Certificates & secrets -> new client secret (value) -> `TEAMS_APP_SECRET`
3. Bot resource -> **Configuration** -> *Messaging endpoint*: `https://<your-host>/api/messages`.
4. Bot resource -> **Channels** -> enable **Microsoft Teams**.

## 2. Public endpoint

- Production: reverse proxy with a valid certificate forwarding to the app's `PORT` (default 3978).
- Development: a tunnel, e.g. `devtunnel host -p 3978 --allow-anonymous` or ngrok; use its URL as messaging endpoint.

## 3. Teams app

Create the app in the Teams **Developer Portal** (or write `manifest.json`):

- Bot: use your `TEAMS_APP_ID`; scopes **Personal**, **Team**, **Group chat**.
- Upload it (*Apps -> Manage your apps -> Upload a custom app*) or have an admin publish it to the org.

## 4. Find the ids you need

- Start the bot (`CHAT_ADAPTER=teams`), open a 1:1 chat and send `/id`. The `user_id` is your Entra object id:
  put it into `ADMINS` (and `ALLOWED_USERS` if you restrict access).
- Add the bot to your team channel, post `@Bot /id` there. The `chat_id` is the channel's conversation id
  (looks like `19:...@thread.tacv2`). Put it into `TEAM_CHAT_ID`. If it contains `;messageid=...`, drop that part and
  everything after it, otherwise escalations post into one thread.
- Restart the bot after changing variables.

## Behavior in Teams

- 1:1 chat: every message goes to the bot.
- Channels and group chats: Teams only delivers messages that @mention the bot. Each channel thread is its own
  conversation (own history).
- The bot's replies support Teams' markdown.

## Authentication details

Incoming: `Chatbot.Chat.Teams.Auth` validates the bearer JWT with Microsoft's keys from
`login.botframework.com` (RS256, issuer `https://api.botframework.com`, audience = your app id, not expired) and checks that
the token's `serviceurl` claim matches the activity - so the bot's own token is never sent to a foreign URL.
Outgoing: client-credentials token from `login.microsoftonline.com/<tenant>` with scope
`https://api.botframework.com/.default`, cached until shortly before expiry.
