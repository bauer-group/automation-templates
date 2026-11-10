"""Tests for resolve_base_images.

base-images.json held a fixed 'tag' per image, and Dependabot bumps the FROM
line, never the config. On 2026-11-10 eight repositories were monitored on
python:3.14-alpine while their images were built on python:3.15-alpine. The
resolver takes the tag from the Dockerfile instead; these tests pin what it
reads from a FROM line, which line it picks, and that it fails loudly rather
than monitoring a guessed tag - for that entry only, so the monitor still
checks every other image. The Dockerfile fixtures are shaped after real ones
of the affected repositories.

Run:  python3 .github/actions/docker-base-image-resolve/tests/test_resolve_base_images.py
      (no pytest required; pytest discovers the tests as well)
"""
from __future__ import annotations

import contextlib
import io
import json
import os
import shutil
import subprocess
import sys
import tempfile
import unittest

ACTION_DIR = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
SCRIPT = os.path.join(ACTION_DIR, "resolve_base_images.py")
sys.path.insert(0, ACTION_DIR)

import resolve_base_images as rbi  # noqa: E402

DIGEST = "sha256:" + "a" * 64

# CS-BackupHelper: a global ARG before the first FROM, three stages of one image.
BACKUPHELPER = """\
# syntax=docker/dockerfile:1
ARG PG_CLIENT_VERSION=18

FROM python:3.15-alpine AS builder
RUN pip install build

FROM python:3.15-alpine AS test
ARG PG_CLIENT_VERSION

FROM python:3.15-alpine AS prod
ARG PG_CLIENT_VERSION
ARG IMAGE_VERSION=0.1.0
"""

# CS-IAM src/login: image and tag both come from ARG defaults; the ARGs are
# declared again after the FROM, inside the stage.
IAM_LOGIN = """\
ARG LOGIN_BASE_IMAGE=ghcr.io/bauer-group/ep-zitadel/zitadel-login
ARG LOGIN_BASE_VERSION=latest

FROM ${LOGIN_BASE_IMAGE}:${LOGIN_BASE_VERSION}

ARG LOGIN_BASE_IMAGE
ARG LOGIN_BASE_VERSION
"""

# CS-NocoDB src/nocodb-backup: a registry image with an ARG tag, two stages.
NOCODB_BACKUP = """\
ARG BACKUPHELPER_VERSION=latest

FROM ghcr.io/bauer-group/cs-backuphelper/backuphelper:${BACKUPHELPER_VERSION} AS test
RUN pytest

FROM ghcr.io/bauer-group/cs-backuphelper/backuphelper:${BACKUPHELPER_VERSION} AS prod
"""

# CS-IAM src/database-backup: later FROM lines name the first stage.
IAM_DATABASE_BACKUP = """\
FROM ghcr.io/bauer-group/cs-backuphelper/backuphelper:latest AS engine
FROM engine AS test
FROM engine
"""


# COM-WhistleblowerApp src/Dockerfile: Python in a RUN heredoc of the asset
# stage; its "from PIL import Image" is no FROM line.
WHISTLEBLOWER = """\
FROM python:3-alpine AS asset-builder
RUN mkdir -p /out && python3 - <<'PY'
from PIL import Image
# a comment to Python, part of the body

sq = Image.open('/src/logo-square.png')
PY

FROM globaleaks/globaleaks:latest
COPY --from=asset-builder /out/ /var/globaleaks/
"""


class RepoCase(unittest.TestCase):
    """A throwaway repository root holding Dockerfiles."""

    def setUp(self) -> None:
        self.root = tempfile.mkdtemp(prefix="resolve-base-images-")

    def tearDown(self) -> None:
        shutil.rmtree(self.root, ignore_errors=True)

    def write(self, path: str, text: str) -> None:
        full = os.path.join(self.root, path)
        os.makedirs(os.path.dirname(full), exist_ok=True)
        with open(full, "w", encoding="utf-8", newline="") as handle:
            handle.write(text)

    def resolve(self, text: str, **entry) -> rbi.Resolved:
        self.write("Dockerfile", text)
        base = {"name": "base", "image": "python", "dockerfile": "Dockerfile", "variable": "BASE_DIGEST"}
        base.update(entry)
        return rbi.resolve_entry(base, self.root)

    def fails(self, text: str, *fragments: str, **entry) -> rbi.ResolveError:
        with self.assertRaises(rbi.ResolveError) as caught:
            self.resolve(text, **entry)
        for fragment in fragments:
            self.assertIn(fragment, str(caught.exception))
        return caught.exception


def references(text: str):
    return [f.reference for f in rbi.parse_dockerfile(text)]


