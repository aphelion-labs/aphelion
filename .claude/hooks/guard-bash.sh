#!/usr/bin/env bash
# PreToolUse (Bash): denies git hook bypasses (ADR 0005), shell writes into living specs (ADR 0004), force pushes without a lease (ADR 0005) and pushes to main (ADR 0010). A match over command text is a guard, not a sandbox (ADR 0005).
set -u

if ! command -v jq >/dev/null 2>&1; then
  # Fail closed: without jq this guard cannot read the tool call.
  echo "guard-bash: jq is required by this repository's Claude Code hooks; install jq" >&2
  exit 2
fi

deny() {
  jq -n --arg r "$1" '{hookSpecificOutput: {hookEventName: "PreToolUse", permissionDecision: "deny", permissionDecisionReason: $r}}'
  exit 0
}

input=$(cat)
cmd=$(printf '%s' "$input" | jq -r '.tool_input.command // ""')
cwd=$(printf '%s' "$input" | jq -r '.cwd // ""')

reason_verify="Skipping git hooks is not allowed (ADR 0005): no --no-verify, no -n on git commit or git push. Fix what the hook reports. If pre-push refused because main changed the same files: git fetch origin && git rebase origin/main, resolve, re-test, then git push --force-with-lease. This check matches the whole command text, so file content passed through a shell heredoc also trips it; write such files with the Write tool."
reason_hookspath="core.hooksPath must stay .githooks (ADR 0005); scripts/setup-hooks.sh sets it and prints it. Commands that mention core.hooksPath are denied. This check matches the whole command text, so file content passed through a shell heredoc also trips it; write such files with the Write tool."
reason_specs="Living specs under openspec/specs/ change only through 'openspec archive' of a change folder in the same PR (ADR 0004). Write a delta spec in openspec/changes/<issue>-<slug>/ instead, for example with /aphelion-sdlc:issue-propose. This check matches the whole command text, so file content passed through a shell heredoc also trips it; write such files with the Write tool."
reason_force="Force pushes without a lease are not allowed. After a rebase use git push --force-with-lease, without --force, -f or a +refspec: git's docs say --force disables the lease check (ADR 0005)."
reason_main="Pushing to main is not allowed. main changes only through a squash-merged PR that the owner merges (ADR 0010). Push your ticket branch <issue>-<slug> and open a PR."

# Whole-command checks.
case "$cmd" in *--no-verify*) deny "$reason_verify" ;; esac
if printf '%s' "$cmd" | grep -qi 'core\.hookspath'; then deny "$reason_hookspath"; fi
# Redirection into openspec/specs/: >, >>, >|, 2>, &> followed by a path with that segment.
if printf '%s' "$cmd" | grep -Eq ">[>|]?[[:space:]]*[\"']?([^[:space:]\"';&|<>]*/)?openspec/specs(/|[[:space:]\"';&|)]|$)"; then
  deny "$reason_specs"
fi

is_spec_path() { [[ "$1" =~ (^|[/=])openspec/specs(/|$) ]]; }

current_branch() { git -C "${cwd:-.}" symbolic-ref --short -q HEAD 2>/dev/null; }

# Split into simple commands on ; && || | & ( ) ` $( and newlines.
s=$cmd
for sep in "\$(" '&&' '||' ';' '|' '&' '(' ')' '`'; do
  s=${s//"$sep"/$'\n'}
done

while IFS= read -r seg; do
  read -r -a raw <<<"$seg" || true
  toks=()
  for t in ${raw[@]+"${raw[@]}"}; do
    t=${t//\"/}
    t=${t//\'/}
    toks+=("$t")
  done
  # Drop leading VAR=value assignments and the wrappers sudo, env and command.
  while [ ${#toks[@]} -gt 0 ]; do
    case "${toks[0]}" in
      sudo | env | command) ;;
      *=*) [[ "${toks[0]}" =~ ^[A-Za-z_][A-Za-z0-9_]*= ]] || break ;;
      *) break ;;
    esac
    toks=(${toks[@]+"${toks[@]:1}"})
  done
  [ ${#toks[@]} -eq 0 ] && continue
  name=${toks[0]##*/}
  args=(${toks[@]+"${toks[@]:1}"})

  case "$name" in
    rm | mv | tee)
      for a in ${args[@]+"${args[@]}"}; do is_spec_path "$a" && deny "$reason_specs"; done
      ;;
    sed)
      inplace=0
      for a in ${args[@]+"${args[@]}"}; do
        [[ "$a" =~ ^(--in-place|-[A-Za-z]*i) ]] && inplace=1
      done
      if [ "$inplace" -eq 1 ]; then
        for a in ${args[@]+"${args[@]}"}; do is_spec_path "$a" && deny "$reason_specs"; done
      fi
      ;;
    cp)
      # The destination is the -t/--target-directory value, else the last operand.
      dest=""
      last=""
      i=0
      while [ "$i" -lt ${#args[@]} ]; do
        a=${args[$i]}
        case "$a" in
          -t) i=$((i + 1)); dest=${args[$i]:-} ;;
          --target-directory=*) dest=${a#*=} ;;
          -*) ;;
          *) last=$a ;;
        esac
        i=$((i + 1))
      done
      [ -n "$dest" ] || dest=$last
      is_spec_path "$dest" && deny "$reason_specs"
      ;;
    git)
      # Find the subcommand after git's global options (-C <dir>, -c <k=v>).
      i=0
      sub=""
      while [ "$i" -lt ${#args[@]} ]; do
        a=${args[$i]}
        case "$a" in
          -C | -c | --git-dir | --work-tree) i=$((i + 1)) ;;
          -*) ;;
          *) sub=$a; break ;;
        esac
        i=$((i + 1))
      done
      rest=(${args[@]+"${args[@]:$((i + 1))}"})
      case "$sub" in
        commit)
          for a in ${rest[@]+"${rest[@]}"}; do
            [[ "$a" =~ ^-[A-Za-z]*n[A-Za-z]*$ ]] && deny "$reason_verify"
          done
          ;;
        push)
          positional=()
          skip_next=0
          for a in ${rest[@]+"${rest[@]}"}; do
            if [ "$skip_next" -eq 1 ]; then skip_next=0; continue; fi
            case "$a" in
              --force | --force=*) deny "$reason_force" ;;
              --force-with-lease* | --force-if-includes) ;;
              --all | --mirror) deny "$reason_main" ;;
              -o | --push-option | --repo | --receive-pack | --exec) skip_next=1 ;;
              --*) ;;
              -*)
                [[ "$a" =~ ^-[A-Za-z]*n ]] && deny "$reason_verify"
                [[ "$a" =~ ^-[A-Za-z]*f ]] && deny "$reason_force"
                ;;
              *) positional+=("$a") ;;
            esac
          done
          # positional[0] is the remote; the rest are refspecs.
          if [ ${#positional[@]} -le 1 ]; then
            [ "$(current_branch)" = "main" ] && deny "$reason_main"
          else
            for r in "${positional[@]:1}"; do
              case "$r" in +*) deny "$reason_force" ;; esac
              dst=${r##*:}
              case "$dst" in
                main | refs/heads/main) deny "$reason_main" ;;
                HEAD | @) [ "$(current_branch)" = "main" ] && deny "$reason_main" ;;
              esac
            done
          fi
          ;;
      esac
      ;;
  esac
done <<<"$s"

exit 0
