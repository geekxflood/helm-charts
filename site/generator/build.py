#!/usr/bin/env python3
"""
Static site generator for the geekxflood Helm chart repository.

Outputs to site/_build/. Discovers all charts in charts/*/, parses their
Chart.yaml + values.yaml + README.md, and renders a landing page plus
per-chart detail pages with auto-generated values reference tables.

Invocation:
    python site/generator/build.py
"""

from __future__ import annotations

import json
import os
import re
import shutil
import sys
from dataclasses import dataclass, field
from datetime import datetime, timezone
from pathlib import Path
from typing import Any, Iterable

import markdown
import yaml
from jinja2 import Environment, FileSystemLoader, select_autoescape

# ---------------------------------------------------------------------------
# Paths & config
# ---------------------------------------------------------------------------

REPO_ROOT = Path(__file__).resolve().parents[2]
SITE_ROOT = REPO_ROOT / "site"
SRC_ROOT = SITE_ROOT / "src"
TEMPLATES_DIR = SRC_ROOT / "templates"
ASSETS_DIR = SRC_ROOT / "assets"
BUILD_DIR = SITE_ROOT / "_build"
CHARTS_DIR = REPO_ROOT / "charts"
ROOT_LOGO = REPO_ROOT / "assets" / "icon.png"

# GitHub Pages serves the repo at /helm-charts/. Allow override for local
# previews where the user might serve from the build dir directly.
BASE_PATH = os.environ.get("BASE_PATH", "/helm-charts").rstrip("/")

REPO_URL = "https://github.com/geekxflood/helm-charts"
SITE_URL = "https://geekxflood.github.io/helm-charts"
HELM_REPO_NAME = "geekxflood"


# ---------------------------------------------------------------------------
# Category inference
# ---------------------------------------------------------------------------

CATEGORY_DEFS: list[tuple[str, str, set[str], set[str]]] = [
    # (slug, label, keyword_match, name_match)
    (
        "media-servers",
        "Media servers",
        {
            "media",
            "streaming",
            "jellyfin",
            "plex",
            "audiobook",
            "audiobooks",
            "podcast",
            "podcasts",
            "ebook",
            "books",
        },
        {"jellyfin", "plex", "audiobookshelf"},
    ),
    (
        "arr-stack",
        "*arr stack",
        {
            "arr",
            "sonarr",
            "radarr",
            "lidarr",
            "readarr",
            "bazarr",
            "prowlarr",
            "indexer",
            "subtitle",
            "subtitles",
        },
        {
            "sonarr",
            "radarr",
            "lidarr",
            "readarr",
            "bazarr",
            "prowlarr",
            "huntarr",
            "lingarr",
            "backuparr",
            "cleanuparr",
            "kapowarr",
            "lazylibrarian",
            "rreading-glasses",
            "flaresolverr",
        },
    ),
    (
        "downloaders",
        "Downloaders",
        {"download", "torrent", "usenet", "nzb", "vpn"},
        {"sabnzbd", "transmission-openvpn"},
    ),
    (
        "requests",
        "Requests & discovery",
        {"requests", "overseerr", "jellyseerr", "ombi"},
        {"overseerr", "overseer", "seerr", "wizarr"},
    ),
    (
        "transcoding",
        "Transcoding & media tools",
        {"transcode", "transcoding", "ffmpeg", "gpu-transcoding"},
        {
            "tdarr",
            "tdarr_node",
            "tdarr_server",
            "unmanic",
            "subgen",
            "posterizarr",
            "ersatztv",
            "dizquetv",
            "tunarr",
            "program-director",
            "tautulli",
            "tautulli-exporter",
            "openwatchparty",
        },
    ),
    (
        "ai-llm",
        "AI & LLM",
        {"ai", "llm", "ollama", "machine-learning", "speech", "whisper"},
        {"ollama", "open-webui", "whisper"},
    ),
    (
        "identity",
        "Identity & access",
        {"identity", "authentication", "sso", "oauth", "oidc", "ldap"},
        {"keycloak", "oauth2-proxy"},
    ),
    (
        "infra",
        "Infrastructure",
        {
            "database",
            "postgresql",
            "postgres",
            "storage",
            "s3",
            "ha",
            "high-availability",
            "secrets",
            "vault",
            "backup",
        },
        {"postgres-ha", "garage", "openbao-unsealer", "database-provisioner"},
    ),
    (
        "monitoring",
        "Monitoring & docs",
        {"monitoring", "metrics", "exporter", "docs", "documentation", "mkdocs"},
        {"mkdocs-material", "tautulli-exporter"},
    ),
]