class ArgExpansion(unittest.TestCase):
    def test_global_arg_default(self):
        self.assertEqual(references("ARG V=3.15\nFROM python:${V}-alpine\n"), ["python:3.15-alpine"])

    def test_unbraced_variable(self):
        self.assertEqual(references("ARG V=3.15\nFROM python:$V\n"), ["python:3.15"])

    def test_default_forms(self):
        cases = {
            "${V:-3.15}": ("3.15", "3.15", "9"),
            "${V-3.15}": ("3.15", "", "9"),
            "x${V:+-slim}": ("x", "x", "x-slim"),
            "x${V+-slim}": ("x", "x-slim", "x-slim"),
        }
        for expression, (unset, empty, set_) in cases.items():
            for declaration, want in (("ARG V", unset), ('ARG V=""', empty), ("ARG V=9", set_)):
                with self.subTest(expression=expression, declaration=declaration):
                    got = references(f"{declaration}\nFROM python:{expression}\n")
                    self.assertEqual(got, [f"python:{want}"])

    def test_nested_default(self):
        self.assertEqual(references("ARG B=3.15\nFROM python:${A:-${B}}\n"), ["python:3.15"])

    def test_default_refers_to_an_earlier_arg(self):
        text = "ARG MAJOR=3\nARG VERSION=${MAJOR}.15\nFROM python:${VERSION}-alpine\n"
        self.assertEqual(references(text), ["python:3.15-alpine"])

    def test_quoted_defaults_and_several_args_on_one_line(self):
        text = 'ARG IMAGE="python" TAG=\'3.15-alpine\'\nFROM ${IMAGE}:${TAG}\n'
        self.assertEqual(references(text), ["python:3.15-alpine"])

    def test_args_after_the_first_from_do_not_reach_later_from_lines(self):
        text = "ARG V=1\nFROM a:${V}\nARG V=2\nFROM b:${V}\n"
        self.assertEqual(references(text), ["a:1", "b:1"])

    def test_arg_without_default_is_unset(self):
        line = rbi.parse_dockerfile("ARG V\nFROM python:${V}\n")[0]
        self.assertIsNone(line.reference)
        self.assertIn("${V} has no default value", line.error)

    def test_redeclaring_without_default_keeps_the_default(self):
        self.assertEqual(references("ARG V=3.15\nARG V\nFROM python:${V}\n"), ["python:3.15"])

    def test_default_using_an_arg_without_value_fails_where_used(self):
        line = rbi.parse_dockerfile("ARG B=${A}\nFROM python:${B}\n")[0]
        self.assertIsNone(line.reference)
        self.assertIn("the default of 'ARG B=${A}' cannot be read: ${A} has no default value", line.error)

    def test_default_using_an_arg_without_value_is_never_guessed(self):
        # BuildKit expands the unset part to "": ARG V=${U} is set and empty,
        # ARG V=3.${U} is "3.". Taken as unset, ${V-x} read "1x" where
        # BuildKit builds "1", ${V:-x} "x" where it builds "3.".
        for declaration in ("ARG V=${U}", "ARG U\nARG V=${U}", "ARG V=3.${U}", "ARG V=${U:+x}${W}"):
            for use in ("1${V-x}", "1${V+x}", "${V:-x}", "1${V:+x}", "${V}", "$V"):
                with self.subTest(declaration=declaration, use=use):
                    line = rbi.parse_dockerfile(f"{declaration}\nFROM python:{use}\n")[0]
                    self.assertIsNone(line.reference)
                    self.assertIn("the default of 'ARG V=", line.error)
        self.assertEqual(references("ARG U=2\nARG V=${U}\nFROM python:${V-x}\n"), ["python:2"])

    def test_a_default_that_cannot_be_read_is_harmless_unless_used(self):
        self.assertEqual(references("ARG V=${U}\nFROM python:3.15\n"), ["python:3.15"])
        self.assertEqual(references("ARG V=${U}\nARG V=3.15\nFROM python:${V}\n"), ["python:3.15"])

    def test_escaped_dollar_is_literal(self):
        self.assertEqual(references("FROM python:\\$V\n"), ["python:$V"])

    def test_unsupported_expansion(self):
        line = rbi.parse_dockerfile("ARG V=3.15\nFROM python:${V#3}\n")[0]
        self.assertIn("unsupported variable expansion", line.error)

    def test_unterminated_brace(self):
        line = rbi.parse_dockerfile("FROM python:${V\n")[0]
        self.assertIn("unterminated", line.error)


