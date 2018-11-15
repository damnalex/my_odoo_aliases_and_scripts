##############################################
############  personnal stuffs  ##############
##############################################

maj(){
	sudo apt-get update && 
	sudo apt-get upgrade -y && 
	sudo apt-get autoclean && 
	sudo apt-get autoremove -y
}

fullmaj(){
	sudo apt-get update &&
	sudo apt-get upgrade -y &&
	sudo apt-get dist-upgrade -y &&
	sudo apt-get autoclean &&
	sudo apt-get autoremove -y
}

alias reload_zshrc='source ~/.zshrc'

alias cya='systemctl suspend -i'

clear_ram(){
	echo "This is going to take a while ..." && 
	echo "Droppping cache" && 
	sudo su -c "echo 3 > /proc/sys/vm/drop_caches" root && 
	echo "Cache dropped" && 
	echo "turning swap off" && 
	sudo swapoff -a && 
	echo "turning swap back on" && 
	sudo swapon -a && 
	echo "Aaaaaand... done!" 
}

noweb(){
        sg no_web $@[1,-1]
}
alias ni='noweb'


#############################################
#############  zsh stuffs  ##################
#############################################

DEFAULT_USER='odoo'

alias e="vim"

eza(){
	e $AP/odoo_alias.sh && 
	reload_zshrc
}

geza(){
	gedit $AP/zsh_alias.sh &&
	reload_zshrc
}

#history analytics
history_count(){
	history -n | cut -d' ' -f1 | sort | uniq -c | trim | sort -g | tac | less
}
trim(){
	awk '{$1=$1};1'
}