DEFAULT_CATEGORY = ("misc", "Miscellaneous")


def infer_category(name: str, keywords: Iterable[str]) -> tuple[str, str]:
    kws = {k.lower() for k in keywords or []}
    nm = name.lower()
    for slug, label, kw_match, name_match in CATEGORY_DEFS:
        if nm in name_match:
            return slug, label
        if kws & kw_match:
            return slug, label
    return DEFAULT_CATEGORY


# ---------------------------------------------------------------------------
# values.yaml comment extractor
# ---------------------------------------------------------------------------
#
# We walk values.yaml at the top level (and one nested level for common keys
# like image.repository) and extract:
#   - key path (dotted)
#   - default value (compact YAML repr)
#   - leading-comment description (block of `#` lines directly above)
#
# This is a line-based scan, not a full parser — that lets us preserve the
# author's inline documentation that PyYAML throws away.


@dataclass
class ValueEntry:
    path: str
    default: str
    description: str
    depth: int = 0


_INDENT_RE = re.compile(r"^( *)([^\s#].*)$")
_KEY_RE = re.compile(r"^([A-Za-z_][\w-]*)\s*:(?:\s*(.*))?$")


def _format_default(raw_value: str, sub_lines: list[str]) -> str:
    """Render a compact default. If the value spans multiple lines (a mapping
    or list), return a short placeholder rather than dumping all of it."""
    raw = (raw_value or "").strip()
    if raw and raw not in ("|", ">", "|-", ">-"):
        # Strip trailing inline comments unless quoted
        if not (raw.startswith('"') or raw.startswith("'")):
            hash_pos = raw.find(" #")
            if hash_pos != -1:
                raw = raw[:hash_pos].rstrip()
        # Truncate huge inline strings
        if len(raw) > 80:
            raw = raw[:77] + "..."
        return raw
    # Inspect sub_lines: empty mapping/list?
    non_empty = [s for s in sub_lines if s.strip() and not s.lstrip().startswith("#")]
    if not non_empty:
        return "{}"
    first = non_empty[0].strip()
    if first.startswith("-"):
        return "[...]"
    return "{...}"


def parse_values_doc(values_path: Path, max_depth: int = 1) -> list[ValueEntry]:
    """Extract documented top-level + first-nested keys with their defaults
    and any leading `#` comment block."""
    if not values_path.exists():
        return []
    text = values_path.read_text(encoding="utf-8")
    lines = text.splitlines()

    entries: list[ValueEntry] = []
    pending_comments: list[str] = []
    # Stack of (indent, key_name) for path reconstruction
    stack: list[tuple[int, str]] = []

    i = 0
    while i < len(lines):
        line = lines[i]
        stripped = line.strip()

        if not stripped:
            # Blank line — break the comment block (don't carry across gaps)
            pending_comments = []
            i += 1
            continue

        if stripped.startswith("---"):
            i += 1
            continue

        # Comment line — accumulate, strip leading `#` and one optional space
        if stripped.startswith("#"):
            cleaned = stripped.lstrip("#")
            if cleaned.startswith(" "):
                cleaned = cleaned[1:]
            pending_comments.append(cleaned)
            i += 1
            continue

        m_indent = _INDENT_RE.match(line)
        if not m_indent:
            pending_comments = []
            i += 1
            continue
        indent = len(m_indent.group(1))
        rest = m_indent.group(2)

        # List item at top level — ignore
        if rest.startswith("-"):
            pending_comments = []
            i += 1
            continue

        m_key = _KEY_RE.match(rest)
        if not m_key:
            pending_comments = []
            i += 1
            continue

        key = m_key.group(1)
        value_part = m_key.group(2) or ""

        # Pop stack to current depth
        while stack and stack[-1][0] >= indent:
            stack.pop()

        depth = len(stack)
        path_parts = [s[1] for s in stack] + [key]
        full_path = ".".join(path_parts)

        # Find lines that belong to this key (greater indent, until we
        # hit something <= indent or EOF). We use them to render a clean
        # default placeholder for mapping/list values.
        sub_lines: list[str] = []
        j = i + 1
        while j < len(lines):
            nxt = lines[j]
            if not nxt.strip():
                sub_lines.append(nxt)
                j += 1
                continue
            nxt_indent_m = _INDENT_RE.match(nxt)
            if not nxt_indent_m:
                # Pure comment line — keep walking
                if nxt.lstrip().startswith("#"):
                    sub_lines.append(nxt)
                    j += 1
                    continue
                break
            nxt_indent = len(nxt_indent_m.group(1))
            if nxt_indent <= indent:
                break
            sub_lines.append(nxt)
            j += 1

        if depth <= max_depth:
            description = "\n".join(pending_comments).strip()
            default = _format_default(value_part, sub_lines)
            entries.append(
                ValueEntry(
                    path=full_path,
                    default=default,
                    description=description,
                    depth=depth,
                )
            )

        stack.append((indent, key))
        pending_comments = []
        i += 1

    return entries