class FromLines(unittest.TestCase):
    def test_platform_flag_and_stage(self):
        line = rbi.parse_dockerfile("FROM --platform=$BUILDPLATFORM golang:1.26-alpine AS Build\n")[0]
        self.assertEqual((line.reference, line.stage, line.stage_ref), ("golang:1.26-alpine", "build", False))

    def test_stage_references_are_not_images(self):
        froms = rbi.parse_dockerfile(IAM_DATABASE_BACKUP)
        self.assertEqual([f.stage_ref for f in froms], [False, True, True])

    def test_stage_names_match_case_insensitively(self):
        froms = rbi.parse_dockerfile("FROM python:3.15 AS Build\nFROM BUILD\n")
        self.assertTrue(froms[1].stage_ref)

    def test_lower_case_instructions(self):
        self.assertEqual(references("arg V=3.15\nfrom python:${V}\n"), ["python:3.15"])

    def test_comments_blank_lines_and_continuations(self):
        text = (
            "# syntax=docker/dockerfile:1\n"        # 1
            "ARG BASE=python \\\n"                    # 2
            "    # a comment inside the ARG\n"        # 3
            "    VERSION=3.15\n"                      # 4
            "\n"                                      # 5
            "# FROM ruby:3 is only a comment\n"       # 6
            "FROM --platform=$BUILDPLATFORM \\\n"     # 7
            "\n"                                      # 8
            "     ${BASE}:${VERSION}-alpine \\   \n"  # 9 (blanks after the backslash)
            "     AS build\n"                         # 10
            "RUN echo \\\n"                           # 11
            "FROM ruby:3\n"                           # 12 (part of the RUN)
        )
        froms = rbi.parse_dockerfile(text)
        self.assertEqual(len(froms), 1)
        self.assertEqual((froms[0].line, froms[0].reference, froms[0].stage), (7, "python:3.15-alpine", "build"))

    def test_crlf_and_byte_order_mark(self):
        self.assertEqual(references("﻿ARG V=3.15\r\nFROM python:${V}\r\n"), ["python:3.15"])

    def test_heredoc_bodies_are_not_instructions(self):
        # COM-WhistleblowerApp and IP-Kleinanzeigen-MCPServer run Python from
        # a RUN heredoc; "from PIL import Image" was read as a FROM line.
        froms = rbi.parse_dockerfile(WHISTLEBLOWER)
        self.assertEqual([(f.line, f.reference) for f in froms],
                         [(1, "python:3-alpine"), (9, "globaleaks/globaleaks:latest")])

    def test_heredoc_forms(self):
        # Each as BuildKit reads it (docker buildx, 2026-11-10): the body's
        # FROM is not an instruction, the line after the terminator is.
        cases = {
            "unquoted": "RUN cat <<EOF\nFROM python:9\nEOF\n",
            "single-quoted": "RUN python3 - <<'PY'\nfrom PIL import Image\nFROM python:9\nPY\n",
            "double-quoted": 'RUN cat <<"EOF" > /x\nFROM python:9\nEOF\n',
            "<<- strips tabs": "RUN cat <<-EOF\n\tFROM python:9\n\tEOF\n",
            "<< keeps a tabbed terminator in the body": "RUN cat <<EOF\n\tEOF\nFROM python:9\nEOF\n",
            "COPY": "COPY <<EOF /x\nFROM python:9\nEOF\n",
            "ADD": "ADD <<EOF /x\nFROM python:9\nEOF\n",
            "two heredocs": "RUN <<A <<B\nFROM python:9\nA\nFROM python:8\nB\n",
            "file descriptor": "RUN cat 3<<EOF\nFROM python:9\nEOF\n",
            "after a continuation": "RUN --network=none \\\n    cat <<EOF\nFROM python:9\nEOF\n",
            "lower-case run, CRLF": "run cat <<EOF\r\nFROM python:9\r\nEOF\r\n",
        }
        for title, body in cases.items():
            with self.subTest(title):
                self.assertEqual(references(f"FROM python:3.15\n{body}FROM python:3.15-slim\n"),
                                 ["python:3.15", "python:3.15-slim"])

    def test_not_a_heredoc(self):
        cases = {
            "exec form": 'RUN ["sh", "-c", "cat <<EOF > /x"]\n',
            "in a quoted string": 'RUN sh -c "cat <<EOF > /x"\n',
            "a quoted word": "RUN echo '<<EOF'\n",
            "a shift": "RUN echo $((1<<20))\n",
            "not RUN, COPY or ADD": "ENTRYPOINT cat <<EOF\n",
        }
        for title, line in cases.items():
            with self.subTest(title):
                self.assertEqual(references(f"FROM python:3.15\n{line}FROM python:9\n"), ["python:3.15", "python:9"])

    def test_lines_end_at_line_feeds_only(self):
        # str.splitlines() also breaks at these; BuildKit does not, so a FROM
        # behind one is part of the RUN (checked with docker buildx).
        for separator in ("\x0c", "\x0b", "\x1c", "\x85", " ", " ", "\r"):
            with self.subTest(separator=repr(separator)):
                froms = rbi.parse_dockerfile(f"FROM python:3.15\nRUN echo a{separator}FROM python:3.14\n")
                self.assertEqual([f.reference for f in froms], ["python:3.15"])
                self.assertEqual(rbi.parse_dockerfile(f"RUN echo a{separator}b\nFROM python:3.15\n")[0].line, 2)

    def test_indices_count_every_from_line(self):
        self.assertEqual([f.index for f in rbi.parse_dockerfile(IAM_DATABASE_BACKUP)], [0, 1, 2])

    def test_unparsable_from_line(self):
        line = rbi.parse_dockerfile("FROM python:3.15 AS\n")[0]
        self.assertIn("cannot parse", line.error)


