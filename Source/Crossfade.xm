#import <Foundation/Foundation.h>
#import <AVFoundation/AVFoundation.h>
#import <objc/runtime.h>
#import "Headers/YTPlayerViewController.h"
#import "Headers/YTMNowPlayingViewController.h"
#import "Headers/YTMWatchViewController.h"

// MARK: - Settings helpers

static BOOL YTMU(NSString *key) {
    NSDictionary *YTMUltimateDict = [[NSUserDefaults standardUserDefaults] dictionaryForKey:@"YTMUltimate"];
    return [YTMUltimateDict[key] boolValue];
}

static int YTMUint(NSString *key) {
    NSDictionary *YTMUltimateDict = [[NSUserDefaults standardUserDefaults] dictionaryForKey:@"YTMUltimate"];
    NSInteger val = [YTMUltimateDict[key] integerValue];
    return (val > 0 ? val : 5); // fallback to 5 seconds if not set
}

// MARK: - Associated object keys

static void *kCrossfadeActiveKey = &kCrossfadeActiveKey;
static void *kLastVideoIDKey = &kLastVideoIDKey;

// MARK: - Category forward declarations

@interface YTPlayerViewController (Crossfade)
@property (nonatomic, assign) BOOL crossfadeActive;
@property (nonatomic, copy) NSString *lastVideoID;
- (void)tryCrossfade;
- (void)applyFadeOutWithDuration:(CGFloat)duration;
@end

// MARK: - Hook

%hook YTPlayerViewController

// ========== Property Implementations ==========

%new
- (BOOL)crossfadeActive {
    NSNumber *value = objc_getAssociatedObject(self, kCrossfadeActiveKey);
    return [value boolValue];
}

%new
- (void)setCrossfadeActive:(BOOL)crossfadeActive {
    objc_setAssociatedObject(self, kCrossfadeActiveKey, @(crossfadeActive), OBJC_ASSOCIATION_RETAIN_NONATOMIC);
}

%new
- (NSString *)lastVideoID {
    return objc_getAssociatedObject(self, kLastVideoIDKey);
}

%new
- (void)setLastVideoID:(NSString *)lastVideoID {
    objc_setAssociatedObject(self, kLastVideoIDKey, lastVideoID, OBJC_ASSOCIATION_COPY_NONATOMIC);
}

// ========== Hooked methods ==========

- (void)setPlayerResponse:(id)playerResponse {
    %orig;

    if (!YTMU(@"YTMUltimateIsEnabled")) return;

    if (YTMU(@"crossfadeEnabled") && self.playerResponse.playerData.videoDetails.title) {
        if (![self.lastVideoID isEqualToString:self.contentVideoID]) {
            self.crossfadeActive = NO;
            self.lastVideoID = self.contentVideoID;
        }
    }
}

// Hooks that fire repeatedly with playback progress
- (void)singleVideo:(id)video currentVideoTimeDidChange:(id)time {
    %orig;
    [self tryCrossfade];
}

- (void)potentiallyMutatedSingleVideo:(id)video currentVideoTimeDidChange:(id)time {
    %orig;
    [self tryCrossfade];
}

// ========== New helper logic ==========

%new
- (void)tryCrossfade {
    if (!YTMU(@"crossfadeEnabled")) return;

    CGFloat total = self.currentVideoTotalMediaTime;
    CGFloat current = self.currentVideoMediaTime;
    NSInteger fadeSeconds = YTMUint(@"crossfadeSeconds");

    if (total <= 0 || fadeSeconds <= 0) return;

    // Trigger only once per track
    if (!self.crossfadeActive && (total - current) <= fadeSeconds) {
        self.crossfadeActive = YES;

        // Fade out the current audio
        [self applyFadeOutWithDuration:(CGFloat)fadeSeconds];

        // Grab parent watch VC
        UIViewController *parentVC = self.parentViewController;
        if (![parentVC isKindOfClass:[%c(YTMWatchViewController) class]]) return;

        YTMWatchViewController *watchVC = (YTMWatchViewController *)parentVC;
        id nowPlayingVC = [watchVC valueForKey:@"_nowPlayingViewController"];

        if (nowPlayingVC && [nowPlayingVC respondsToSelector:@selector(didTapNextButton)]) {
            // Schedule a smooth transition to next
            dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)((fadeSeconds / 2.0) * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
                [nowPlayingVC didTapNextButton];
            });
        }
    }
}

// Apply fade-out to player volume if accessible
%new
- (void)applyFadeOutWithDuration:(CGFloat)duration {
    id player = [self valueForKey:@"_player"];
    if (![player respondsToSelector:@selector(volume)]) return;

    CGFloat step = 0.05;
    CGFloat interval = duration * step;
    __block CGFloat volume = [[player valueForKey:@"volume"] floatValue];

    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
        while (volume > 0.0) {
            volume -= step;
            if (volume < 0.0) volume = 0.0;
            dispatch_async(dispatch_get_main_queue(), ^{
                [player setValue:@(volume) forKey:@"volume"];
            });
            [NSThread sleepForTimeInterval:interval];
        }
    });
}

%end

// MARK: - Constructor (initialize defaults)

%ctor {
    NSMutableDictionary *dict = [NSMutableDictionary dictionaryWithDictionary:[[NSUserDefaults standardUserDefaults] dictionaryForKey:@"YTMUltimate"]];

    if (dict[@"crossfadeEnabled"] == nil) {
        dict[@"crossfadeEnabled"] = @(NO);
    }

    if (dict[@"crossfadeSeconds"] == nil) {
        dict[@"crossfadeSeconds"] = @(5);
    }

    [[NSUserDefaults standardUserDefaults] setObject:dict forKey:@"YTMUltimate"];
}
