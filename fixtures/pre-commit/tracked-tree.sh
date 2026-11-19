tracked_tree=$(mktemp -d)
while IFS= read -r -d '' tracked; do
  [ -f "$tracked" ] || continue
  mkdir -p "$tracked_tree/$(dirname "$tracked")"
  cp -- "$tracked" "$tracked_tree/$tracked"
done < <(git ls-files -z)
[ -f "$tracked_tree/flake.nix" ] || { echo "no tracked flake.nix in $PWD" >&2; exit 1; }