# ---------------------------------------------------------------------------
# Markdown rendering & TOC extraction
# ---------------------------------------------------------------------------


def make_markdown() -> markdown.Markdown:
    return markdown.Markdown(
        extensions=[
            "fenced_code",
            "tables",
            "toc",
            "codehilite",
            "attr_list",
        ],
        extension_configs={
            "codehilite": {
                "guess_lang": False,
                "css_class": "codehilite",
                "noclasses": False,
            },
            "toc": {
                "permalink": False,
                "toc_depth": "2-3",
            },
        },
        output_format="html5",
    )


@dataclass
class TocItem:
    level: int
    title: str
    anchor: str


def extract_toc_from_md(md_text: str) -> list[TocItem]:
    """Walk the README looking for level-2 and level-3 headings and produce
    anchor slugs matching python-markdown's `toc` extension (lowercase, dashes
    for spaces, alphanumerics + dash kept)."""
    toc: list[TocItem] = []
    in_fence = False
    for raw in md_text.splitlines():
        if raw.startswith("```") or raw.startswith("~~~"):
            in_fence = not in_fence
            continue
        if in_fence:
            continue
        m = re.match(r"^(#{2,3})\s+(.+?)\s*#*\s*$", raw)
        if not m:
            continue
        level = len(m.group(1))
        title = m.group(2).strip()
        anchor = slugify_heading(title)
        toc.append(TocItem(level=level, title=title, anchor=anchor))
    return toc


def slugify_heading(text: str) -> str:
    # Matches python-markdown's default toc slugify reasonably well
    text = text.lower()
    text = re.sub(r"[^\w\s-]", "", text)
    text = re.sub(r"[-\s]+", "-", text).strip("-")
    return text


# ---------------------------------------------------------------------------
# Chart discovery
# ---------------------------------------------------------------------------


@dataclass
class Chart:
    name: str
    version: str
    app_version: str
    description: str
    keywords: list[str]
    home: str
    sources: list[str]
    maintainers: list[dict]
    icon_path: Path | None
    icon_ext: str
    category_slug: str
    category_label: str
    readme_md: str
    values_entries: list[ValueEntry] = field(default_factory=list)


