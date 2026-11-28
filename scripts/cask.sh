#!/bin/sh
cat <<CASK
cask "openspot" do
  version "$1"
  sha256 "$2"

  url "https://github.com/celishq/openspot/releases/download/v#{version}/Openspot-#{version}.dmg"
  name "Openspot"
  desc "Lightweight launcher, extensible by coding agents"
  homepage "https://github.com/celishq/openspot"

  livecheck do
    url "https://github.com/celishq/openspot/releases/latest/download/appcast.xml"
    strategy :sparkle, &:short_version
  end

  auto_updates true
  depends_on macos: :tahoe

  app "Openspot.app"

  zap trash: "~/.config/openspot"
end
CASK
