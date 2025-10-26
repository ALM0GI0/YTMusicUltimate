#include "GSVolBar.h"
#import <objc/runtime.h> // ADDED: Required for associated objects

static BOOL YTMU(NSString *key) {
    NSDictionary *YTMUltimateDict = [[NSUserDefaults standardUserDefaults] dictionaryForKey:@"YTMUltimate"];
    return [YTMUltimateDict[key] boolValue];
}

static BOOL volumeBar = YTMU(@"YTMUltimateIsEnabled") && YTMU(@"volBar");

@interface YTMWatchView: UIView
@property (readonly, nonatomic) BOOL isExpanded;
@property (nonatomic, strong) UIView *tabView;
@property (nonatomic) long long currentLayout;
@property (nonatomic, strong) GSVolBar *volumeBar; // Keep this declaration for the compiler

- (void)updateVolBarVisibility;
@end

// Define a static key for associated objects
static void *kVolumeBarKey = &kVolumeBarKey;

%hook YTMWatchView

// REMOVED: %property (nonatomic, strong) GSVolBar *volumeBar;

// ADDED: Manual getter implementation using associated objects
%new
- (GSVolBar *)volumeBar {
    return objc_getAssociatedObject(self, kVolumeBarKey);
}

// ADDED: Manual setter implementation using associated objects
%new
- (void)setVolumeBar:(GSVolBar *)volumeBar {
    objc_setAssociatedObject(self, kVolumeBarKey, volumeBar, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
}


- (instancetype)initWithColorScheme:(id)scheme {
    self = %orig;

    if (self && volumeBar) {
        self.volumeBar = [[GSVolBar alloc] initWithFrame:CGRectMake(self.frame.size.width / 2 - (self.frame.size.width / 2) / 2, 0, self.frame.size.width / 2, 25)];

        [self addSubview:self.volumeBar];
    }

    return self;
}

- (void)layoutSubviews {
    %orig;

    if (volumeBar) {
        self.volumeBar.frame = CGRectMake(self.frame.size.width / 2 - (self.frame.size.width / 2) / 2, CGRectGetMinY(self.tabView.frame) - 25, self.frame.size.width / 2, 25);
    }
}

- (void)updateColorsAfterLayoutChangeTo:(long long)arg1 {
    %orig;

    if (volumeBar) {
        [self updateVolBarVisibility];
    }
}

- (void)updateColorsBeforeLayoutChangeTo:(long long)arg1 {
    %orig;

    if (volumeBar) {
        self.volumeBar.hidden = YES;
    }
}

%new
- (void)updateVolBarVisibility {
    if (volumeBar) {
        dispatch_async(dispatch_get_main_queue(), ^(void){
            self.volumeBar.hidden = !(self.isExpanded && self.currentLayout == 2);
        });
    }
}

%end
