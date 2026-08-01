#!/usr/bin/env bash
# Usage: sync-checksums.sh <depName> <newVersion>
#
# Reads images/*/image.yaml for checksums blocks matching <depName>,
# fetches and parses upstream checksums, writes them to buildArgs and Dockerfile ARGs.

set -o errexit -o nounset -o pipefail

dep_name="${1:?depName required (e.g. actions/runner)}"
new_version="${2:?newVersion required (e.g. v2.336.0)}"
pkg_version="${new_version#v}"

release_body=$(gh release view "${new_version}" --repo "${dep_name}" --json body --jq '.body')
if [ -z "$release_body" ]; then
  echo "::error::Failed to fetch release body for ${dep_name} @ ${new_version}" >&2
  exit 1
fi

checksums_section=$(sed --quiet '/^## SHA-256 Checksums/,/^## /p' <<< "$release_body" | grep --invert-match '^## ')

declare -A lookup_body
while IFS= read -r line; do
  line="${line#- }"
  filename="${line%% *}"
  hash="${line##* }"
  if [ -n "$filename" ] && [ -n "$hash" ] && [ "${#hash}" -eq 64 ]; then
    lookup_body["$filename"]="$hash"
  fi
done < <(grep --extended-regexp '^- [^[:space:]]+\.(tar\.gz|tar\.xz|tar\.bz2|zip) [0-9a-f]{64}$' <<< "$checksums_section")

changed=0
while IFS= read -r config; do
  image_dir=$(dirname "$config")
  image_name=$(basename "$image_dir")

  block_count=$(yq '.checksums | length' "$config")
  for ((b = 0; b < block_count; b++)); do
    cfg_upstream=$(yq --unwrapScalar ".checksums[${b}].upstream // \"\"" "$config")
    [ "$cfg_upstream" = "$dep_name" ] || continue

    source_type=$(yq --unwrapScalar ".checksums[${b}].source // \"body\"" "$config")

    declare -A lookup

    case "$source_type" in
      body)
        if [ -z "${checksums_section:-}" ] || [ "${#lookup_body[@]}" -eq 0 ]; then
          echo "::error file=${config}::No '## SHA-256 Checksums' section found in release body for ${dep_name} @ ${new_version}" >&2
          exit 1
        fi
        for key in "${!lookup_body[@]}"; do
          lookup["$key"]="${lookup_body[$key]}"
        done
        ;;
      checksums_file)
        checksums_file_template=$(yq --unwrapScalar ".checksums[${b}].checksums_file" "$config")
        if [ -z "$checksums_file_template" ]; then
          echo "::error file=${config}::checksums_file is required when source=checksums_file" >&2
          exit 1
        fi
        checksums_filename="${checksums_file_template//\{version\}/$pkg_version}"
        if ! checksums_content=$(gh release download "${new_version}" --repo "${dep_name}" --pattern "${checksums_filename}" --output - 2> /dev/null); then
          echo "::error::Failed to download checksums file '${checksums_filename}' from ${dep_name} @ ${new_version}" >&2
          exit 1
        fi

        while IFS= read -r line; do
          hash="${line%%  *}"
          filename="${line##*  }"
          if [ -n "$hash" ] && [ -n "$filename" ] && [ "${#hash}" -eq 64 ]; then
            case "$filename" in
              *.tar.gz | *.tar.xz | *.tar.bz2 | *.zip)
                lookup["$filename"]="$hash"
                ;;
            esac
          fi
        done <<< "$checksums_content"

        if [ "${#lookup[@]}" -eq 0 ]; then
          echo "::error file=${config}::No checksums parsed from '${checksums_filename}' for ${dep_name} @ ${new_version}" >&2
          exit 1
        fi
        ;;
      *)
        echo "::error file=${config}::unsupported checksums source '${source_type}' (must be 'body' or 'checksums_file')" >&2
        exit 1
        ;;
    esac

    asset_count=$(yq ".checksums[${b}].assets | length" "$config")
    for ((i = 0; i < asset_count; i++)); do
      pattern=$(yq --unwrapScalar ".checksums[${b}].assets[${i}].pattern" "$config")
      arg_name=$(yq --unwrapScalar ".checksums[${b}].assets[${i}].arg" "$config")
      update_dockerfile=$(yq --unwrapScalar ".checksums[${b}].assets[${i}].dockerfile // \"false\"" "$config")

      platforms=$(yq '.buildArgs | keys | .[]' "$config")
      for platform in $platforms; do
        arch_token=$(yq --unwrapScalar ".checksums[${b}].assets[${i}].arch_map[\"${platform}\"] // \"${platform}\"" "$config")

        expected="${pattern//\{arch\}/$arch_token}"
        expected="${expected//\{version\}/$pkg_version}"

        sha256="${lookup[$expected]:-}"
        if [ -z "$sha256" ]; then
          echo "::error file=${config}::checksum not found for asset '${expected}' (platform=${platform})" >&2
          printf 'Available: %s\n' "${!lookup[@]}"
          exit 1
        fi

        current=$(yq --unwrapScalar ".buildArgs.${platform}.${arg_name}" "$config")
        if [ "$current" = "$sha256" ]; then
          echo "${image_name}: buildArgs.${platform}.${arg_name} unchanged"
        else
          yq --inplace ".buildArgs.${platform}.${arg_name} = \"${sha256}\"" "$config"
          echo "${image_name}: buildArgs.${platform}.${arg_name} → ${sha256}"
          changed=$((changed + 1))
        fi
      done

      if [ "$update_dockerfile" = "true" ]; then
        dockerfile="${image_dir}/Dockerfile"
        amd64_arch=$(yq --unwrapScalar ".checksums[${b}].assets[${i}].arch_map.amd64 // \"amd64\"" "$config")
        expected="${pattern//\{arch\}/$amd64_arch}"
        expected="${expected//\{version\}/$pkg_version}"
        sha256="${lookup[$expected]:-}"
        if [ -z "$sha256" ]; then
          echo "::error file=${config}::checksum not found for asset '${expected}' (Dockerfile default)" >&2
          exit 1
        fi
        current=$(grep --only-matching --perl-regexp "ARG ${arg_name}=\K[0-9a-f]{64}" "$dockerfile" || true)
        if [ "$current" != "$sha256" ]; then
          sed --in-place "s/^ARG ${arg_name}=[0-9a-f]\{64\}$/ARG ${arg_name}=${sha256}/" "$dockerfile"
          echo "${image_name}: Dockerfile ARG ${arg_name} → ${sha256}"
          changed=$((changed + 1))
        fi
      fi
    done
  done
done < <(find images -mindepth 2 -maxdepth 2 -name image.yaml -type f | sort)

if [ "$changed" -eq 0 ]; then
  echo "No checksums needed updating"
else
  echo "Updated ${changed} checksums"
fi
