
# Stow
With [Stow](https://www.gnu.org/software/stow/) you can easly manage your Dotfiles. You just need to move to your dotfiles directory. Stow will create symlink for every directory you want with the following command. 
```bash
  stow -v pywall 
```

# Pywal
Pywal automatically can create you a color scheme based on your Wallpaper. I`ve made the costum script config-colors.sh to also update Thundrbird and Brave. For Thunderbird(and Firefox) you will need Pywalfox and for any chromium Browser you can create a theme, which can be imported a Chrome-Extension. For testing and tweaking I also use [wpg](https://github.com/deviantfero/wpgtk). But for me it is currently not perfect, mainly because I don't understand GTK theming.

# Waybar
For my Bar I use Waybar with some CSS Tweaks. The colors are given by pywal.

# Active Window Tracker and Blocker

This project is build for Hyprland. It notes the time you spend on each program. It only counts the active window. If the active window is the browser Brave it notes the URL you are on. There is also a blocked-sites list. So if you are on a tab the program will close the tab if the URL is on these list.
You can find the script in the folder bash. I activate it in my hyprland.conf.


## Author

- [@mxmln-wysk](https://www.github.com/mxmln-wysk)

