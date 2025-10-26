#import <UIKit/UIKit.h>
#import <objc/runtime.h> // ADDED: Required for associated objects

static BOOL YTMU(NSString *key) {
    NSDictionary *YTMUltimateDict = [[NSUserDefaults standardUserDefaults] dictionaryForKey:@"YTMUltimate"];
    return [YTMUltimateDict[key] boolValue];
}

static BOOL selectableLyrics = YTMU(@"YTMUltimateIsEnabled") && YTMU(@"selectableLyrics");

@interface YTFormattedStringLabel : UILabel
@end

@interface YTMLightweightMusicDescriptionShelfCell : UIView
@property (retain, nonatomic) UITextView *lyrics; // Keep this declaration for the compiler
@end

// Define a static key for associated objects
static void *kSelectableLyricsKey = &kSelectableLyricsKey;

%hook YTMLightweightMusicDescriptionShelfCell

// REMOVED: %property (retain, nonatomic) UITextView *lyrics;

// ADDED: Manual getter implementation using associated objects
%new
- (UITextView *)lyrics {
    return objc_getAssociatedObject(self, kSelectableLyricsKey);
}

// ADDED: Manual setter implementation using associated objects
%new
- (void)setLyrics:(UITextView *)lyrics {
    objc_setAssociatedObject(self, kSelectableLyricsKey, lyrics, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
}


- (id)initWithFrame:(CGRect)frame {
    self = %orig;
    if (self && selectableLyrics) {
        UIView *container = [self valueForKey:@"_descriptionContainer"];
        
        // This line now calls the manually implemented setter
        self.lyrics = [[UITextView alloc] init]; 
        
        self.lyrics.backgroundColor = [UIColor clearColor];
        self.lyrics.editable = NO;
        self.lyrics.scrollEnabled = NO;
        self.lyrics.showsVerticalScrollIndicator = NO;
        [container addSubview:self.lyrics];
    }
    return self;
}

- (void)setRenderer:(id)renderer {
    %orig;

    if (selectableLyrics) {
        YTFormattedStringLabel *lyrics = [self valueForKey:@"_descriptionLabel"];
        lyrics.userInteractionEnabled = YES;
        lyrics.hidden = YES;
        
        // Use the manually implemented getter/setter
        self.lyrics.font = lyrics.font;
        self.lyrics.textColor = lyrics.textColor;
        self.lyrics.attributedText = lyrics.attributedText;
    }
}

- (void)layoutSubviews {
    %orig;

    if (selectableLyrics) {
        YTFormattedStringLabel *lyrics = [self valueForKey:@"_descriptionLabel"];
        // Use the manually implemented getter/setter
        self.lyrics.frame = lyrics.frame;
    }
}

%end
