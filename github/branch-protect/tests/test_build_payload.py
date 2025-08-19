from src.protect_main import Config, build_payload


def test_build_payload_minimal():
    cfg = Config(
        org=None,
        repos=["owner/repo"],
        branch="main",
        reviews=2,
        include_admins=True,
        linear_history=True,
        allow_force_pushes=False,
        allow_deletions=False,
        require_conversation_resolution=True,
        strict_up_to_date=True,
        status_checks=[],
        restrict_teams=[],
        restrict_users=[],
        require_signed_commits=False,
        delete_mode=False,
        dry_run=True,
        token="dummy",
    )
    payload = build_payload(cfg)
    assert payload["required_status_checks"]["strict"] is True
    assert payload["required_pull_request_reviews"]["required_approving_review_count"] == 2
    assert payload["restrictions"] is None


def test_build_payload_restrictions():
    cfg = Config(
        org=None,
        repos=["o/r"],
        branch="dev",
        reviews=1,
        include_admins=False,
        linear_history=False,
        allow_force_pushes=True,
        allow_deletions=True,
        require_conversation_resolution=False,
        strict_up_to_date=False,
        status_checks=["build"],
        restrict_teams=["team1"],
        restrict_users=["user1"],
        require_signed_commits=True,
        delete_mode=False,
        dry_run=False,
        token="dummy",
    )
    payload = build_payload(cfg)
    assert payload["required_status_checks"]["contexts"] == ["build"]
    assert payload["restrictions"]["teams"] == ["team1"]
    assert payload["restrictions"]["users"] == ["user1"]
