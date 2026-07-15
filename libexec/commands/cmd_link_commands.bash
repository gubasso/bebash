# shellcheck shell=bash
: 'desc: Link bebash overlay commands into the executable bindir.'

__bebash_cmd_link_commands_usage() {
  printf 'usage: bebash link-commands [--dry-run] [--prune-only] [--json]\n'
}

__bebash_link_commands_json_array() {
  local first=1 item
  printf '['
  for item in "$@"; do
    ((first)) || printf ','
    first=0
    __bebash_json_string "$item"
  done
  printf ']'
}

__bebash_link_commands_is_reserved() {
  case "$1" in
    bebash | bebash-cmd) return 0 ;;
    *) return 1 ;;
  esac
}

__bebash_link_commands_managed_link() {
  local path=$1 launcher=$2 target
  [[ -L $path ]] || return 1
  target=$(readlink -- "$path") || return 1
  [[ $target != /* ]] && target=$(cd -P -- "$(dirname -- "$path")" && pwd)/$target
  [[ $target == "$launcher" ]]
}

__bebash_link_commands_write_manifest() {
  local manifest=$1 tmp=$2
  LC_ALL=C sort -u -o "$tmp" -- "$tmp"
  mv -- "$tmp" "$manifest"
}

bebash::cmd::link_commands() {
  local dry_run=0 prune_only=0 json=${__BEBASH_GLOBAL[json]}
  while (($#)); do
    case "$1" in
    --dry-run) dry_run=1 ;;
    --prune-only) prune_only=1 ;;
    --json) json=1 ;;
    -h | --help)
      __bebash_cmd_link_commands_usage
      return 0
      ;;
    --)
      shift
      break
      ;;
    -*)
      bebash::die 2 "unknown flag for link-commands: $1"
      return $?
      ;;
    *)
      bebash::die 2 "link-commands takes no arguments"
      return $?
      ;;
    esac
    shift
  done
  (($# == 0)) || {
    bebash::die 2 "link-commands takes no arguments"
    return $?
  }

  local commands_dir=$BEBASH_DATA_DIR/commands
  local bindir=${__BEBASH_BIN_DIR:-}
  local launcher=$bindir/bebash-cmd
  local state_dir manifest tmp_manifest
  local command_path name link tmp_link old_path
  local linked=0 skipped=0 pruned=0
  local -a created=() skipped_items=() pruned_items=()
  local -A desired=()

  [[ -n $bindir ]] || {
    bebash::die 70 "__BEBASH_BIN_DIR is not set"
    return $?
  }
  [[ -x $launcher ]] || {
    bebash::die 70 "bebash-cmd launcher not found: $launcher"
    return $?
  }

  state_dir=$(__bebash_state_dir)
  manifest=$(__bebash_commands_manifest_path)

  if [[ -d $commands_dir ]]; then
    while IFS= read -r command_path; do
      [[ -f $command_path && -x $command_path ]] || continue
      name=${command_path##*/}
      if __bebash_link_commands_is_reserved "$name"; then
        skipped=$((skipped + 1))
        skipped_items+=("$name:reserved")
        continue
      fi
      link=$bindir/$name
      desired["$link"]=1
      [[ $prune_only -eq 1 ]] && continue
      if [[ -e $link || -L $link ]]; then
        if ! __bebash_link_commands_managed_link "$link" "$launcher"; then
          skipped=$((skipped + 1))
          skipped_items+=("$name:exists")
          continue
        fi
      fi
      if ((dry_run)); then
        linked=$((linked + 1))
        created+=("$link")
        continue
      fi
      mkdir -p -- "$bindir"
      tmp_link=$bindir/.$name.bebash-cmd.$$
      rm -f -- "$tmp_link"
      # Atomic shim update: build the symlink under a private temp name, then
      # rename it into place so interrupted runs never leave a partial target.
      ln -s -- "$launcher" "$tmp_link"
      mv -Tf -- "$tmp_link" "$link"
      linked=$((linked + 1))
      created+=("$link")
    done < <(find "$commands_dir" -maxdepth 1 -type f | LC_ALL=C sort)
  fi

  if [[ -e $manifest ]]; then
    while IFS= read -r old_path || [[ -n $old_path ]]; do
      [[ -n $old_path ]] || continue
      [[ -z ${desired[$old_path]:-} ]] || continue
      if __bebash_link_commands_managed_link "$old_path" "$launcher"; then
        if ((dry_run)); then
          pruned=$((pruned + 1))
          pruned_items+=("$old_path")
        else
          rm -f -- "$old_path"
          pruned=$((pruned + 1))
          pruned_items+=("$old_path")
        fi
      fi
    done <"$manifest"
  fi

  if ((!dry_run)); then
    mkdir -p -- "$state_dir"
    tmp_manifest=$(mktemp "$state_dir/commands-manifest.XXXXXX")
    for link in "${!desired[@]}"; do
      __bebash_link_commands_managed_link "$link" "$launcher" || continue
      printf '%s\n' "$link" >>"$tmp_manifest"
    done
    if [[ -s $tmp_manifest ]]; then
      __bebash_link_commands_write_manifest "$manifest" "$tmp_manifest"
    else
      rm -f -- "$tmp_manifest" "$manifest"
    fi
  fi

  if ((json)); then
    printf '{"linked":%s,"skipped":%s,"pruned":%s,"created":' "$linked" "$skipped" "$pruned"
    __bebash_link_commands_json_array "${created[@]}"
    printf ',"skipped_items":'
    __bebash_link_commands_json_array "${skipped_items[@]}"
    printf ',"pruned_items":'
    __bebash_link_commands_json_array "${pruned_items[@]}"
    printf '}\n'
  else
    __bebash_ui_info "linked $linked command shim(s); skipped $skipped; pruned $pruned"
  fi
}
