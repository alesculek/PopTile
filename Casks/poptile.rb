cask "poptile" do
  version "0.5.1"
  sha256 "8b34db6182874c2b7338a5e526a32871a16777ec32a2173886c07ee95e52ced5"

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
    # Re-sign with "PopTile Dev" cert if available in login keychain.
    # This preserves TCC accessibility permissions across reinstalls
    # (ad-hoc signatures change every build, causing TCC to revoke access).
    # For users without the cert, the ad-hoc signature still works — they
    # just need to re-grant accessibility permission after each update.
    system_command "/usr/bin/codesign",
                   args: ["--force", "--deep", "--sign", "PopTile Dev", "#{appdir}/PopTile.app"],
                   sudo: false,
                   must_succeed: false
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
