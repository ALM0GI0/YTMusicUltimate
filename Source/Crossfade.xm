#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>
#import <objc/runtime.h>
#import "Headers/Localization.h"

// Macro to read boolean/int values from the settings dict
static BOOL ytmuBool(NSString *key) {
    NSDictionary *YTMUltimateDict = [[NSUserDefaults standardUserDefaults] dictionaryForKey:@"YTMUltimate"];
    return [YTMUltimateDict[key] boolValue];
}
static NSInteger ytmuInt(NSString *key) {
    NSDictionary *YTMUltimateDict = [[NSUserDefaults standardUserDefaults] dictionaryForKey:@"YTMUltimate"];
    return [YTMUltimateDict[key] integerValue];
}

// Associated object keys
static void *kCrossfadeStartedKey = &kCrossfadeStartedKey;
static void *kCrossfadeFaderKey = &kCrossfadeFaderKey;

%ctor {
    // Ensure defaults
    NSMutableDictionary *mutableDict = [NSMutableDictionary dictionaryWithDictionary:[[NSUserDefaults standardUserDefaults] dictionaryForKey:@"YTMUltimate"]];
    if (!mutableDict) mutableDict = [NSMutableDictionary new];
    if (mutableDict[@"crossfadeSeconds"] == nil) {
        [mutableDict setObject:@(5) forKey:@"crossfadeSeconds"];
    }
    [[NSUserDefaults standardUserDefaults] setObject:mutableDict forKey:@"YTMUltimate"];
}

// Helper: attempt to call a selector on object, with zero args.
static BOOL tryPerformSelectorOn(id target, SEL sel) {
    if (!target || !sel) return NO;
    if ([target respondsToSelector:sel]) {
        // use performSelector to avoid compiler warnings
#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Warc-performSelector-leaks"
        [target performSelector:sel];
#pragma clang diagnostic pop
        return YES;
    }
    return NO;
}

