# WordPress Multisite Docker Environment

A portable, cross-platform WordPress Multisite developer environment using Docker/Podman, Nginx, PHP 8.4, and MySQL 8.4—managed by a built-in GUI control panel.

---

## Developer Quick Start (Clone & Run)

The stack uses a **self-initializing container architecture**. On first launch, it will automatically download WordPress core, configure database connectors, establish database tables, convert the setup into a Multisite network, install translations, and configure directory permissions.

1. **Clone the repository** and enter the directory.
2. **Launch the Control Panel**:
   - **macOS / Linux**:
     ```bash
     cp .env.example .env && ./start.sh
     ```
   - **Windows (CMD / PowerShell)**:
     ```cmd
     copy .env.example .env && start.bat
     ```

This boots the zero-dependency Python manager backend, opens your browser to the Control Panel (default `http://localhost:8000`), and allows you to build, customize, and run your WordPress Multisite stack instantly.

---

## Zero-Dependency GUI Control Panel

The environment features an interactive dark-mode stack manager dashboard (served via [manager.py](./manager.py)).

### Features:
- **Operations Controls**: Easily run `[ Start Stack ]` (rebuilds and launches the containers) and `[ Stop Stack ]` (tears down resources) with a single click.
- **Environment Settings**: Live-modify variables like Local Domain, Port, and Admin Credentials directly in the UI. Changes are synced safely to your `.env` without wiping other configuration.
- **Port Conflict Resolution**: If port `8000` is already in use by another service on your machine, the Stack Manager automatically finds and binds to the next available port (e.g., `8001`, `8002`, etc.) and opens the browser to the correct location.
- **Real-Time Logs**: View container output directly in the console log section.
- **Clean Shutdown**: Hitting `Ctrl+C` in your terminal or clicking `[ Shutdown Panel ]` in the dashboard completely terminates the process and releases the host port instantly.

---

## WP-CLI Host Helper (`./wp`)

To make running command-line operations fast and straightforward, a local wrapper script **[wp](./wp)** is included in the project root.

You can run any standard WP-CLI command from your host terminal without manually shelling into the docker containers:

```bash
./wp <command>
```

### Examples:
- **List registered users**:
  ```bash
  ./wp user list
  ```
- **Install and activate a plugin**:
  ```bash
  ./wp plugin install query-monitor --activate
  ```
- **Export the database**:
  ```bash
  ./wp db export
  ```

*Note: The script automatically handles container target mapping and maps commands to run as the `www-data` user to prevent host permission mismatch issues.*

---

## Multisite Super Admin & Translations

### 1. Automatic Super Admin (Network Admin) Mapping
By default, WordPress's Multisite conversion process does not always promote the primary user to a network super-admin. 
Our custom container configuration in **[docker-entrypoint.sh](./php/docker-entrypoint.sh)** automatically monitors username syncs and grants full **Super Admin** privileges to the user defined as `WP_ADMIN_USER` in the control panel settings.

### 2. Multi-Language Configuration (English & Arabic)
To support multi-language installations, **Arabic (`ar`)** is automatically downloaded and installed alongside the default **English** package during the initial installation phase.

#### Accessing Site-Level Language Settings:
In WordPress Multisite, site administrators cannot download translations on-the-fly. They can only select languages that the Network Admin has already installed on the server.
To allow subsite admins to change their site's language:
1. Navigate to the **Network Settings** panel (`/wp-admin/network/settings.php`).
2. Scroll to the bottom and check the **Language** checkbox under *Enable administration menus*.
3. Save changes. Admins will now see the language selector in their respective `Settings > General` pages.

---

## Customizable Configurations

You can adjust all database configurations, host ports, and admin account details directly inside the GUI control panel **Settings** page or by manually editing the local `.env` file:

```env
# Database Settings
DB_NAME=wordpress
DB_USER=wpuser
DB_PASSWORD=wppassword
DB_ROOT_PASSWORD=rootpassword

# WordPress Site Settings
WP_PORT=8080
WP_URL=http://localhost:8080
WP_TITLE=WordPress Multisite Network
WP_ADMIN_USER=admin
WP_ADMIN_PASSWORD=adminpassword
WP_ADMIN_EMAIL=admin@example.com
```

### Running on Port 80 (e.g., http://wp.localhost)

If you want to access your WordPress Multisite network directly without appending a port number (e.g. `http://wp.localhost` instead of `http://wp.localhost:8080`), set `WP_PORT=80` in the GUI settings or `.env`. 

Depending on your operating system, you may need to adjust local configurations to allow binding to privileged ports (< 1024):

#### Linux (Rootless Podman / Docker)
Rootless containers cannot bind to ports below 1024 by default. Run the following command to allow binding to port 80 as a regular user:
```bash
sudo sysctl -w net.ipv4.ip_unprivileged_port_start=80
```
To make this setting persistent across reboots, run:
```bash
echo "net.ipv4.ip_unprivileged_port_start=80" | sudo tee -a /etc/sysctl.d/99-podman-ports.conf
```

#### Windows
Docker Desktop and WSL2 forward port 80 automatically. If port 80 is blocked by IIS or another system service, stop the HTTP service from an **Administrator Command Prompt**:
```cmd
net stop http
```

#### macOS
Docker Desktop handles port forwarding on port 80 automatically. If the port is in use by the built-in macOS Apache server, stop it:
```bash
sudo apachectl stop
```

---

## Troubleshooting

### "No such file or directory: 'docker-compose'"
If you see an error related to `docker-compose` not found or logs failing to load:
- **Environment PATH issues**: Some shell setups (like Zsh) do not automatically load user bin paths (e.g. `~/.local/bin`) in GUI environments, which can prevent the control panel from finding user-installed compose configurations.
- **Dynamic Selection**: The manager script automatically looks in common locations (`~/.local/bin`, `~/bin`) and dynamically switches between `docker-compose` (legacy) and `docker compose` (v2 plugin).
- **Workaround**: If you still experience issues, run the stack directly from an active terminal shell where your binary paths are sourced, using:
  ```bash
  ./start.sh
  ```

---

## Project Structure

- `docker-compose.yml` - Container orchestration and service layouts.
- `src/wp-content/` - Shared folder for plugins, themes, and uploads. Drop files here to work on them.
- `nginx/default.conf` - Nginx configuration featuring Multisite subdirectory rewrites and relative redirects.
- `php/Dockerfile` - Custom PHP 8.4 FPM image equipped with required extensions and WP-CLI.
- `manager.py` / `manager_ui.html` - Python control panel app and OpenCode-style web GUI.
- `wp` - Local WP-CLI wrapper helper script.
