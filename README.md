# debugging
- debug.yml
  use this to test stuff quickly

- core  
  comment most of the programs installed in the base-devel role, so it speeds up
  
# TODO
add (/etc/default/keyboard file)

XKBMODEL=pc105
XKBLAYOUT=latam
XKBVARIANT=colemak
XKBOPTIONS=caps:escape
BACKSPACE=guess


add picom from source
https://github.com/yshui/picom/releases/tag/v9.1

#--

install the libgra library patch
don't forget to run ldconfig after it ends to refresh the cache!!

xmobar do
sudo apt install libasound2-dev libxpm-dev
cabal install xmobar --flags="all_extensions"
apt-get install trayer xscreensaver autorandr pavucontrol dunst shellcheck
apt-get install feh xfce4-power-manager

xmonad
can't stow stack.yaml so make sure you either generate it or, add this line
system-ghc: true

install xft_bgra

