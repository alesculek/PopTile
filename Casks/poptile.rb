cask "poptile" do
  version "0.5.1"
  sha256 "7a978b4a90d1a44583ea48c3f64edbd994afd1b9918a16e898fc680da10e657b"

  url "https://github.com/alesculek/PopTile/releases/download/v#{version}/PopTile-v#{version}-macos-arm64.zip"
  name "PopTile"
  desc "Auto-tiling window manager for macOS (pop-shell port)"
  homepage "https://github.com/alesculek/PopTile"

  depends_on macos: ">= :sonoma"
  depends_on arch: :arm64

  app "PopTile.app"

  postflight do
    # Remove quarantine so the ad-hoc signed app can launch without Gatekeeper prompt
    system_command "/usr/bin/xattr",
                   args: ["-cr", "#{appdir}/PopTile.app"],
                   sudo: false
  end

  zap trash: [
    "~/Library/Preferences/com.poptile.PopTile.plist",
  ]

  caveats <<~EOS
    PopTile requires Accessibility permission to manage windows.
    On first launch, grant access in:
      System Settings → Privacy & Security → Accessibility

    For the best experience, enable Dock auto-hide:
      defaults write com.apple.dock autohide -bool true && killall Dock
  EOS
end
