#import <UIKit/UIKit.h>
#import <Foundation/Foundation.h>
#import "Headers/YTPlayerViewController.h"
#import "Headers/YTMNowPlayingViewController.h"
#import <AVFoundation/AVFoundation.h>

#define ytmuBool(key) [[[NSUserDefaults standardUserDefaults] dictionaryForKey:@"YTMUltimate"][key] boolValue]
#define ytmuInt(key) [[[NSUserDefaults standardUserDefaults] dictionaryForKey:@"YTMUltimate"][key] integerValue]

AVPlayer *_player;

%hook YTPlayerViewController
%property (nonatomic, retain) id playerObserver;
%property (nonatomic, assign) BOOL isCrossfading;

- (void)viewDidLoad {
    %orig;
    object_getInstanceVariable(self, "_player", (void **)&_player);
    [self setupCrossfadeObserver];
}

- (void)playbackController:(id)arg1 didActivateVideo:(id)arg2 withPlaybackData:(id)arg3 {
    %orig;
    self.isCrossfading = NO;
}

%new
- (void)setupCrossfadeObserver {
    if (self.playerObserver) {
        [_player removeTimeObserver:self.playerObserver];
        self.playerObserver = nil;
    }

    if (!ytmuBool(@"crossfade")) return;

    __weak YTPlayerViewController *weakSelf = self;
    self.playerObserver = [_player addPeriodicTimeObserverForInterval:CMTimeMake(1, 2) queue:dispatch_get_main_queue() usingBlock:^(CMTime time) {
        YTPlayerViewController *strongSelf = weakSelf;
        if (!strongSelf) return;

        if (strongSelf.isCrossfading) return;

        AVPlayerItem *currentItem = _player.currentItem;
        if (currentItem.status == AVPlayerItemStatusReadyToPlay) {
            Float64 currentTime = CMTimeGetSeconds(time);
            Float64 totalDuration = CMTimeGetSeconds(currentItem.duration);
            int crossfadeDuration = ytmuInt(@"crossfadeDuration");

            if (totalDuration > 0 && (totalDuration - currentTime) <= crossfadeDuration) {
                strongSelf.isCrossfading = YES;
                [strongSelf fadeOutAndPlayNext];
            }
        }
    }];
}

%new
- (void)fadeOutAndPlayNext {
    int crossfadeDuration = ytmuInt(@"crossfadeDuration");

    CGFloat volume = _player.volume;
    CGFloat fadeOutStep = volume / (crossfadeDuration * 2);

    for (int i = 0; i < (crossfadeDuration * 2); i++) {
        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(i * 0.5 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
            _player.volume -= fadeOutStep;
        });
    }

    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(crossfadeDuration * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
        YTMNowPlayingViewController *nowPlayingVC = (YTMNowPlayingViewController *)self.parentViewController.parentViewController;
        if (nowPlayingVC) {
            [nowPlayingVC didTapNextButton];
        }
        _player.volume = volume;
    });
}
%end

%ctor {
    NSMutableDictionary *mutableDict = [NSMutableDictionary dictionaryWithDictionary:[[NSUserDefaults standardUserDefaults] dictionaryForKey:@"YTMUltimate"]];
    if (mutableDict[@"crossfade"] == nil) {
        [mutableDict setObject:@(0) forKey:@"crossfade"];
    }
     if (mutableDict[@"crossfadeDuration"] == nil) {
        [mutableDict setObject:@(5) forKey:@"crossfadeDuration"];
    }
    [[NSUserDefaults standardUserDefaults] setObject:mutableDict forKey:@"YTMUltimate"];
}
