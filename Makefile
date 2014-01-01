include theos/makefiles/common.mk

TWEAK_NAME = WeeLoader
WeeLoader_FILES = Tweak.x
WeeLoader_PRIVATE_FRAMEWORKS = BulletinBoard SpringBoardUIServices

after-stage::
	-@mkdir -p $(THEOS_STAGING_DIR)/System/Library/WeeAppPlugins
	-@mkdir -p $(THEOS_STAGING_DIR)/System/Library/BulletinBoardPlugins
	-@mkdir -p $(THEOS_STAGING_DIR)/Library/WeeLoader/Plugins
	-@mkdir -p $(THEOS_STAGING_DIR)/Library/WeeLoader/BulletinBoardPlugins

include $(THEOS_MAKE_PATH)/tweak.mk
