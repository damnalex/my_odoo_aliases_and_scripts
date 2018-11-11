# alias "noweb" : prefix for executing scripts without allowing outgoing web requests.
#
# Original idea from http://ubuntuforums.org/showthread.php?t=1188099
#
# no warranties use at own risk
# made for zsh, not tested with other shells

# to prepare for the use of this alias/iptable rule combo : 
#  groupadd no_web
#  usermod -a -G no_web $USER

# add a file in /etc/network/if-pre-up.d/ with following content:
# #!/bin/bash'
# iptables -I OUTPUT 1 -m owner --gid-owner no_web -p tcp --dport 80 -j DROP
# iptables -I OUTPUT 1 -m owner --gid-owner no_web -p tcp --dport 443 -j DROP
# don't forget to make it executable

# or execute the following :
#
# (
#     echo '#!/bin/bash'
#     echo 'iptables -I OUTPUT 1 -m owner --gid-owner no_web -p tcp --dport 80 -j DROP'
#     echo 'iptables -I OUTPUT 1 -m owner --gid-owner no_web -p tcp --dport 443 -j DROP'
# ) | make_script /etc/network/if-pre-up.d/iptables_no_web_rule
#

noweb(){
	sg no_web $@[1,-1] 
}
alias ni='noweb'

