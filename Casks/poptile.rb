cask "poptile" do
  version "0.5.0"
  sha256 "3a2024a7170cf0576dea2341802721e81e2042fb62a78478541df5478557d5bd"

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
