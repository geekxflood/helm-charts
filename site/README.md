# `site/` — static site generator

The geekxflood Helm chart repository ships a hand-rolled static documentation
site that is published to GitHub Pages at <https://geekxflood.github.io/helm-charts/>.

The site coexists with `index.yaml` at the root of the Pages branch so that
`helm repo add geekxflood https://geekxflood.github.io/helm-charts` keeps
working — the build only writes to `site/_build/` and never to the repo root.

## Layout

```
site/
├── generator/
│   ├── build.py            # the generator
│   └── requirements.txt    # pinned Python deps
├── src/
│   ├── templates/          # Jinja2 templates (base, index, chart, 404)
│   └── assets/             # css / js / img copied verbatim into _build/assets
└── _build/                 # generated output (gitignored)
```

## Build

Requires Python 3.11+.

```bash
python -m venv .venv && source .venv/bin/activate
pip install -r site/generator/requirements.txt
python site/generator/build.py
```

The build writes everything to `site/_build/`:

- `site/_build/index.html` — landing page
- `site/_build/charts/<name>/index.html` — per-chart detail page
- `site/_build/charts.json` — machine-readable chart index
- `site/_build/sitemap.xml`
- `site/_build/assets/...` — css / js / images

## Preview locally

The site links every asset through `BASE_PATH` (default `/helm-charts`), which
is the GitHub Pages prefix. To preview locally with that prefix, serve one
directory above and visit `/helm-charts/`:

```bash
python site/generator/build.py
mkdir -p _preview/helm-charts
cp -r site/_build/* _preview/helm-charts/
python -m http.server -d _preview 8000
# then open http://localhost:8000/helm-charts/
```

Or build with an empty `BASE_PATH` and serve `site/_build` directly:

```bash
BASE_PATH= python site/generator/build.py
python -m http.server -d site/_build 8000
# then open http://localhost:8000/
```

## What the generator does

1. Discovers every `charts/*/Chart.yaml` and parses metadata (name, version,
   appVersion, description, keywords, home, sources, maintainers, icon).
2. Renders each chart's `README.md` to HTML with python-markdown
   (`fenced_code`, `tables`, `toc`, `codehilite`, `attr_list`).
3. Walks each `values.yaml` top-level (and one nested level) and extracts
   key path, default value, and the leading `#` comment block as a
   description — used to build the "Values reference" table on every chart
   page, even when the chart's README is sparse.
4. Renders the landing page, grouping charts by inferred category
   (media servers / *arr stack / downloaders / requests / transcoding /
   AI & LLM / identity / infra / monitoring / misc).
5. Copies static assets and per-chart icons into `_build/`.
6. Emits `charts.json` and `sitemap.xml`.

## Customising

- **Accent / theme:** all colour tokens live at the top of
  `src/assets/css/site.css` under `:root` and `[data-theme="light"]`.
- **Templates:** Jinja2 templates under `src/templates/`. `base.html` is the
  shell; `index.html` and `chart.html` extend it.
- **Categories:** edit `CATEGORY_DEFS` in `generator/build.py`. Each entry
  is `(slug, label, keyword_match_set, name_match_set)` and the first
  matching category wins; charts that match nothing land in "Miscellaneous".

## Constraints

- Pure Python — no Node toolchain.
- No external runtime JS dependencies. Search is a ~60-line vanilla script.
- All asset URLs are prefixed with `BASE_PATH` so the same build works at
  `/helm-charts/` on GitHub Pages and at `/` for local previews.
- The build never writes outside `site/_build/`. `index.yaml` and every
  other root file are untouched.