class References(unittest.TestCase):
    def test_split(self):
        cases = {
            "python": ("python", None, None),
            "python:3.15-alpine": ("python", "3.15-alpine", None),
            "localhost:5000/app": ("localhost:5000/app", None, None),
            "localhost:5000/app:1.2": ("localhost:5000/app", "1.2", None),
            f"ghcr.io/a/b:3.15@{DIGEST}": ("ghcr.io/a/b", "3.15", DIGEST),
            f"python@{DIGEST}": ("python", None, DIGEST),
        }
        for reference, want in cases.items():
            with self.subTest(reference=reference):
                self.assertEqual(rbi.split_reference(reference), want)

    def test_docker_hub_spellings_are_one_repository(self):
        spellings = ["python", "library/python", "docker.io/python", "docker.io/library/python",
                     "index.docker.io/library/python"]
        self.assertEqual({rbi.normalize_repository(s) for s in spellings}, {"docker.io/library/python"})

    def test_other_registries(self):
        self.assertEqual(rbi.normalize_repository("ghcr.io/bauer-group/cs-minio/minio"),
                         "ghcr.io/bauer-group/cs-minio/minio")
        self.assertEqual(rbi.normalize_repository("localhost:5000/app"), "localhost:5000/app")
        self.assertEqual(rbi.normalize_repository("n8nio/n8n"), "docker.io/n8nio/n8n")

    def test_invalid_repositories(self):
        for name in ("Python", "python ", "", "a//b", "ghcr.io/"):
            with self.subTest(name=name):
                self.assertIsNone(rbi.normalize_repository(name))