// Helper: fade volume linearly over duration using a repeating timer
%new
- (void)startVolumeFadeFrom:(double)start to:(double)end duration:(NSTimeInterval)duration onPlayer:(id)player {
    if (!player) return;
    if (![player respondsToSelector:@selector(setVolume:)]) return;
    
    // If a fader is already running on this controller, cancel it
    NSTimer *existing = objc_getAssociatedObject(self, kCrossfadeFaderKey);
    if (existing && [existing isValid]) {
        [existing invalidate];
    }
    
    __block NSTimeInterval elapsed = 0;
    __block double lastVol = start;
    NSTimeInterval interval = 0.1;
    NSTimeInterval steps = MAX(1, duration / interval);
    double stepAmount = (end - start) / steps;
    
    // set initial
#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Warc-performSelector-leaks"
    [player performSelector:@selector(setVolume:) withObject:@(start)];
#pragma clang diagnostic pop

    __weak typeof(self) weakSelf = self;
    NSTimer *timer = [NSTimer scheduledTimerWithTimeInterval:interval repeats:YES block:^(NSTimer * _Nonnull t) {
        __strong typeof(weakSelf) strongSelf = weakSelf;
        if (!strongSelf) {
            [t invalidate];
            return;
        }
        elapsed += interval;
        lastVol += stepAmount;
        if (elapsed >= duration) {
            // final set
#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Warc-performSelector-leaks"
            [player performSelector:@selector(setVolume:) withObject:@(end)];
#pragma clang diagnostic pop
            [t invalidate];
            objc_setAssociatedObject(strongSelf, kCrossfadeFaderKey, nil, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
            return;
        } else {
#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Warc-performSelector-leaks"
            [player performSelector:@selector(setVolume:) withObject:@(lastVol)];
#pragma clang diagnostic pop
        }
    }];
    objc_setAssociatedObject(self, kCrossfadeFaderKey, timer, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
}

// Primary hook: observe time updates
%hook YTPlayerViewController

// The app updates currentVideoMediaTime frequently; hook setter to detect changes
- (void)setCurrentVideoMediaTime:(double)time {
    %orig;
    
    // read crossfade setting (seconds)
    NSInteger crossfade = ytmuInt(@"crossfadeSeconds");
    if (crossfade <= 0) return;
    
    // avoid crossfade logic if user disabled overall tweak
    NSDictionary *YTMUltimateDict = [[NSUserDefaults standardUserDefaults] dictionaryForKey:@"YTMUltimate"];
    if (!YTMUltimateDict) return;
    
    // Avoid retriggering if we've already started a crossfade for this item
    NSNumber *started = objc_getAssociatedObject(self, kCrossfadeStartedKey);
    if (started && [started boolValue]) {
        return;
    }
    
    // Try to obtain remaining time:
    // The controller may expose a property 'currentVideoMediaDuration' (used by other hooks).
    double duration = 0;
    if ([self respondsToSelector:@selector(currentVideoMediaDuration)]) {
#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Warc-performSelector-leaks"
        id durVal = [self performSelector:@selector(currentVideoMediaDuration)];
#pragma clang diagnostic pop
        if ([durVal respondsToSelector:@selector(doubleValue)]) {
            duration = [durVal doubleValue];
        }
    } else {
        // Try reading ivar if available
        Ivar iv = class_getInstanceVariable([self class], "_currentVideoMediaDuration");
        if (iv) {
            id durVal = object_getIvar(self, iv);
            if (durVal && [durVal respondsToSelector:@selector(doubleValue)]) {
                duration = [durVal doubleValue];
            }
        }
    }
    
    if (duration <= 0) return;
    
    double remaining = duration - time;
    if (remaining <= (double)crossfade) {
        // mark started to prevent re-entrance
        objc_setAssociatedObject(self, kCrossfadeStartedKey, @(YES), OBJC_ASSOCIATION_RETAIN_NONATOMIC);
        
        // Try to find a "next" controller / queue object that can advance to next track.
        // Many internal APIs exist with different names; attempt a few common selectors.
        BOOL advanced = NO;
        
        // 1) If controller has a queueController property
        if ([self respondsToSelector:@selector(queueController)]) {
#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Warc-performSelector-leaks"
            id queue = [self performSelector:@selector(queueController)];
#pragma clang diagnostic pop
            if (queue) {
                // Try a set of likely selectors on queue
                SEL sels[] = { @selector(advanceToNextItem), @selector(playNextItem), @selector(skipToNextItem), @selector(skipToNext), @selector(advanceToNext) };
                for (int i = 0; i < sizeof(sels)/sizeof(SEL); ++i) {
                    if (tryPerformSelectorOn(queue, sels[i])) { advanced = YES; break; }
                }
            }
        }
        
        // 2) If controller itself can advance
        if (!advanced) {
            SEL sels2[] = { @selector(advanceToNextItem), @selector(playNextItem), @selector(skipToNextItem), @selector(skipToNext), @selector(advanceToNext) };
            for (int i = 0; i < sizeof(sels2)/sizeof(SEL); ++i) {
                if (tryPerformSelectorOn(self, sels2[i])) { advanced = YES; break; }
            }
        }
        
        // 3) When we advanced, attempt to perform a volume fade between current and next players
        // Try to obtain player object(s). Some controllers expose currentPlayer or player properties.
        id currentPlayer = nil;
        id nextPlayer = nil;
        
        if ([self respondsToSelector:@selector(player)]) {
#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Warc-performSelector-leaks"
            currentPlayer = [self performSelector:@selector(player)];
#pragma clang diagnostic pop
        }
        if (!currentPlayer) {
            // attempt to get player via ivar names
            Ivar iv = class_getInstanceVariable([self class], "_player");
            if (iv) currentPlayer = object_getIvar(self, iv);
        }
        
        // If queueController returns an upcoming player or next player property, attempt to access it
        if ([self respondsToSelector:@selector(queueController)]) {
#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Warc-performSelector-leaks"
            id queue = [self performSelector:@selector(queueController)];
#pragma clang diagnostic pop
            if (queue) {
                // try some common selectors for next player holder
                if ([queue respondsToSelector:@selector(nextPlayer)]) {
#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Warc-performSelector-leaks"
                    nextPlayer = [queue performSelector:@selector(nextPlayer)];
#pragma clang diagnostic pop
                }
            }
        }
        
        // If we have currentPlayer and nextPlayer and they support setVolume:, do fade
        if (currentPlayer && nextPlayer && [currentPlayer respondsToSelector:@selector(setVolume:)] && [nextPlayer respondsToSelector:@selector(setVolume:)]) {
            // Start incoming at 0, outgoing at current volume down to 0
            double outgoingStart = 1.0;
            double incomingStart = 0.0;
            
            // try to get existing volume value
            if ([currentPlayer respondsToSelector:@selector(volume)]) {
#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Warc-performSelector-leaks"
                id volObj = [currentPlayer performSelector:@selector(volume)];
#pragma clang diagnostic pop
                if (volObj && [volObj respondsToSelector:@selector(doubleValue)]) {
                    outgoingStart = [volObj doubleValue];
                }
            }
            
            [self startVolumeFadeFrom:outgoingStart to:0.0 duration:crossfade onPlayer:currentPlayer];
            [self startVolumeFadeFrom:incomingStart to:outgoingStart duration:crossfade onPlayer:nextPlayer];
        } else {
            // If we don't have distinct player objects supporting setVolume:, we can't fade programmatically.
            // We simply attempted to advance early, which may produce overlap if the app mixes audio.
        }
        
        // Reset the started flag after the full duration plus a small buffer so the next item can crossfade again later
        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)((crossfade + 1.0) * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
            objc_setAssociatedObject(self, kCrossfadeStartedKey, @(NO), OBJC_ASSOCIATION_RETAIN_NONATOMIC);
        });
    }
}

%end
