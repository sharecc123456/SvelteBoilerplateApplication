#!/usr/bin/env bash
# Author: Akashdeep Nandi <nandi@boilerplate.co>
# Small modifications for Nix by Levente Kurusa <lev@boilerplate.co>
# Copyright 2022 (c) Boilerplate, Inc.

#
# To use: Copy the output from the prettier GH Action.
# e.g. your clipboard should look like this:
#
# [warn] assets/js/ui/components/Form/Question.svelte
# [warn] assets/js/ui/iac/IacFill.svelte
# [warn] assets/js/ui/iac/IacSetup.svelte
# [warn] assets/js/ui/pages/requestor_portal/ChecklistNew.svelte
# [warn] assets/js/ui/pages/requestor_portal/RecipientDetails/components/DataTab.svelte
# [warn] assets/js/ui/pages/requestor_portal/RecipientDetails/index.svelte
#
# Then you can use your platform's pbpaste like this:
# nix-shell:~src/boilerplate/app/assets $ pbpaste | ../tools/bprettier.sh
#
# Note that pbpaste is only available on macOS, other platforms have similar tools.

while IFS='$\n' read -r file; do
  path="$(echo $file | cut -d' ' -f2 | sed 's/assets\///g' )"
  echo Rewriting "$path";
  prettier --write "$path";
done < /dev/stdin