def discover_charts() -> list[Chart]:
    charts: list[Chart] = []
    for chart_yaml in sorted(CHARTS_DIR.glob("*/Chart.yaml")):
        chart_dir = chart_yaml.parent
        try:
            meta = yaml.safe_load(chart_yaml.read_text(encoding="utf-8")) or {}
        except yaml.YAMLError as exc:
            print(f"  ! skipping {chart_dir.name}: {exc}", file=sys.stderr)
            continue

        name = str(meta.get("name") or chart_dir.name)
        version = str(meta.get("version") or "0.0.0")
        app_version = str(meta.get("appVersion") or "")
        description = (meta.get("description") or "").strip()
        keywords = list(meta.get("keywords") or [])
        home = (meta.get("home") or "").strip()
        sources = list(meta.get("sources") or [])
        maintainers = list(meta.get("maintainers") or [])

        # Local icon (svg/png) under charts/<name>/assets/
        icon_path: Path | None = None
        icon_ext = ""
        for ext in (".svg", ".png", ".jpg", ".jpeg"):
            candidate = chart_dir / "assets" / f"icon{ext}"
            if candidate.exists():
                icon_path = candidate
                icon_ext = ext
                break

        readme_path = chart_dir / "README.md"
        readme_md = (
            readme_path.read_text(encoding="utf-8") if readme_path.exists() else ""
        )

        values_entries = parse_values_doc(chart_dir / "values.yaml")

        cat_slug, cat_label = infer_category(name, keywords)

        charts.append(
            Chart(
                name=name,
                version=version,
                app_version=app_version,
                description=description,
                keywords=keywords,
                home=home,
                sources=sources,
                maintainers=maintainers,
                icon_path=icon_path,
                icon_ext=icon_ext,
                category_slug=cat_slug,
                category_label=cat_label,
                readme_md=readme_md,
                values_entries=values_entries,
            )
        )
    return charts


# ---------------------------------------------------------------------------
# Build
# ---------------------------------------------------------------------------


def asset(path: str) -> str:
    """Prefix BASE_PATH for any in-site link. Idempotent on absolute URLs."""
    if path.startswith(("http://", "https://", "mailto:", "#")):
        return path
    if not path.startswith("/"):
        path = "/" + path
    return f"{BASE_PATH}{path}"


def copy_tree(src: Path, dst: Path) -> None:
    if dst.exists():
        shutil.rmtree(dst)
    shutil.copytree(src, dst)


