#
# ~/.bashrc
#
# If not running interactively, don't do anything
[[ $- != *i* ]] && return




#alias
alias ..="cd ..";
alias cdn="cd ~/nix-conf/";
alias update="sudo nix flake update";
alias switch="sudo nixos-rebuild switch --flake";
alias remove="sudo nix-collect-garbage -d";
alias generations="sudo nix-env -p /nix/var/nix/profiles/system --list-generations";
alias list="nix-store --query --requisites /run/current-system | cut -d- -f2- | sort | uniq";
alias repair5="sudo ntfsfix -d  /dev/sdb5";
alias repair4="sudo ntfsfix -d  /dev/sdb4";
alias repair1="sudo ntfsfix -d  /dev/sdb1";


#prompt
source ~/.bashScripts/git-prompt.sh
PS1='[\[$(tput bold)\]';
PS1+='\[$(tput setaf 214)\]\u'; #user orange
PS1+='\[$(tput setaf 112)\]@\h'; #host green
PS1+='\[$(tput setaf 75)\] \W'; #directinary blue
PS1+='\[$(tput setaf 220)\]\[$(__git_ps1 " {%s}")\]';
PS1+='\[$(tput sgr0)\]] => '; #else white


