#!/usr/bin/env python3
"""
GitHub Repository Cleanup Tool

This tool cleans up a GitHub repository by removing:
- All workflow runs
- All releases
- All tags
- All branches except main and master

Usage:
    python github_cleanup.py --owner <owner> --repo <repo> [--token <token>] [--dry-run]

Requirements:
    - Python 3.6+
    - requests library
    - GitHub Personal Access Token with appropriate permissions

Author: BAUER GROUP Automation Templates
License: MIT
"""

import argparse
import json
import os
import sys
import time
from typing import List, Dict, Optional
import requests
from datetime import datetime

try:
    from github_auth import get_authenticated_github
    from github import Github
except ImportError:
    print("❌ Erforderliche Module nicht gefunden.")
    print("💡 Installieren Sie die Pakete: pip install -r requirements.txt")
    sys.exit(1)


class GitHubCleanup:
    """GitHub Repository Cleanup Tool"""
    
    def __init__(self, owner: str, repo: str, token: str, dry_run: bool = False):
        self.owner = owner
        self.repo = repo
        self.token = token
        self.dry_run = dry_run
        self.base_url = "https://api.github.com"
        self.log_messages = []  # Store log messages for later analysis
        self.headers = {
            "Authorization": f"token {token}",
            "Accept": "application/vnd.github.v3+json",
            "User-Agent": "GitHub-Cleanup-Tool/1.0"
        }
        self.session = requests.Session()
        self.session.headers.update(self.headers)
        
    def log(self, message: str, level: str = "INFO"):
        """Log a message with timestamp"""
        timestamp = datetime.now().strftime("%Y-%m-%d %H:%M:%S")
        prefix = "🔍 [DRY-RUN]" if self.dry_run else "🔧"
        log_message = f"{prefix} [{timestamp}] {level}: {message}"
        self.log_messages.append(log_message)  # Store for later analysis
        print(log_message)
    
    def make_request(self, method: str, url: str, silent_404: bool = False, **kwargs) -> Optional[requests.Response]:
        """Make a GitHub API request with error handling"""
        try:
            response = self.session.request(method, url, **kwargs)
            
            # Handle rate limiting
            if response.status_code == 403 and "rate limit" in response.text.lower():
                reset_time = int(response.headers.get('X-RateLimit-Reset', 0))
                wait_time = max(reset_time - int(time.time()), 60)
                self.log(f"Rate limit reached. Waiting {wait_time} seconds...", "WARNING")
                time.sleep(wait_time)
                return self.make_request(method, url, silent_404=silent_404, **kwargs)
            
            # Handle permission errors
            if response.status_code == 403 and "not accessible by integration" in response.text.lower():
                self.log(f"⚠️  Permission denied - Token needs additional scopes for this operation", "WARNING")
                return response
            
            if response.status_code >= 400:
                if response.status_code == 404 and silent_404:
                    return response  # Return 404 without logging error
                self.log(f"API Error: {response.status_code} - {response.text}", "ERROR")
                return response if response.status_code == 404 else None
                
            return response
        except Exception as e:
            self.log(f"Request failed: {str(e)}", "ERROR")
            return None
    
    def get_paginated_results(self, url: str, per_page: int = 100, data_key: str = None) -> List[Dict]:
        """Get all results from a paginated GitHub API endpoint"""
        results = []
        page = 1
        
        while True:
            paginated_url = f"{url}?page={page}&per_page={per_page}"
            response = self.make_request("GET", paginated_url)
            
            if not response:
                break
                
            json_data = response.json()
            if not json_data:
                break
            
            # Extract data from the correct key if specified
            if data_key and data_key in json_data:
                data = json_data[data_key]
            elif isinstance(json_data, list):
                data = json_data
            else:
                # Try common keys
                data = json_data.get('workflow_runs') or json_data.get('items') or []
                
            if not data:
                break
                
            results.extend(data)
            page += 1
            
            # Break if we got less than per_page results (last page)
            if len(data) < per_page:
                break
                
        return results
    
    def cleanup_workflow_runs(self):
        """Delete all workflow runs"""
        self.log("🏃 Starting workflow runs cleanup...")
        
        url = f"{self.base_url}/repos/{self.owner}/{self.repo}/actions/runs"
        workflow_runs = self.get_paginated_results(url, data_key='workflow_runs')
        
        self.log(f"Found {len(workflow_runs)} workflow runs")
        
        for run in workflow_runs:
            run_id = run['id']
            run_name = run.get('name', 'Unknown')
            run_status = run.get('status', 'Unknown')
            
            if self.dry_run:
                self.log(f"Would delete workflow run: {run_name} (ID: {run_id}, Status: {run_status})")
            else:
                delete_url = f"{self.base_url}/repos/{self.owner}/{self.repo}/actions/runs/{run_id}"
                response = self.make_request("DELETE", delete_url)
                
                if response and response.status_code == 204:
                    self.log(f"✅ Deleted workflow run: {run_name} (ID: {run_id})")
                elif response and response.status_code == 403:
                    self.log(f"⚠️  Workflow run deletion requires admin permissions: {run_name} (ID: {run_id})", "WARNING")
                    self.log("💡 Lösung: Verwenden Sie einen Personal Access Token mit 'workflow' scope", "INFO")
                else:
                    self.log(f"❌ Failed to delete workflow run: {run_name} (ID: {run_id})", "ERROR")
                
                # Small delay to avoid rate limiting
                time.sleep(0.1)
    
    def cleanup_releases(self):
        """Delete all releases"""
        self.log("🎯 Starting releases cleanup...")
        
        url = f"{self.base_url}/repos/{self.owner}/{self.repo}/releases"
        releases = self.get_paginated_results(url)
        
        self.log(f"Found {len(releases)} releases")
        
        for release in releases:
            release_id = release['id']
            release_name = release.get('name', release.get('tag_name', 'Unknown'))
            tag_name = release.get('tag_name', 'Unknown')
            
            if self.dry_run:
                self.log(f"Would delete release: {release_name} (Tag: {tag_name}, ID: {release_id})")
            else:
                delete_url = f"{self.base_url}/repos/{self.owner}/{self.repo}/releases/{release_id}"
                response = self.make_request("DELETE", delete_url)
                
                if response and response.status_code == 204:
                    self.log(f"✅ Deleted release: {release_name} (Tag: {tag_name})")
                else:
                    self.log(f"❌ Failed to delete release: {release_name} (Tag: {tag_name})", "ERROR")
                
                time.sleep(0.1)
    
    def cleanup_tags(self):
        """Delete all tags"""
        self.log("🏷️ Starting tags cleanup...")
        
        url = f"{self.base_url}/repos/{self.owner}/{self.repo}/git/refs/tags"
        response = self.make_request("GET", url, silent_404=True)
        
        if not response:
            self.log("No tags found or error retrieving tags")
            return
        
        if response.status_code == 404:
            self.log("No tags found in repository")
            return
        elif response.status_code != 200:
            self.log(f"Error retrieving tags: {response.status_code}")
            return
            
        tags = response.json()
        self.log(f"Found {len(tags)} tags")
        
        for tag in tags:
            tag_ref = tag['ref']  # e.g., "refs/tags/v1.0.0"
            tag_name = tag_ref.replace('refs/tags/', '')
            
            if self.dry_run:
                self.log(f"Would delete tag: {tag_name}")
            else:
                delete_url = f"{self.base_url}/repos/{self.owner}/{self.repo}/git/{tag_ref}"
                response = self.make_request("DELETE", delete_url)
                
                if response and response.status_code == 204:
                    self.log(f"✅ Deleted tag: {tag_name}")
                else:
                    self.log(f"❌ Failed to delete tag: {tag_name}", "ERROR")
                
                time.sleep(0.1)
    
    def cleanup_branches(self):
        """Delete all branches except main and master"""
        self.log("🌿 Starting branches cleanup...")
        
        protected_branches = {'main', 'master'}
        
        url = f"{self.base_url}/repos/{self.owner}/{self.repo}/branches"
        branches = self.get_paginated_results(url)
        
        # Filter out protected branches
        branches_to_delete = [b for b in branches if b['name'] not in protected_branches]
        
        self.log(f"Found {len(branches)} total branches, {len(branches_to_delete)} to delete")
        
        for branch in branches_to_delete:
            branch_name = branch['name']
            
            if self.dry_run:
                self.log(f"Would delete branch: {branch_name}")
            else:
                delete_url = f"{self.base_url}/repos/{self.owner}/{self.repo}/git/refs/heads/{branch_name}"
                response = self.make_request("DELETE", delete_url)
                
                if response and response.status_code == 204:
                    self.log(f"✅ Deleted branch: {branch_name}")
                elif response and response.status_code == 403:
                    self.log(f"⚠️  Branch deletion requires admin permissions: {branch_name}", "WARNING")
                    self.log("💡 Lösung: Verwenden Sie einen Personal Access Token mit 'repo' scope", "INFO")
                else:
                    self.log(f"❌ Failed to delete branch: {branch_name}", "ERROR")
                
                time.sleep(0.1)
    
    def cleanup_pull_requests(self):
        """Clean up open pull requests by closing them"""
        self.log("🔀 Starting pull requests cleanup...")
        
        # Get only open pull requests
        url = f"{self.base_url}/repos/{self.owner}/{self.repo}/pulls"
        open_prs = self.get_paginated_results(f"{url}?state=open")
        
        if not open_prs:
            self.log("No open pull requests found")
            return
        
        self.log(f"Found {len(open_prs)} open pull requests")
        
        for pr in open_prs:
            pr_number = pr['number']
            pr_title = pr['title']
            
            if self.dry_run:
                self.log(f"Would close PR #{pr_number}: {pr_title}")
            else:
                # Close the open PR
                close_url = f"{self.base_url}/repos/{self.owner}/{self.repo}/pulls/{pr_number}"
                close_response = self.make_request("PATCH", close_url, 
                                                 json={"state": "closed"})
                
                if close_response and close_response.status_code == 200:
                    self.log(f"✅ Closed PR #{pr_number}: {pr_title}")
                else:
                    self.log(f"❌ Failed to close PR #{pr_number}: {pr_title}", "ERROR")
                
                time.sleep(0.1)
    
    def get_repository_info(self):
        """Get basic repository information"""
        url = f"{self.base_url}/repos/{self.owner}/{self.repo}"
        response = self.make_request("GET", url)
        
        if response and response.status_code == 200:
            repo_data = response.json()
            self.log(f"Repository: {repo_data['full_name']}")
            self.log(f"Description: {repo_data.get('description', 'No description')}")
            self.log(f"Default branch: {repo_data.get('default_branch', 'Unknown')}")
            return repo_data
        else:
            self.log("Failed to get repository information", "ERROR")
            return None
    
    def run_cleanup(self):
        """Run the complete cleanup process"""
        self.log("🚀 Starting GitHub repository cleanup...")
        self.log(f"Repository: {self.owner}/{self.repo}")
        self.log(f"Dry run mode: {'Enabled' if self.dry_run else 'Disabled'}")
        
        # Verify repository access
        repo_info = self.get_repository_info()
        if not repo_info:
            self.log("Cannot access repository. Check owner/repo names and token permissions.", "ERROR")
            return False
        
        try:
            # Run cleanup operations
            self.cleanup_workflow_runs()
            self.cleanup_pull_requests()
            self.cleanup_releases()
            self.cleanup_tags()
            self.cleanup_branches()
            
            self.log("✨ Cleanup completed successfully!")
            
            # Check if there were permission issues
            if any("Permission denied" in line for line in self.log_messages if hasattr(self, 'log_messages')):
                print("\n🔧 TROUBLESHOOTING - Permission-Probleme erkannt:")
                print("━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━")
                print("💡 Für vollständige Repository-Bereinigung benötigen Sie einen Personal Access Token")
                print("🔗 Erstellen Sie einen Token: https://github.com/settings/tokens")
                print("✅ Erforderliche Scopes:")
                print("   • repo (Full control of private repositories)")
                print("   • workflow (Update GitHub Action workflows)")  
                print("   • admin:repo_hook (Admin access to repository hooks)")
                print("\n🚀 Verwendung mit Token:")
                print(f"   python github_cleanup.py --owner {self.owner} --repo {self.repo} --token YOUR_TOKEN")
                print("   oder")
                print("   export GITHUB_TOKEN=YOUR_TOKEN")
                print(f"   python github_cleanup.py --owner {self.owner} --repo {self.repo}")
            
            return True
            
        except KeyboardInterrupt:
            self.log("Cleanup interrupted by user", "WARNING")
            return False
        except Exception as e:
            self.log(f"Cleanup failed with error: {str(e)}", "ERROR")
            return False


