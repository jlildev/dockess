import http.server
import socketserver
import json
import subprocess
import os
import urllib.parse
import threading
import sys
import shutil

PORT = 8000
PROJECT_DIR = os.path.dirname(os.path.abspath(__file__))
BUNDLE_DIR = sys._MEIPASS if hasattr(sys, '_MEIPASS') else PROJECT_DIR

def get_compose_cmd():
    # Ensure common user binary directories are in PATH
    for path in [os.path.expanduser('~/.local/bin'), os.path.expanduser('~/bin')]:
        if os.path.exists(path) and path not in os.environ.get('PATH', '').split(os.pathsep):
            os.environ['PATH'] = f"{path}{os.pathsep}{os.environ.get('PATH', '')}"
            
    if shutil.which("docker-compose"):
        return ["docker-compose"]
        
    if shutil.which("docker"):
        try:
            res = subprocess.run(["docker", "compose", "version"], capture_output=True, text=True)
            if res.returncode == 0:
                return ["docker", "compose"]
        except Exception:
            pass
            
    return ["docker-compose"]

class ManagerHandler(http.server.SimpleHTTPRequestHandler):
    def log_message(self, format, *args):
        # Silence default request logging for cleaner output
        pass

    def do_GET(self):
        if self.path == '/' or self.path == '/index.html':
            self.send_response(200)
            self.send_header('Content-type', 'text/html; charset=utf-8')
            self.end_headers()
            ui_path = os.path.join(BUNDLE_DIR, 'manager_ui.html')
            with open(ui_path, 'r', encoding='utf-8') as f:
                self.wfile.write(f.read().encode('utf-8'))
        elif self.path == '/api/status':
            self.send_json(self.get_status())
        elif self.path == '/api/config':
            self.send_json(self.get_config())
        elif self.path == '/api/logs':
            self.send_json(self.get_logs())
        else:
            # Fall back to standard file serving
            super().do_GET()

    def do_POST(self):
        content_length = int(self.headers['Content-Length'])
        post_data = self.rfile.read(content_length).decode('utf-8')
        
        if self.path == '/api/save':
            data = json.loads(post_data)
            self.save_config(data)
            self.send_json({"status": "success", "message": "Configuration saved!"})
        elif self.path == '/api/start':
            cmd = get_compose_cmd() + ["up", "-d", "--build"]
            threading.Thread(target=self.run_command, args=(cmd,)).start()
            self.send_json({"status": "success", "message": "Starting containers..."})
        elif self.path == '/api/stop':
            cmd = get_compose_cmd() + ["down"]
            threading.Thread(target=self.run_command, args=(cmd,)).start()
            self.send_json({"status": "success", "message": "Stopping containers..."})
        elif self.path == '/api/shutdown':
            self.send_response(200)
            self.send_header('Content-type', 'application/json')
            self.send_header('Connection', 'close')
            self.end_headers()
            self.wfile.write(json.dumps({"status": "success", "message": "Manager shutting down..."}).encode('utf-8'))
            self.wfile.flush()
            
            def shutdown_server():
                import time
                time.sleep(0.5)
                os._exit(0)
            threading.Thread(target=shutdown_server).start()
        else:
            self.send_error(404, "Not Found")

    def send_json(self, data):
        self.send_response(200)
        self.send_header('Content-type', 'application/json')
        self.end_headers()
        self.wfile.write(json.dumps(data).encode('utf-8'))

    def get_config(self):
        config = {}
        env_path = os.path.join(PROJECT_DIR, '.env')
        # If .env doesn't exist, try loading from .env.example
        source_path = env_path if os.path.exists(env_path) else os.path.join(PROJECT_DIR, '.env.example')
        
        if os.path.exists(source_path):
            with open(source_path, 'r') as f:
                for line in f:
                    line = line.strip()
                    if line and not line.startswith('#') and '=' in line:
                        k, v = line.split('=', 1)
                        config[k.strip()] = v.strip()
        return config

    def save_config(self, data):
        env_path = os.path.join(PROJECT_DIR, '.env')
        domain = data.get('WP_DOMAIN', 'localhost')
        port = data.get('WP_PORT', '8080')
        if port == '80':
            wp_url = f"http://{domain}"
        elif port == '443':
            wp_url = f"https://{domain}"
        else:
            wp_url = f"http://{domain}:{port}"
            
        lines = [
            "# Database Settings",
            f"DB_NAME={data.get('DB_NAME', 'wordpress')}",
            f"DB_USER={data.get('DB_USER', 'wpuser')}",
            f"DB_PASSWORD={data.get('DB_PASSWORD', 'wppassword')}",
            f"DB_ROOT_PASSWORD={data.get('DB_ROOT_PASSWORD', 'rootpassword')}",
            f"DB_HOST={data.get('DB_HOST', 'db')}",
            "",
            "# WordPress Site Settings",
            f"WP_DOMAIN={domain}",
            f"WP_PORT={port}",
            f"WP_URL={wp_url}",
            f"WP_TITLE={data.get('WP_TITLE', 'WordPress Multisite Network')}",
            f"WP_ADMIN_USER={data.get('WP_ADMIN_USER', 'admin')}",
            f"WP_ADMIN_PASSWORD={data.get('WP_ADMIN_PASSWORD', 'adminpassword')}",
            f"WP_ADMIN_EMAIL={data.get('WP_ADMIN_EMAIL', 'admin@example.com')}"
        ]
        with open(env_path, 'w') as f:
            f.write('\n'.join(lines) + '\n')

    def get_status(self):
        try:
            cmd = get_compose_cmd() + ["ps", "--format", "json"]
            result = subprocess.run(
                cmd,
                cwd=PROJECT_DIR,
                capture_output=True,
                text=True
            )
            if result.returncode == 0:
                output = result.stdout.strip()
                if not output:
                    return {"running": False, "containers": []}
                try:
                    if output.startswith('['):
                        containers = json.loads(output)
                    else:
                        containers = [json.loads(line) for line in output.split('\n') if line]
                    running = any(c.get('State') == 'running' for c in containers)
                    return {"running": running, "containers": containers}
                except Exception:
                    running = "running" in output or "Up" in output
                    return {"running": running, "containers": [], "raw": output}
            else:
                return {"running": False, "error": result.stderr}
        except Exception as e:
            return {"running": False, "error": str(e)}

    def get_logs(self):
        try:
            cmd = get_compose_cmd() + ["logs", "--tail=50"]
            result = subprocess.run(
                cmd,
                cwd=PROJECT_DIR,
                capture_output=True,
                text=True
            )
            return {"logs": result.stdout + result.stderr}
        except Exception as e:
            return {"logs": f"Error loading logs: {str(e)}"}

    def run_command(self, cmd):
        try:
            subprocess.run(cmd, cwd=PROJECT_DIR, capture_output=True, text=True)
        except Exception:
            pass

if __name__ == '__main__':
    # Bind to localhost for security
    handler = ManagerHandler
    
    # Try binding to PORT (8000), and auto-fallback to higher ports if in use
    port = PORT
    max_attempts = 20
    httpd = None
    
    for attempt in range(max_attempts):
        try:
            socketserver.TCPServer.allow_reuse_address = True
            httpd = socketserver.TCPServer(("127.0.0.1", port), handler)
            break
        except OSError as e:
            if e.errno in (98, 48):  # 98 on Linux, 48 on macOS (Address already in use)
                port += 1
            else:
                raise e
                
    if not httpd:
        print("Error: Could not find an open port to bind the server.")
        sys.exit(1)
        
    port_file = os.path.join(PROJECT_DIR, '.manager_port')
    with open(port_file, 'w', encoding='utf-8') as f:
        f.write(str(port))
        
    print(f"Manager server started at http://localhost:{port}")
    try:
        httpd.serve_forever()
    finally:
        if os.path.exists(port_file):
            try:
                os.remove(port_file)
            except Exception:
                pass