class ResolveEntry(RepoCase):
    def test_tag_follows_the_from_line(self):
        result = self.resolve(BACKUPHELPER)
        self.assertEqual((result.tag, result.line), ("3.15-alpine", 4))
        self.assertEqual(result.entry["tag"], "3.15-alpine")
        self.assertEqual(result.notices, [])

    def test_stale_config_tag_is_reported_and_the_dockerfile_wins(self):
        result = self.resolve(BACKUPHELPER, tag="3.14-alpine")
        self.assertEqual(result.entry["tag"], "3.15-alpine")
        self.assertEqual(len(result.notices), 1)
        message, file, line = result.notices[0]
        self.assertIn("'3.14-alpine' is stale", message)
        self.assertIn("'3.15-alpine'", message)
        self.assertEqual((file, line), ("Dockerfile", 4))
        self.assertNotIn("--build-arg", message)

    def test_stale_tag_from_an_arg_names_the_build_arg_exception(self):
        # XPD-SonarQube watches sonarqube:community on purpose: its release
        # overrides the ARG, so the default is not what is built.
        result = self.resolve("ARG SONARQUBE_VERSION=26.8.0.126808-community\nFROM sonarqube:${SONARQUBE_VERSION}\n",
                              image="sonarqube", tag="community")
        self.assertEqual(result.tag, "26.8.0.126808-community")
        message = result.notices[0][0]
        self.assertIn("'community' is stale", message)
        self.assertIn("If the release overrides that ARG with --build-arg, keep 'tag' and remove 'dockerfile'", message)

    def test_matching_config_tag_needs_no_notice(self):
        self.assertEqual(self.resolve(BACKUPHELPER, tag="3.15-alpine").notices, [])

    def test_other_fields_are_kept(self):
        result = self.resolve(BACKUPHELPER, description="x", stage="prod")
        self.assertEqual(result.entry["description"], "x")
        self.assertEqual(result.entry["variable"], "BASE_DIGEST")
        self.assertEqual(result.entry["image"], "python")

    def test_image_and_tag_from_arg_defaults(self):
        result = self.resolve(IAM_LOGIN, image="ghcr.io/bauer-group/ep-zitadel/zitadel-login")
        self.assertEqual(result.tag, "latest")

    def test_registry_image_with_an_arg_tag(self):
        result = self.resolve(NOCODB_BACKUP, image="ghcr.io/bauer-group/cs-backuphelper/backuphelper")
        self.assertEqual(result.tag, "latest")

    def test_from_lines_naming_a_stage_are_skipped(self):
        result = self.resolve(IAM_DATABASE_BACKUP, image="ghcr.io/bauer-group/cs-backuphelper/backuphelper")
        self.assertEqual((result.tag, result.line), ("latest", 1))

    def test_docker_hub_spellings_match(self):
        self.assertEqual(self.resolve("FROM python:3.15\n", image="library/python").tag, "3.15")
        self.assertEqual(self.resolve("FROM docker.io/library/python:3.15\n", image="python").tag, "3.15")

    def test_different_tags_are_ambiguous(self):
        text = "FROM python:3.15-alpine AS build\nFROM python:3.15-slim AS prod\n"
        self.fails(text, "different tags", "3.15-alpine (line 1)", "3.15-slim (line 2)", "'stage'")

    def test_stage_selects_the_from_line(self):
        text = "FROM python:3.15-alpine AS build\nFROM python:3.15-slim AS Prod\n"
        self.assertEqual(self.resolve(text, stage="prod").tag, "3.15-slim")
        self.assertEqual(self.resolve(text, stage="PROD").tag, "3.15-slim")

    def test_from_index_selects_the_from_line(self):
        text = "FROM python:3.15-alpine AS build\nFROM python:3.15-slim AS prod\n"
        self.assertEqual(self.resolve(text, **{"from-index": 0}).tag, "3.15-alpine")
        self.assertEqual(self.resolve(text, **{"from-index": 1}).tag, "3.15-slim")

    def test_stage_and_from_index_together(self):
        self.fails(BACKUPHELPER, "either 'stage' or 'from-index'", stage="prod", **{"from-index": 0})

    def test_unknown_stage(self):
        self.fails(BACKUPHELPER, "no stage 'runtime'", "builder, test, prod", stage="runtime")

    def test_from_index_out_of_range(self):
        self.fails(BACKUPHELPER, "out of range", "3 FROM line(s)", **{"from-index": 3})

    def test_from_index_must_be_a_whole_number(self):
        for value in (True, -1, "1", 1.5, -1.0, float("nan")):
            with self.subTest(value=value):
                self.fails(BACKUPHELPER, "'from-index' must be a whole number", **{"from-index": value})

    def test_from_index_may_be_written_as_a_float(self):
        # JSON Schema counts 1.0 as an integer, so the schema accepts it.
        text = "FROM python:3.15-alpine AS build\nFROM python:3.15-slim AS prod\n"
        self.assertEqual(self.resolve(text, **{"from-index": 1.0}).tag, "3.15-slim")

    def test_selected_line_names_a_stage(self):
        self.fails(IAM_DATABASE_BACKUP, "builds on an earlier stage",
                   image="ghcr.io/bauer-group/cs-backuphelper/backuphelper", stage="test")

    def test_selected_line_uses_another_image(self):
        text = "FROM golang:1.26-alpine AS build\nFROM python:3.15-alpine AS prod\n"
        error = self.fails(text, "line 1 uses 'golang', not 'python'", "cross-check", stage="build")
        self.assertEqual((error.file, error.line), ("Dockerfile", 1))

    def test_image_not_in_the_dockerfile(self):
        self.fails("FROM golang:1.26-alpine AS build\nFROM alpine:3.23\n",
                   "no FROM line in Dockerfile uses 'python'", "line 1: golang:1.26-alpine", "line 2: alpine:3.23")

    def test_unresolvable_lines_are_named_when_nothing_matches(self):
        self.fails("ARG IMAGE\nFROM ${IMAGE}:3.15\n", "no FROM line", "${IMAGE} has no default value")

    def test_an_unreadable_line_fails_the_entry_next_to_readable_ones(self):
        # Without a selector the readable line alone would be monitored, while
        # the unreadable one may build on the image with another tag.
        cases = {
            "builder literal, prod from an ARG without default":
                ("ARG PY\nFROM python:3.15-alpine AS builder\nFROM python:${PY}-alpine AS prod\n",
                 "line 3: python:${PY}-alpine (${PY} has no default value"),
            "image from an ARG without default":
                ("ARG BASE\nFROM python:3.15-alpine AS builder\nFROM ${BASE} AS prod\n",
                 "line 3: ${BASE} (${BASE} has no default value"),
            "registry from an ARG without default":
                ("ARG REG\nFROM python:3.15-alpine AS builder\nFROM ${REG}/python:3.15-alpine\n", "line 3"),
            "digest from an ARG without default":
                ("ARG D\nFROM python:3.15-alpine AS builder\nFROM python@${D}\n", "line 3: python@${D}"),
            "Docker Hub spelling, ARG default that cannot be read":
                ("ARG V=${U}\nFROM python:3.15-alpine AS builder\nFROM docker.io/library/python:${V}\n",
                 "the default of 'ARG V=${U}' cannot be read"),
            "unparsable line":
                ("FROM python:3.15-alpine AS builder\nFROM python:3.14-alpine AS prod extra\n",
                 "line 2: python:3.14-alpine AS prod extra (cannot parse"),
        }
        for title, (text, fragment) in cases.items():
            with self.subTest(title):
                error = self.fails(text, fragment, "cannot be read, so it may use 'python' on another tag",
                                   "set 'stage' or 'from-index'")
                self.assertEqual((error.file, error.line), ("Dockerfile", text.count("\n")))

    def test_an_unreadable_line_of_another_image_is_not_the_image(self):
        text = "ARG GO\nFROM golang:${GO} AS build\nFROM python:3.15-alpine\n"
        self.assertEqual(self.resolve(text).tag, "3.15-alpine")

    def test_a_heredoc_body_is_no_unreadable_line(self):
        # Read as a FROM line, the body's "from PIL import Image" could not be
        # parsed and would fail both entries of COM-WhistleblowerApp.
        self.assertEqual(self.resolve(WHISTLEBLOWER, image="globaleaks/globaleaks").tag, "latest")
        self.assertEqual(self.resolve(WHISTLEBLOWER).tag, "3-alpine")

    def test_an_unterminated_heredoc_fails(self):
        # BuildKit rejects it; reading on would silently drop the FROM lines
        # after it - here the 9.9 line, which BuildKit's build would use.
        text = "FROM python:1.0 AS b\nRUN cat <<EOF\nno terminator\nFROM python:9.9\n"
        error = self.fails(text, "unterminated heredoc <<EOF", "Dockerfile")
        self.assertEqual(error.line, 2)
        self.assertEqual(error.file, "Dockerfile")

    def test_odd_quoting_cannot_hide_from_lines(self):
        # A quote that starts mid-word makes the << look like a heredoc to the
        # word splitter; the missing terminator must fail, not watch 1.0.
        text = 'FROM python:1.0 AS b\nRUN FOO="x <<EOF y" true\nFROM python:9.9\n'
        self.fails(text, "unterminated heredoc")

    def test_a_lone_carriage_return_does_not_end_a_line(self):
        # read_dockerfile() opens with newline="", so a lone CR inside a RUN
        # stays in that instruction (BuildKit splits at line feeds only).
        text = "FROM python:3.15-alpine\nRUN echo a\rFROM python:9.9\n"
        self.assertEqual(self.resolve(text).tag, "3.15-alpine")

    def test_a_selector_chooses_past_an_unreadable_line(self):
        text = "ARG PY\nFROM python:3.15-alpine AS builder\nFROM python:${PY}-alpine AS prod\n"
        self.assertEqual(self.resolve(text, stage="builder").tag, "3.15-alpine")
        self.assertEqual(self.resolve(text, **{"from-index": 0}).tag, "3.15-alpine")
        self.fails(text, "${PY} has no default value", stage="prod")

    def test_unresolvable_selected_line(self):
        error = self.fails("FROM python:${VERSION} AS prod\n", "${VERSION} has no default value", stage="prod")
        self.assertEqual(error.line, 1)

    def test_digest_pin_keeps_the_tag(self):
        self.assertEqual(self.resolve(f"FROM python:3.15-alpine@{DIGEST}\n").tag, "3.15-alpine")

    def test_digest_only_has_no_tag_to_monitor(self):
        self.fails(f"FROM python@{DIGEST}\n", "pins only a digest")

    def test_invalid_digest(self):
        self.fails("FROM python:3.15@sha256:zz\n", "not a valid digest")

    def test_no_tag_is_latest(self):
        self.assertEqual(self.resolve("FROM python\n").tag, "latest")

    def test_invalid_tag(self):
        self.fails('ARG V="3.15 alpine"\nFROM python:${V}\n', "'3.15 alpine' is not a valid tag")

    def test_no_from_line(self):
        self.fails("# empty\n", "has no FROM line")

    def test_missing_dockerfile(self):
        with self.assertRaises(rbi.ResolveError) as caught:
            rbi.resolve_entry({"name": "x", "image": "python", "dockerfile": "src/app/Dockerfile"}, self.root)
        self.assertIn("Dockerfile not found: src/app/Dockerfile", str(caught.exception))

    def test_paths_outside_the_repository(self):
        outside = tempfile.mkdtemp(prefix="resolve-outside-")
        self.addCleanup(shutil.rmtree, outside, True)
        with open(os.path.join(outside, "Dockerfile"), "w") as handle:
            handle.write("FROM python:3.15\n")
        relative = os.path.relpath(os.path.join(outside, "Dockerfile"), self.root)
        for path, fragment in ((relative, "outside the repository"),
                               (os.path.join(outside, "Dockerfile"), "relative to the repository root"),
                               ("/etc/Dockerfile", "relative to the repository root")):
            with self.subTest(path=path):
                with self.assertRaises(rbi.ResolveError) as caught:
                    rbi.resolve_entry({"name": "x", "image": "python", "dockerfile": path}, self.root)
                self.assertIn(fragment, str(caught.exception))

    def test_dockerfile_in_a_subdirectory(self):
        self.write("src/app/Dockerfile", BACKUPHELPER)
        result = rbi.resolve_entry({"name": "x", "image": "python", "dockerfile": "src/app/Dockerfile"}, self.root)
        self.assertEqual(result.tag, "3.15-alpine")

    def test_image_is_required(self):
        self.write("Dockerfile", BACKUPHELPER)
        for entry in ({"dockerfile": "Dockerfile"}, {"dockerfile": "Dockerfile", "image": "Python"}):
            with self.subTest(entry=entry):
                with self.assertRaises(rbi.ResolveError):
                    rbi.resolve_entry(entry, self.root)

    def test_empty_dockerfile_path(self):
        self.fails(BACKUPHELPER, "'dockerfile' must be the path", dockerfile="")


