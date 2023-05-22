#########################################################################
# common include file for application Makefiles
#
# Makefile Common Usage:
# > make
# > make install
# > make remove
#
# Important Notes:
# To use the "install" and "remove" targets to install your
# application directly from the shell, you must do the following:
#
# 1) Make sure that you have the curl command line executable in your path
# 2) Set the variable ROKU_DEV_TARGET in your environment to the IP
#    address of your Roku box. (e.g. export ROKU_DEV_TARGET=192.168.1.1.
#    Set in your this variable in your shell startup (e.g. .bashrc)
# 3) Set the variable ROKU_DEV_PASSWORD in your environment for the password
#    associated with the rokudev account.
##########################################################################

BRANDING_ROOT = https://raw.githubusercontent.com/jellyfin/jellyfin-ux/master/branding/SVG
ICON_SOURCE = icon-transparent.svg
BANNER_SOURCE = banner-dark.svg
OUTPUT_DIR = ./images

# Locales supported by Roku
SUPPORTED_LOCALES = en_US en_GB fr_CA es_ES de_DE it_IT pt_BR

ifdef ROKU_DEV_PASSWORD
    USERPASS = rokudev:$(ROKU_DEV_PASSWORD)
else
    USERPASS = rokudev
endif

HTTPSTATUS = $(shell curl --silent --write-out "\n%{http_code}\n" $(ROKU_DEV_TARGET))

ifeq "$(HTTPSTATUS)" " 401"
	CURLCMD = curl -S --tcp-fastopen --connect-timeout 2 --max-time 30 --retry 5
else
	CURLCMD = curl -S --tcp-fastopen --connect-timeout 2 --max-time 30 --retry 5 --user $(USERPASS) --digest
endif

home:
	@echo "Forcing roku to main menu screen $(ROKU_DEV_TARGET)..."
	curl -s -S -d '' http://$(ROKU_DEV_TARGET):8060/keypress/home
	sleep 2

bsc:
	@bsc

prep_commit:
	npm run format
	npm ci
	npm run validate
	npm run check-formatting

install: bsc home
	@echo "Installing $(APPNAME) to host $(ROKU_DEV_TARGET)"
	@$(CURLCMD) --user $(USERPASS) --digest -F "mysubmit=Install" -F "archive=@out/jellyfin-roku.zip" -F "passwd=" http://$(ROKU_DEV_TARGET)/plugin_install | grep "<font color" | sed "s/<font color=\"red\">//" | sed "s[</font>[["

remove:
	@echo "Removing $(APPNAME) from host $(ROKU_DEV_TARGET)"
	@if [ "$(HTTPSTATUS)" == " 401" ]; \
	then \
		$(CURLCMD) --user $(USERPASS) --digest -F "mysubmit=Delete" -F "archive=" -F "passwd=" http://$(ROKU_DEV_TARGET)/plugin_install | grep "<font color" | sed "s/<font color=\"red\">//" | sed "s[</font>[[" ; \
	else \
		curl -s -S -F "mysubmit=Delete" -F "archive=" -F "passwd=" http://$(ROKU_DEV_TARGET)/plugin_install | grep "<font color" | sed "s/<font color=\"red\">//" | sed "s[</font>[[" ; \
	fi




