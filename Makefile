include theos/makefiles/common.mk

TWEAK_NAME = WeeLoader
WeeLoader_FILES = Tweak.xm

after-stage::
	-@mkdir -p $(THEOS_STAGING_DIR)/Library/WeeLoader/Plugins

include $(THEOS_MAKE_PATH)/tweak.mk