def main():
    """Main function"""
    parser = argparse.ArgumentParser(
        description="Clean up a GitHub repository by removing workflow runs, releases, tags, and branches",
        formatter_class=argparse.RawDescriptionHelpFormatter,
        epilog="""
Examples:
  python github_cleanup.py --owner myorg --repo myrepo --token ghp_xxxx
  python github_cleanup.py --owner myorg --repo myrepo --dry-run
  python github_cleanup.py --owner myorg --repo myrepo (uses GITHUB_TOKEN env var or device flow)
        """
    )
    
    parser.add_argument("--owner", required=True, help="GitHub repository owner/organization")
    parser.add_argument("--repo", required=True, help="GitHub repository name")
    parser.add_argument("--token", help="GitHub Personal Access Token (or use GITHUB_TOKEN env var)")
    parser.add_argument("--dry-run", action="store_true", help="Show what would be deleted without actually deleting")
    parser.add_argument("--verbose", "-v", action="store_true", help="Enable verbose output")
    
    args = parser.parse_args()
    
    # Handle authentication
    token = None
    
    # Get token from argument or environment variable
    token = args.token or os.getenv("GITHUB_TOKEN")
    if not token:
        # Offer choice between device flow and manual token
        print("\n🔐 GitHub Authentifizierung erforderlich")
        print("1️⃣  Device Flow (Browser-Login) - Begrenzte Berechtigungen")
        print("2️⃣  Personal Access Token - Volle Berechtigungen")
        print("\n💡 Für vollständige Repository-Bereinigung wird Option 2 empfohlen!")
        
        while True:
            choice = input("\nWählen Sie eine Option (1 oder 2): ").strip()
            if choice == "1":
                print("🔐 Starte GitHub Device Flow Authentifizierung...")
                print("⚠️  Hinweis: Device Flow hat begrenzte Berechtigungen - möglicherweise können nicht alle Items gelöscht werden")
                try:
                    github_client, token = get_authenticated_github()
                    user = github_client.get_user()
                    print(f"✅ Erfolgreich angemeldet als: {user.login} ({user.name})")
                    break
                except Exception as e:
                    print(f"❌ Device Flow fehlgeschlagen: {e}")
                    print("💡 Versuchen Sie Option 2 (Personal Access Token)")
                    continue
            elif choice == "2":
                print("\n📋 So erstellen Sie einen Personal Access Token:")
                print("1. Gehen Sie zu: https://github.com/settings/tokens")
                print("2. Klicken Sie auf 'Generate new token (classic)'")
                print("3. Wählen Sie diese Scopes:")
                print("   ✅ repo (Full control of private repositories)")
                print("   ✅ workflow (Update GitHub Action workflows)")
                print("   ✅ admin:repo_hook (Admin access to repository hooks)")
                print("4. Kopieren Sie den Token und fügen Sie ihn hier ein")
                
                token = input("\n🔑 Geben Sie Ihren Personal Access Token ein: ").strip()
                if token:
                    break
                else:
                    print("❌ Kein Token eingegeben!")
                    continue
            else:
                print("❌ Ungültige Auswahl! Bitte wählen Sie 1 oder 2.")
                continue
    
    # Confirm destructive operation
    if not args.dry_run:
        print(f"⚠️  WARNING: This will permanently delete ALL workflow runs, releases, tags, and branches (except main/master) from {args.owner}/{args.repo}")
        confirmation = input("Are you absolutely sure? Type 'yes' to continue: ")
        if confirmation.lower() != 'yes':
            print("Operation cancelled.")
            sys.exit(0)
    
    # Run cleanup
    cleanup = GitHubCleanup(args.owner, args.repo, token, args.dry_run)
    success = cleanup.run_cleanup()
    
    sys.exit(0 if success else 1)


if __name__ == "__main__":
    main()
