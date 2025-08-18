#!/usr/bin/env python3
"""
Test GitHub Device Flow Authentication
Einfaches Testskript für die Device Flow Authentifizierung
"""

import sys
import os

# Add current directory to path to import github_auth
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))

try:
    from github_auth import get_authenticated_github
    print("✅ GitHub Auth Modul erfolgreich importiert")
except ImportError as e:
    print(f"❌ Import-Fehler: {e}")
    print("💡 Installieren Sie die Abhängigkeiten: pip install -r requirements.txt")
    sys.exit(1)


def test_device_flow():
    """Test GitHub Device Flow authentication"""
    print("\n🧪 Teste GitHub Device Flow Authentifizierung...")
    print("=" * 50)
    
    try:
        # Authentifizierung
        github, token = get_authenticated_github()
        
        # Benutzerinformationen abrufen
        user = github.get_user()
        print(f"✅ Erfolgreich angemeldet als: {user.login}")
        print(f"📧 E-Mail: {user.email or 'Nicht öffentlich'}")
        print(f"👤 Name: {user.name or 'Nicht gesetzt'}")
        print(f"🏢 Unternehmen: {user.company or 'Nicht gesetzt'}")
        print(f"📍 Standort: {user.location or 'Nicht gesetzt'}")
        
        # Repository-Informationen anzeigen
        print(f"\n📚 Ihre Repositories:")
        repos = list(github.get_user().get_repos(sort='updated'))[:10]
        
        for i, repo in enumerate(repos, 1):
            privacy = "🔒 Privat" if repo.private else "🌐 Öffentlich"
            print(f"  {i:2d}. {repo.full_name} ({privacy})")
            
        print(f"\n📊 Statistiken:")
        print(f"  - Öffentliche Repositories: {user.public_repos}")
        print(f"  - Follower: {user.followers}")
        print(f"  - Following: {user.following}")
        
        # Rate Limit anzeigen
        try:
            rate_limit = github.get_rate_limit()
            core_limit = rate_limit.core
            print(f"\n⏱️  Rate Limit:")
            print(f"  - Verbleibend: {core_limit.remaining}/{core_limit.limit}")
            reset_time = core_limit.reset.strftime("%H:%M:%S")
            print(f"  - Reset um: {reset_time}")
        except Exception as e:
            print(f"\n⏱️  Rate Limit: Nicht verfügbar ({e})")
        
        return True
        
    except Exception as e:
        print(f"❌ Authentifizierung fehlgeschlagen: {e}")
        return False


def main():
    """Main test function"""
    print("� GitHub Device Flow Authentication Test")
    print("=" * 50)
    
    # Test Device Flow
    device_flow_success = test_device_flow()
    
    print("\n" + "=" * 50)
    print("📋 Test-Zusammenfassung:")
    print(f"  Device Flow: {'✅ Erfolgreich' if device_flow_success else '❌ Fehlgeschlagen'}")
    
    if device_flow_success:
        print("\n🎉 Device Flow Authentifizierung funktioniert!")
        print("💡 Sie können jetzt das Cleanup-Tool mit --device-auth verwenden:")
        print("   python github_cleanup.py --owner OWNER --repo REPO --device-auth --dry-run")
    else:
        print("\n❌ Device Flow Authentifizierung fehlgeschlagen")
        print("💡 Überprüfen Sie Ihre Internetverbindung und Firewall-Einstellungen")


if __name__ == '__main__':
    main()
