# Use VHS to render this demo GIF: https://github.com/charmbracelet/vhs
# NOTE: Requires 'and-ever.mp4' to exist in the current directory!
#       Download it manually or use 'render_demo.sh'.

Output lum1fy.gif

Require echo
Require ffmpeg


## -- set theme -- ##
Set Shell "zsh"
Set FontSize 20
Set Width 1040
Set Height 460
Set Padding 20
Set FontFamily "JetBrainsMono Nerd Font"
Set Theme "Catppuccin Mocha"
Set PlaybackSpeed 4.0


## -- set lum1fy alias -- ##
Hide
Type "alias lum1fy='../../lum1fy.sh'"
Enter
Type 'clear'
Enter
Show


## -- convert the video -- ##
Type@150ms "lum1fy -y --discord free --speed 6 and-ever.mp4"
Sleep 1s
Enter
Sleep 60s
