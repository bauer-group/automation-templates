#!/usr/bin/env python3
"""
GitHub Device Flow Authentication Module
Provides convenient browser-based device flow authentication for GitHub API access.
"""

import secrets
import webbrowser
import urllib.parse
import time
import requests
from github import Github
import os


def get_authenticated_github():
    """
    Get authenticated GitHub instance using Device Flow.
    
    Returns:
        tuple: (Github instance, access_token)
    """
    print("🔐 Starte GitHub Device Flow Authentifizierung...")
    
    # Step 1: Request device code
    device_response = requests.post(
        'https://github.com/login/device/code',
        headers={'Accept': 'application/json'},
        data={
            'client_id': 'Iv1.b507a08c87ecfe98',  # GitHub CLI client ID (public)
            'scope': 'repo workflow admin:repo_hook actions'
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
            access_token = token_data['access_token']
            print("✅ Authentifizierung erfolgreich!")
            return Github(access_token), access_token
        elif token_data.get('error') == 'authorization_pending':
            continue
        elif token_data.get('error') == 'slow_down':
            interval += 5
            continue
        else:
            raise Exception(f"❌ Authentifizierung fehlgeschlagen: {token_data}")
            
    raise Exception("❌ Authentifizierung timeout erreicht")


if __name__ == '__main__':
    """Test authentication"""
    print("🧪 Teste GitHub Device Flow Authentifizierung...")
    
    try:
        github, token = get_authenticated_github()
        user = github.get_user()
        print(f"✅ Angemeldet als: {user.login} ({user.name})")
        
        # Show available repositories
        repos = list(github.get_user().get_repos())[:5]
        print(f"📚 Erste 5 Repositories:")
        for repo in repos:
            print(f"  - {repo.full_name}")
            
    except Exception as e:
        print(f"❌ Fehler: {e}")
