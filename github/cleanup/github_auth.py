#!/usr/bin/env python3
"""
GitHub OAuth Authentication Module
Provides convenient browser-based authentication for GitHub API access.
"""

import secrets
import webbrowser
import urllib.parse
from flask import Flask, request, redirect
import threading
import time
import requests
from github import Github
import os


class GitHubOAuth:
    """
    GitHub OAuth authentication handler with browser-based login.
    """
    
    def __init__(self, client_id=None, client_secret=None, scopes=None):
        """
        Initialize OAuth handler.
        
        Args:
            client_id: GitHub OAuth App Client ID
            client_secret: GitHub OAuth App Client Secret  
            scopes: List of required GitHub scopes
        """
        self.client_id = client_id or self._get_env_var('GITHUB_CLIENT_ID')
        self.client_secret = client_secret or self._get_env_var('GITHUB_CLIENT_SECRET')
        self.scopes = scopes or ['repo', 'workflow', 'delete_repo']
        self.redirect_uri = 'http://localhost:8080/callback'
        self.state = None
        self.access_token = None
        self.app = Flask(__name__)
        self.app.logger.disabled = True
        self.server_thread = None
        
    def _get_env_var(self, var_name):
        """Get environment variable with helpful error message."""
        value = os.getenv(var_name)
        if not value:
            print(f"⚠️  Umgebungsvariable {var_name} nicht gesetzt.")
            print(f"   Setzen Sie diese oder verwenden Sie authenticate_with_device_flow()")
        return value
        
    def authenticate_browser(self):
        """
        Authenticate using browser-based OAuth flow.
        
        Returns:
            Github: Authenticated PyGithub instance
        """
        if not self.client_id or not self.client_secret:
            print("❌ Client ID oder Client Secret fehlt. Verwende Device Flow...")
            return self.authenticate_with_device_flow()
            
        print("🔐 Starte Browser-basierte GitHub-Authentifizierung...")
        
        # Generate state for security
        self.state = secrets.token_urlsafe(32)
        
        # Setup Flask routes
        self.app.add_url_rule('/callback', 'callback', self._handle_callback)
        
        # Start local server in background
        self._start_server()
        
        # Build authorization URL
        auth_url = self._build_auth_url()
        
        print(f"🌐 Öffne Browser für GitHub-Login...")
        print(f"📋 Falls der Browser sich nicht öffnet, besuchen Sie: {auth_url}")
        
        # Open browser
        webbrowser.open(auth_url)
        
        # Wait for callback
        print("⏳ Warte auf Autorisierung...")
        timeout = 300  # 5 minutes
        start_time = time.time()
        
        while not self.access_token and (time.time() - start_time) < timeout:
            time.sleep(1)
            
        self._stop_server()
        
        if not self.access_token:
            raise Exception("❌ Authentifizierung fehlgeschlagen oder Timeout erreicht")
            
        print("✅ Authentifizierung erfolgreich!")
        return Github(self.access_token)
        
    def authenticate_with_device_flow(self):
        """
        Authenticate using GitHub Device Flow (no OAuth app required).
        
        Returns:
            Github: Authenticated PyGithub instance
        """
        print("🔐 Starte GitHub Device Flow Authentifizierung...")
        
        # Step 1: Request device code
        device_response = requests.post(
            'https://github.com/login/device/code',
            headers={'Accept': 'application/json'},
            data={
                'client_id': 'Iv1.b507a08c87ecfe98',  # GitHub CLI client ID (public)
                'scope': ' '.join(self.scopes)
            }
        )
        
        if device_response.status_code != 200:
            raise Exception(f"❌ Device Code Anfrage fehlgeschlagen: {device_response.text}")
            
        device_data = device_response.json()
        
        print(f"\n📱 Bitte besuchen Sie: {device_data['verification_uri']}")
        print(f"🔢 Und geben Sie diesen Code ein: {device_data['user_code']}")
        print("📋 Der Code wurde in die Zwischenablage kopiert.")
        
        # Copy to clipboard if possible
        try:
            import pyperclip
            pyperclip.copy(device_data['user_code'])
        except ImportError:
            pass
            
        # Auto-open browser
        webbrowser.open(device_data['verification_uri'])
        
        # Step 2: Poll for authorization
        print("⏳ Warte auf Autorisierung...")
        interval = device_data['interval']
        expires_in = device_data['expires_in']
        start_time = time.time()
        
        while time.time() - start_time < expires_in:
            time.sleep(interval)
            
            token_response = requests.post(
                'https://github.com/login/oauth/access_token',
                headers={'Accept': 'application/json'},
                data={
                    'client_id': 'Iv1.b507a08c87ecfe98',
                    'device_code': device_data['device_code'],
                    'grant_type': 'urn:ietf:params:oauth:grant-type:device_code'
                }
            )
            
            token_data = token_response.json()
            
            if 'access_token' in token_data:
                self.access_token = token_data['access_token']
                print("✅ Authentifizierung erfolgreich!")
                return Github(self.access_token)
            elif token_data.get('error') == 'authorization_pending':
                continue
            elif token_data.get('error') == 'slow_down':
                interval += 5
                continue
            else:
                raise Exception(f"❌ Authentifizierung fehlgeschlagen: {token_data}")
                
        raise Exception("❌ Authentifizierung timeout erreicht")
        
    def _build_auth_url(self):
        """Build GitHub authorization URL."""
        params = {
            'client_id': self.client_id,
            'redirect_uri': self.redirect_uri,
            'scope': ' '.join(self.scopes),
            'state': self.state,
            'allow_signup': 'true'
        }
        return f"https://github.com/login/oauth/authorize?{urllib.parse.urlencode(params)}"
        
    def _handle_callback(self):
        """Handle OAuth callback."""
        code = request.args.get('code')
        state = request.args.get('state')
        error = request.args.get('error')
        
        if error:
            return f"❌ Authentifizierung fehlgeschlagen: {error}", 400
            
        if state != self.state:
            return "❌ Ungültiger State Parameter", 400
            
        if not code:
            return "❌ Kein Authorization Code erhalten", 400
            
        # Exchange code for access token
        token_response = requests.post(
            'https://github.com/login/oauth/access_token',
            headers={'Accept': 'application/json'},
            data={
                'client_id': self.client_id,
                'client_secret': self.client_secret,
                'code': code,
                'redirect_uri': self.redirect_uri
            }
        )
        
        token_data = token_response.json()
        
        if 'access_token' in token_data:
            self.access_token = token_data['access_token']
            return """
            <html>
            <body>
                <h2>✅ Authentifizierung erfolgreich!</h2>
                <p>Sie können dieses Fenster jetzt schließen und zur Anwendung zurückkehren.</p>
                <script>window.close();</script>
            </body>
            </html>
            """
        else:
            return f"❌ Token-Austausch fehlgeschlagen: {token_data}", 400
            
    def _start_server(self):
        """Start Flask server in background thread."""
        def run_server():
            self.app.run(host='localhost', port=8080, debug=False, use_reloader=False)
            
        self.server_thread = threading.Thread(target=run_server, daemon=True)
        self.server_thread.start()
        time.sleep(1)  # Give server time to start
        
    def _stop_server(self):
        """Stop Flask server."""
        # Flask development server doesn't have a clean shutdown method
        # In production, you'd use a proper WSGI server with shutdown capability
        pass


def get_authenticated_github(use_device_flow=True):
    """
    Convenience function to get authenticated GitHub instance.
    
    Args:
        use_device_flow: If True, prefer device flow over OAuth app
        
    Returns:
        tuple: (Github instance, access_token)
    """
    oauth = GitHubOAuth()
    
    if use_device_flow:
        github = oauth.authenticate_with_device_flow()
        return github, oauth.access_token
    else:
        github = oauth.authenticate_browser()
        return github, oauth.access_token


if __name__ == '__main__':
    """Test authentication"""
    print("🧪 Teste GitHub-Authentifizierung...")
    
    try:
        github = get_authenticated_github()
        user = github.get_user()
        print(f"✅ Angemeldet als: {user.login} ({user.name})")
        
        # Show available repositories
        repos = list(github.get_user().get_repos())[:5]
        print(f"📚 Erste 5 Repositories:")
        for repo in repos:
            print(f"  - {repo.full_name}")
            
    except Exception as e:
        print(f"❌ Fehler: {e}")
