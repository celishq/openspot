#!/bin/sh
printf 'button=press\ntitle=Open in Visual Studio Code\n\n'
printf 'button=in-2\ntitle=Open in Zed\n\n'
printf 'button=page-1\ntitle=Open on GitHub\n\n'
printf 'button=page-2\ntitle=Open on GitLab\n\n'
printf 'button=reveal\ntitle=Show in Finder\nshortcut=cmd+return\n\n'
printf 'button=terminal\ntitle=Open in Terminal\nshortcut=cmd+t\n\n'
printf 'button=copy\ntitle=Copy path\nshortcut=cmd+shift+c\n\n'
printf 'button=editor\ntitle=Change default app\nscope=spot\n\n'
printf 'button=folder\ntitle=Change folder\nscope=spot\n'
for repo in 'api-gateway:main:github.com/northwind/api-gateway' 'design-tokens:feature/dark-mode:github.com/northwind/design-tokens' 'dotfiles:main:' 'invoice-cli:fix/rounding:gitlab.com/maple/invoice-cli' 'mobile-app:release/2.4:github.com/northwind/mobile-app' 'notes-site:main:gitlab.com/maple/notes-site'; do
  name=${repo%%:*}
  rest=${repo#*:}
  page=${rest#*:}
  path=/Users/you/Developer/$name
  printf '\nitem=%s\ntitle=%s\ndetail=%s\nicon=%s\n' "$path" "$name" "${rest%%:*}" "$path"
  case "$page" in
    github.com/*) printf 'page=https://%s\nhides=page-2\n' "$page" ;;
    gitlab.com/*) printf 'page=https://%s\nhides=page-1\n' "$page" ;;
    *) printf 'hides=page-1\nhides=page-2\n' ;;
  esac
done