class CommandLine(RepoCase):
    def run_main(self, images):
        output = os.path.join(self.root, "out.json")
        stdout = io.StringIO()
        saved = sys.stdin
        sys.stdin = io.StringIO(images if isinstance(images, str) else json.dumps(images))
        try:
            with contextlib.redirect_stdout(stdout):
                code = rbi.main(["--output", output, "--root", self.root])
        finally:
            sys.stdin = saved
        result = None
        if os.path.exists(output):
            with open(output, encoding="utf-8") as handle:
                result = json.load(handle)
        return code, stdout.getvalue(), result

    def test_entries_without_dockerfile_are_unchanged(self):
        images = [
            {"name": "n8n", "image": "n8nio/n8n", "tag": "stable", "variable": "N8N_STABLE_DIGEST"},
            {"variable": "ODD_DIGEST", "tag": "latest", "image": "busybox", "name": "odd", "extra": [1, None]},
        ]
        code, log, result = self.run_main(images)
        self.assertEqual((code, result, log), (0, {"images": images, "unresolved": []}, ""))

    def test_resolved_list(self):
        self.write("src/app/Dockerfile", BACKUPHELPER)
        images = [
            {"name": "n8n", "image": "n8nio/n8n", "tag": "stable", "variable": "N8N_STABLE_DIGEST"},
            {"name": "python", "image": "python", "tag": "3.14-alpine", "dockerfile": "src/app/Dockerfile",
             "variable": "PYTHON_DIGEST"},
        ]
        code, log, result = self.run_main(images)
        self.assertEqual((code, result["unresolved"]), (0, []))
        self.assertEqual(result["images"][0], images[0])
        self.assertEqual(result["images"][1], dict(images[1], tag="3.15-alpine"))
        self.assertIn("::notice file=src/app/Dockerfile,line=4::python: the configured tag '3.14-alpine' is stale",
                      log)
        self.assertIn("python: python:3.15-alpine from src/app/Dockerfile line 4", log)

    def test_unresolved_entries_are_reported_and_left_out(self):
        # Never on a guessed tag, and never holding back the other entries:
        # the monitor checks those and fails the job at the end.
        self.write("Dockerfile", "FROM golang:1.26-alpine\n")
        self.write("src/app/Dockerfile", BACKUPHELPER)
        images = [
            {"name": "missing", "image": "python", "dockerfile": "nope/Dockerfile", "variable": "A"},
            {"name": "other", "image": "python", "tag": "3.14-alpine", "dockerfile": "Dockerfile", "variable": "B"},
            {"name": "plain", "image": "python", "tag": "3.15", "variable": "C"},
            {"name": "app", "image": "python", "dockerfile": "src/app/Dockerfile", "variable": "D"},
        ]
        code, log, result = self.run_main(images)
        self.assertEqual(code, 0)
        self.assertEqual(result["images"], [images[2], dict(images[3], tag="3.15-alpine")])
        self.assertEqual([(u["name"], u["image"], u["dockerfile"]) for u in result["unresolved"]],
                         [("missing", "python", "nope/Dockerfile"), ("other", "python", "Dockerfile")])
        self.assertIn("Dockerfile not found: nope/Dockerfile", result["unresolved"][0]["error"])
        self.assertIn("no FROM line in Dockerfile uses 'python'", result["unresolved"][1]["error"])
        self.assertIn("::error::missing: Dockerfile not found", log)
        self.assertIn("::error file=Dockerfile::other: no FROM line in Dockerfile uses 'python'", log)
        self.assertIn("2 of 3 entries with 'dockerfile' are not checked", log)
        self.assertNotIn("stale", log)

    def test_entries_sharing_a_variable_on_different_tags_are_not_checked(self):
        # An entry copied for a second Dockerfile without a new variable: both
        # would be compared with one stored digest and release on every check.
        self.write("src/a/Dockerfile", "FROM python:3.15-alpine\n")
        self.write("src/b/Dockerfile", "ARG V=3.14-alpine\nFROM python:${V}\n")
        images = [
            {"name": "a", "image": "python", "dockerfile": "src/a/Dockerfile", "variable": "PY"},
            {"name": "b", "image": "library/python", "dockerfile": "src/b/Dockerfile", "variable": "PY"},
            {"name": "c", "image": "python", "dockerfile": "src/a/Dockerfile", "variable": "PY_C"},
        ]
        code, log, result = self.run_main(images)
        self.assertEqual(code, 0)
        self.assertEqual([e["name"] for e in result["images"]], ["c"])
        self.assertEqual([u["name"] for u in result["unresolved"]], ["a", "b"])
        error = ("'variable' PY is used by entries checked on different images: a on "
                 "docker.io/library/python:3.15-alpine, b on docker.io/library/python:3.14-alpine")
        self.assertIn(error, result["unresolved"][0]["error"])
        self.assertIn(f"::error file=src/a/Dockerfile,line=1::a: {error}", log)
        self.assertIn(f"::error file=src/b/Dockerfile,line=2::b: {error}", log)
        self.assertIn("2 of 3 entries with 'dockerfile' are not checked", log)

    def test_an_entry_without_dockerfile_on_a_shared_variable_stays_as_it_was(self):
        # Kept from before the migration next to its new 'dockerfile' entry:
        # only the new entry is left out, the old one is checked as before.
        self.write("Dockerfile", "FROM python:3.15-alpine\n")
        images = [
            {"name": "old", "image": "python", "tag": "3.14-alpine", "variable": "PY"},
            {"name": "new", "image": "python", "dockerfile": "Dockerfile", "variable": "PY"},
        ]
        code, log, result = self.run_main(images)
        self.assertEqual((code, result["images"]), (0, [images[0]]))
        self.assertEqual([u["name"] for u in result["unresolved"]], ["new"])
        self.assertIn("old on docker.io/library/python:3.14-alpine, new on docker.io/library/python:3.15-alpine",
                      result["unresolved"][0]["error"])

    def test_entries_sharing_a_variable_on_the_same_image_and_tag_are_fine(self):
        self.write("src/a/Dockerfile", "FROM python:3.15-alpine\n")
        self.write("src/b/Dockerfile", "FROM docker.io/library/python:3.15-alpine AS prod\n")
        images = [
            {"name": "a", "image": "python", "dockerfile": "src/a/Dockerfile", "variable": "PY"},
            {"name": "b", "image": "python", "dockerfile": "src/b/Dockerfile", "variable": "PY"},
            {"name": "c", "image": "docker.io/python", "tag": "3.15-alpine", "variable": "PY"},
        ]
        code, _, result = self.run_main(images)
        self.assertEqual((code, len(result["images"]), result["unresolved"]), (0, 3, []))

    def test_error_annotation_points_at_the_from_line(self):
        self.write("Dockerfile", "FROM golang:1.26-alpine AS build\n")
        code, log, result = self.run_main([{"name": "p", "image": "python", "dockerfile": "Dockerfile", "stage": "build"}])
        self.assertEqual((code, result["images"]), (0, []))
        self.assertIn("::error file=Dockerfile,line=1::p: Dockerfile line 1 uses 'golang'", log)

    def test_invalid_input(self):
        self.assertEqual(self.run_main("not json")[:3:2], (1, None))
        self.assertEqual(self.run_main({"images": []})[:3:2], (1, None))

    def test_config_values_cannot_start_a_workflow_command(self):
        self.write("Dockerfile", "FROM python:3.15\n")
        code, log, _ = self.run_main([
            {"name": "a\n::warning::forged", "image": "python", "dockerfile": "Dockerfile", "tag": "3.14"},
            {"name": "b\n::warning::forged", "image": "golang", "dockerfile": "Dockerfile"},
        ])
        self.assertEqual(code, 0)
        self.assertFalse([line for line in log.splitlines() if line.startswith("::warning::")], log)
        self.assertIn("a%0A::warning::forged", log)

    def test_command_escapes_properties(self):
        self.assertEqual(rbi.command("error", "50% done\r\n", "a,b:c", 3), "::error file=a%2Cb%3Ac,line=3::50%25 done%0D%0A")
        self.assertEqual(rbi.command("notice", "x"), "::notice::x")


class Script(RepoCase):
    def test_runs_isolated_as_the_action_runs_it(self):
        self.write("Dockerfile", BACKUPHELPER)
        output = os.path.join(self.root, "out.json")
        # A module of the caller's repository must not shadow the standard library.
        self.write("json.py", "raise SystemExit('caller module imported')\n")
        process = subprocess.run(
            [sys.executable, "-I", SCRIPT, "--output", output],
            input=json.dumps([{"name": "p", "image": "python", "dockerfile": "Dockerfile", "variable": "P"}]),
            cwd=self.root, capture_output=True, text=True, encoding="utf-8", timeout=60)
        self.assertEqual(process.returncode, 0, process.stdout + process.stderr)
        with open(output, encoding="utf-8") as handle:
            self.assertEqual(json.load(handle)["images"][0]["tag"], "3.15-alpine")


if __name__ == "__main__":
    unittest.main(verbosity=2)
