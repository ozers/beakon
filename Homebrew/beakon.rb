cask "beakon" do
  version "1.0.0"
  sha256 :no_check # Update with actual SHA after release

  url "https://github.com/ozers/beakon/releases/download/v#{version}/Beakon.dmg"
  name "Beakon"
  desc "AI usage tracker & prompt vault for your macOS menu bar"
  homepage "https://github.com/ozers/beakon"

  depends_on macos: ">= :sonoma"

  app "Beakon.app"

  zap trash: [
    "~/Library/Application Support/Beakon",
    "~/Library/Preferences/com.ozersubasi.Beakon.plist",
    "~/Library/Caches/com.ozersubasi.Beakon",
  ]
end
