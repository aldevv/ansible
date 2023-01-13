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


install the libgra library patch
don't forget to run ldconfig after it ends to refresh the cache!!
dependencies for libgra: 
                        - xutils-dev

# use this guide
https://www.maximilian-schillinger.de/articles/st-libxft-bgra-patch.html
# usar ldconfig solo cuando se alla añadido el library path (donde esta el nuevo archivo .so)
# en un nuevo archivo en /etc/ld.so.conf/mylibs.conf

# luego usar ldconfig
# crear de nuevo st con
# make
# make install
# revisar que se alla usado el correcto en (/usr/lib), utilizando ldd st
# en caso de no querer cambiar el libxft para todos los programas, se puede
# modificar el config.mk de st para que busque la libreria en un path personalizado
# la libreria patcheada

install xft_bgra


# add dwm.desktop
# add stow init so it adds .xprofile
# do sudoers file thing
# create playground
# create playground/code
# create learn
# create projects
# create work
# add backlight logic (create the xorg.conf file, look at your wiki)
