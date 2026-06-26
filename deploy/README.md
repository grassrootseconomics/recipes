# Recipes Deployment Notes

Recipes has two deployable pieces:

- `recipes.grassecon.org`: static Godot Web client.
- `recipes-server.grassecon.org`: authoritative Node server API/WebSocket endpoint.

The server hostname is DNS-based because the final IP is not known yet. Point `recipes-server.grassecon.org` at the remote machine once it exists, or update `client/data/servers.json` before exporting the Web client if a different hostname is chosen.

## Server

On the remote machine:

```bash
git clone https://github.com/grassrootseconomics/recipes.git /opt/recipes
cd /opt/recipes
npm ci
npm run build
HOST=127.0.0.1 PORT=3000 node server/dist/index.js
```

For a long-running deployment, adapt:

```text
deploy/systemd/recipes-server.service
deploy/nginx/recipes-server.example.conf
```

The nginx example includes WebSocket upgrade headers.

## Web Client

Build the Web client:

```bash
cd /opt/recipes
npm run export:web
sudo rsync -a --delete client/web/ /var/www/recipes/
```

Serve `/var/www/recipes` over HTTPS using:

```text
deploy/nginx/recipes-web.example.conf
```

Godot Web requires a secure browser context for normal public use, so production should use HTTPS. The nginx example also sets the cross-origin isolation headers Godot expects.

## Smoke Checks

```bash
curl -s https://recipes-server.grassecon.org/health
curl -I https://recipes.grassecon.org/
```

Then open `https://recipes.grassecon.org`, select `Grassroots Recipes Server`, create a public table, and verify another browser can see and join that table from the public table list.
