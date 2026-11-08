#!/bin/zsh
# Per-Mac settings that Migration Assistant doesn't copy. Re-run on each new Mac, then log out and back in.

# Menu bar: item spacing, hidden Spotlight icon, and which Control Center items show
defaults -currentHost write -globalDomain NSStatusItemSpacing -int 8
defaults -currentHost write com.apple.Spotlight MenuItemHidden -bool true
defaults -currentHost write com.apple.controlcenter BatteryShowPercentage -bool false
defaults -currentHost write com.apple.controlcenter ShowSuggestions -bool true
for key value in AccessibilityShortcuts 12 BatteryShowEnergyMode 0 Display 8 KeyboardBrightness 12 \
                 NowPlaying 8 Siri 8 Sound 2 StageManager 18 VoiceControl 8 Weather 2 WiFi 2; do
  defaults -currentHost write com.apple.controlcenter $key -int $value
done

# Liquid Glass tint (System Settings → Appearance)
defaults write -globalDomain NSGlassTintAmount -float 0.85

killall ControlCenter SystemUIServer 2>/dev/null
print 'Done. Log out and back in so every app picks up the spacing and tint.'
