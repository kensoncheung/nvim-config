#!/usr/bin/env bash
#
# clean-treesitter-parsers.sh — move nvim-treesitter parsers that shadow Neovim's bundled ones.
#
# Neovim 0.12 ships parsers (c, lua, markdown, markdown_inline, query, vim, vimdoc)
# whose grammars match its runtime queries. nvim-treesitter also installs copies
# under parser/; because the plugin directory comes first in 'runtimepath', an
# outdated copy shadows the bundled parser and queries fail to load
# (E5113: Query error ... Invalid field name "operator").
#
# This script moves such duplicates into a timestamped backup directory. It is
# idempotent: a second run finds nothing to do.
#
# Usage:
#   ./scripts/clean-treesitter-parsers.sh            # move shadowing parsers to backup
#   ./scripts/clean-treesitter-parsers.sh --dry-run  # list what would move, change nothing
#   ./scripts/clean-treesitter-parsers.sh --help
#
# Env overrides:
#   NVIM_BIN        nvim executable (default: nvim)
#   TS_PARSER_DIR   parser dir to clean
#                   (default: $XDG_DATA_HOME/nvim/site/pack/packer/start/nvim-treesitter/parser)
#   BACKUP_DIR      backup root (default: $XDG_DATA_HOME/nvim/treesitter-parser-backup)
#
# Rollback: move the files from the printed backup directory back into TS_PARSER_DIR.
#
set -euo pipefail

usage() {
  sed -n '3,25p' "$0" | sed 's/^# \{0,1\}//'
}

dry_run=0
case "${1:-}" in
  -h|--help) usage; exit 0 ;;
  --dry-run) dry_run=1 ;;
  "") ;;
  *) echo "unknown argument: $1" >&2; usage >&2; exit 2 ;;
esac

NVIM_BIN="${NVIM_BIN:-nvim}"
DATA_DIR="${XDG_DATA_HOME:-$HOME/.local/share}/nvim"
TS_PARSER_DIR="${TS_PARSER_DIR:-$DATA_DIR/site/pack/packer/start/nvim-treesitter/parser}"
BACKUP_ROOT="${BACKUP_DIR:-$DATA_DIR/treesitter-parser-backup}"

if ! command -v "$NVIM_BIN" >/dev/null 2>&1; then
  echo "error: nvim executable not found: $NVIM_BIN" >&2
  exit 1
fi

if [ ! -d "$TS_PARSER_DIR" ]; then
  echo "nothing to clean: $TS_PARSER_DIR does not exist"
  exit 0
fi

# Languages whose parsers Neovim itself ships. --clean keeps user config and
# pack plugins out of 'runtimepath', so only bundled parsers are listed.
# io.write goes to stdout; print/echo in headless nvim go to stderr.
if ! bundled=$("$NVIM_BIN" --clean --headless \
  +'lua for _, f in ipairs(vim.api.nvim_get_runtime_file("parser/*", true)) do io.write(vim.fn.fnamemodify(f, ":t:r"), "\n") end' \
  +qa 2>/dev/null | sort -u); then
  echo "error: failed to query bundled parsers from $NVIM_BIN" >&2
  exit 1
fi

moved=0
moved_langs=""
backup_dir=""

for lang in $bundled; do
  # nvim-treesitter names parsers "<lang>.so" (or .dylib/.dll on some platforms).
  for src in "$TS_PARSER_DIR/$lang".*; do
    [ -e "$src" ] || continue

    if [ "$dry_run" -eq 1 ]; then
      echo "would move: $src"
      moved=$((moved + 1))
      continue
    fi

    if [ -z "$backup_dir" ]; then
      mkdir -p "$BACKUP_ROOT"
      backup_dir=$(mktemp -d "$BACKUP_ROOT/$(date +%Y%m%d-%H%M%S).XXXXXX")
    fi

    mv "$src" "$backup_dir/"
    echo "moved: $src -> $backup_dir/"
    case " $moved_langs " in
      *" $lang "*) ;;
      *) moved_langs="$moved_langs $lang" ;;
    esac
    moved=$((moved + 1))
  done
done

if [ "$moved" -eq 0 ]; then
  echo "nothing to clean: no bundled-language parsers in $TS_PARSER_DIR"
  exit 0
fi

if [ "$dry_run" -eq 1 ]; then
  echo "dry-run: $moved file(s) would be moved; nothing changed"
  exit 0
fi

echo "backup: $backup_dir"
echo "moved $moved file(s)"

# Verify that the bundled parsers can still parse the highlight queries.
verify_failed=0
if [ -n "${moved_langs// /}" ]; then
  verify_out=$(VERIFY_LANGS="$moved_langs" "$NVIM_BIN" --headless \
    +'lua for lang in (vim.env.VERIFY_LANGS or ""):gmatch("%S+") do local ok, err = pcall(vim.treesitter.query.get, lang, "highlights"); if ok then print("verify ok: " .. lang) else print("verify FAILED: " .. lang .. ": " .. tostring(err)) end end' \
    +qa 2>&1) || true

  echo "$verify_out" | grep -E '^verify ' || true
  if echo "$verify_out" | grep -q '^verify FAILED'; then
    verify_failed=1
  fi
fi

if [ "$verify_failed" -eq 1 ]; then
  echo "error: query verification failed; restore from $backup_dir and inspect" >&2
  exit 1
fi
