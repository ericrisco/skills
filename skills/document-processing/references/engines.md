# Engines: install, version pins, licensing, troubleshooting

Offloaded depth for `document-processing`. Read before a non-trivial install or when a job hits a quirk.

## Install matrix + version pins

| Library | Install | Pin (current stable, 2026-06) | Notes |
|---|---|---|---|
| pypdf | `pip install pypdf` | `pypdf==6.12.2` | Pure-Python, no C deps. Runs in Lambda / slim containers. Core: read/write/merge/split/rotate/forms. |
| pdfplumber | `pip install pdfplumber` | latest | Layout-aware text + `extract_tables()`. Built on pdfminer.six. |
| docxtpl | `pip install docxtpl` | `docxtpl==0.20.*` | python-docx-template. Jinja2 over a real `.docx`. Pulls in python-docx + Jinja2. |
| python-docx | `pip install python-docx` | latest | Programmatic DOCX when you build the doc from code, not from a template. |
| reportlab | `pip install reportlab` | latest | PDF generation: low-level `canvas` and high-level Platypus flowables. |
| docling | `pip install docling` | latest | IBM / LF AI local pipeline. First run downloads models. CPU works; GPU is faster. |
| marker | `pip install marker-pdf` | latest | Datalab pipeline on the Surya engine. PDF/image → Markdown/JSON/HTML. GPU recommended. |
| pytesseract | `pip install pytesseract` + system Tesseract | latest | Needs the Tesseract binary: macOS `brew install tesseract`, Debian `apt install tesseract-ocr`. Add `tesseract-ocr-<lang>` packs for non-English. |
| mistralai | `pip install mistralai` | latest | Hosted OCR client. Needs `MISTRAL_API_KEY`. No local model download. |
| PyMuPDF | `pip install pymupdf` | latest | ⚠️ **AGPL** — see licensing. Fastest extract + easiest page→PNG raster + annotations. |

## Licensing — read before you ship

| Library | License | Implication |
|---|---|---|
| pypdf | BSD-3 | Permissive. Ship freely. |
| pdfplumber | MIT | Permissive. |
| python-docx / docxtpl | MIT / LGPL-ish | Permissive enough for commercial use. |
| reportlab | BSD (open-source edition) | Open edition is BSD; "ReportLab PLUS" is the paid product. The `reportlab` PyPI package is the open one. |
| docling | MIT | Permissive, local, no per-page cost. |
| marker / surya | check current repo license | Historically had usage-revenue conditions on Surya weights — verify before commercial deployment. |
| **PyMuPDF** | **AGPL-3.0** | **Network/SaaS use can trigger source-disclosure obligations.** Either comply with AGPL (open your source) or buy Artifex's commercial license. Do not slip it into a closed product silently. |
| Mistral OCR | Hosted, paid | ~$2 / 1,000 pages; 50% off via Batch API. No code license issue — it is an API. Data leaves the machine. |
| Tesseract | Apache-2.0 | Permissive, free, local. |

## Local OCR vs hosted: Docling vs Marker vs Mistral

| Dimension | Docling | Marker | Mistral OCR |
|---|---|---|---|
| Runs | Local | Local | Hosted API |
| Cost | Free (compute only) | Free (compute only) | ~$2 / 1k pages (50% off batch) |
| Best at | Layout + reading order, table structure, many input formats (PDF/DOCX/PPTX/XLSX/HTML/images) | Clean Markdown from PDFs/images, equations, code blocks | Messy scans, handwriting, complex tables, forms |
| OCR backend | Wraps Tesseract / EasyOCR / RapidOCR | Surya recognition engine | Proprietary (`mistral-ocr-2512`, OCR 3) |
| Output | Markdown / JSON | Markdown / JSON / HTML | Markdown / JSON, interleaved text+images |
| Pick when | Data must stay local; batch conversion; varied formats | Local + want deterministic layout parsing | Quality matters more than per-page cost; handwriting; API budget fine |

Decision: **data must stay local → Docling (varied formats) or Marker (PDF→Markdown).** **Handwriting / messy / API budget fine → Mistral OCR.** **Clean scan, zero budget, simple layout → plain `pytesseract`.**

## Troubleshooting

**Encrypted / password PDFs.** `PdfReader` raises on encrypted files. Decrypt first:

```python
from pypdf import PdfReader

reader = PdfReader("locked.pdf")
if reader.is_encrypted:
    reader.decrypt("the-password")  # empty string for owner-locked-but-readable PDFs
```

Some PDFs are owner-locked (printing/editing disabled) but openable with `reader.decrypt("")`.

**AcroForm fields fill but show blank, or names look mangled.** Dump `get_fields()` and inspect `/FT` and the exact keys — field names are case-sensitive and often have a hierarchy (`section1.name`). For checkbox/radio, the value is the on-state from `/V` (commonly `/Yes`), not `True`. If a fill writes but the viewer renders nothing, the AcroForm may lack `/NeedAppearances`; setting `auto_regenerate=False` and flattening sidesteps appearance-stream issues.

**Multi-column reading order is scrambled.** pdfplumber reads in PDF object order, which can interleave columns. For complex layouts (academic papers, newspapers) prefer Docling/Marker, which do explicit reading-order analysis, over raw pdfplumber text.

**CJK / accented text comes out as boxes or mojibake.** For OCR, install the matching Tesseract language pack (`tesseract-ocr-jpn`, `-chi-sim`, `-cat`, ...) and pass `lang=`. For extraction, the font may lack a ToUnicode map — that is a broken text layer; fall back to OCR. Handwriting: Tesseract is poor; use Mistral OCR.

**Lambda / container cold-start size.** pypdf + pdfplumber are small and pure-Python — fine in a slim image. Docling/Marker pull large model weights — bake them into the image or mount a cache; do not download on every cold start.