def build_site() -> None:
    started = datetime.now(timezone.utc)
    print(f"[build] BASE_PATH={BASE_PATH!r}")
    print(f"[build] charts dir: {CHARTS_DIR}")

    # 1. Clean & recreate build dir
    if BUILD_DIR.exists():
        shutil.rmtree(BUILD_DIR)
    BUILD_DIR.mkdir(parents=True)

    # 2. Copy static assets
    if ASSETS_DIR.exists():
        copy_tree(ASSETS_DIR, BUILD_DIR / "assets")
    # Always ship the repo logo at /assets/img/logo.png so templates can rely
    # on a single canonical location.
    img_dst = BUILD_DIR / "assets" / "img"
    img_dst.mkdir(parents=True, exist_ok=True)
    if ROOT_LOGO.exists():
        shutil.copy2(ROOT_LOGO, img_dst / "logo.png")

    # 3. Discover charts
    charts = discover_charts()
    print(f"[build] discovered {len(charts)} charts")

    # 4. Jinja env
    env = Environment(
        loader=FileSystemLoader(str(TEMPLATES_DIR)),
        autoescape=select_autoescape(["html"]),
        trim_blocks=True,
        lstrip_blocks=True,
    )
    env.globals["base_path"] = BASE_PATH
    env.globals["asset"] = asset
    env.globals["repo_url"] = REPO_URL
    env.globals["site_url"] = SITE_URL
    env.globals["helm_repo_name"] = HELM_REPO_NAME
    env.globals["build_time"] = started.strftime("%Y-%m-%d %H:%M UTC")
    env.globals["build_year"] = started.year

    chart_template = env.get_template("chart.html")
    index_template = env.get_template("index.html")
    notfound_template = env.get_template("404.html")

    # 5. Render per-chart pages
    md_renderer = make_markdown()
    chart_records: list[dict[str, Any]] = []

    for chart in charts:
        md_renderer.reset()
        readme_html = md_renderer.convert(chart.readme_md) if chart.readme_md else ""
        toc_items = extract_toc_from_md(chart.readme_md) if chart.readme_md else []

        # Copy icon (if any) into the chart's output dir
        out_dir = BUILD_DIR / "charts" / chart.name
        out_dir.mkdir(parents=True, exist_ok=True)

        icon_url = None
        if chart.icon_path is not None:
            dst = out_dir / f"icon{chart.icon_ext}"
            shutil.copy2(chart.icon_path, dst)
            icon_url = asset(f"/charts/{chart.name}/icon{chart.icon_ext}")

        page = chart_template.render(
            chart=chart,
            readme_html=readme_html,
            toc_items=toc_items,
            icon_url=icon_url,
            install_lines=[
                f"helm repo add {HELM_REPO_NAME} {SITE_URL}",
                "helm repo update",
                f"helm install <release-name> {HELM_REPO_NAME}/{chart.name}",
            ],
            page_title=f"{chart.name} - geekxflood Helm charts",
            canonical_url=f"{SITE_URL}/charts/{chart.name}/",
        )
        (out_dir / "index.html").write_text(page, encoding="utf-8")

        chart_records.append(
            {
                "name": chart.name,
                "version": chart.version,
                "appVersion": chart.app_version,
                "description": chart.description,
                "keywords": chart.keywords,
                "category": chart.category_slug,
                "categoryLabel": chart.category_label,
                "home": chart.home,
                "sources": chart.sources,
                "icon": icon_url,
                "url": asset(f"/charts/{chart.name}/"),
            }
        )

    # 6. Render landing page (group by category, preserving CATEGORY_DEFS order)
    order = [slug for slug, _, _, _ in CATEGORY_DEFS] + [DEFAULT_CATEGORY[0]]
    grouped: dict[str, dict[str, Any]] = {}
    for chart in charts:
        bucket = grouped.setdefault(
            chart.category_slug,
            {"slug": chart.category_slug, "label": chart.category_label, "charts": []},
        )
        bucket["charts"].append(chart)
    grouped_ordered = [grouped[k] for k in order if k in grouped]
    for g in grouped_ordered:
        g["charts"].sort(key=lambda c: c.name)

    index_html = index_template.render(
        charts=charts,
        groups=grouped_ordered,
        total_count=len(charts),
        page_title="geekxflood Helm charts",
        canonical_url=f"{SITE_URL}/",
        install_command=f"helm repo add {HELM_REPO_NAME} {SITE_URL}",
    )
    (BUILD_DIR / "index.html").write_text(index_html, encoding="utf-8")

    # 7. 404 page
    notfound_html = notfound_template.render(
        page_title="Not found - geekxflood Helm charts",
        canonical_url=f"{SITE_URL}/404.html",
    )
    (BUILD_DIR / "404.html").write_text(notfound_html, encoding="utf-8")

    # 8. charts.json (machine-readable)
    (BUILD_DIR / "charts.json").write_text(
        json.dumps(
            {
                "generated": started.isoformat(),
                "count": len(chart_records),
                "charts": chart_records,
            },
            indent=2,
        ),
        encoding="utf-8",
    )

    # 9. sitemap.xml
    urls = [f"{SITE_URL}/"] + [f"{SITE_URL}/charts/{c.name}/" for c in charts]
    sitemap_entries = "\n".join(
        f"  <url><loc>{u}</loc><lastmod>{started.date()}</lastmod></url>" for u in urls
    )
    sitemap = (
        '<?xml version="1.0" encoding="UTF-8"?>\n'
        '<urlset xmlns="http://www.sitemaps.org/schemas/sitemap/0.9">\n'
        f"{sitemap_entries}\n"
        "</urlset>\n"
    )
    (BUILD_DIR / "sitemap.xml").write_text(sitemap, encoding="utf-8")

    # 10. Pygments stylesheet (one-dark inspired). We ship our own dark theme
    # alongside site.css. site.css references these classes; we just dump the
    # Pygments default-classes file so users can switch later.
    try:
        from pygments.formatters import HtmlFormatter

        pyg_css = HtmlFormatter(style="one-dark").get_style_defs(".codehilite")
        (BUILD_DIR / "assets" / "css" / "pygments.css").write_text(
            pyg_css, encoding="utf-8"
        )
    except Exception as exc:  # pragma: no cover - pygments style availability varies
        print(f"  ! could not write pygments stylesheet: {exc}", file=sys.stderr)

    elapsed = (datetime.now(timezone.utc) - started).total_seconds()
    print(f"[build] wrote {BUILD_DIR} ({len(charts)} charts) in {elapsed:.2f}s")


if __name__ == "__main__":
    build_site()
